#!/usr/bin/env python3
"""
run_mini_swe.py — Mini-SWE-Agent wrapper with multi-provider rate-limit fallback.
Intercepts all litellm.completion calls and automatically routes them to the next available slot.

Fallback chain priority:
  1. Anthropic Claude (anthropic/claude-haiku-4-5-20251001) — best for code, separate quota
  2. Gemini 2.5 Flash — fast, generous free tier
  3. Gemini 2.5 Flash Lite — cheapest, lowest latency

Known gotchas:
- Claude model MUST use the 'anthropic/' prefix in litellm (e.g. anthropic/claude-haiku-4-5-20251001).
  Without it litellm raises "LLM Provider NOT provided" even if ANTHROPIC_API_KEY is set.
- Gemini 'Cached content is too small' (400): Gemini's Context Cache API requires ≥ 2048 tokens.
  Caused by litellm (or mini-swe-agent) passing use_google_context_caching=True.
  Fixed by: (a) env vars LITELLM_DISABLE_PROMPT_CACHING + LITELLM_GOOGLE_DISABLE_CONTEXT_CACHING,
             (b) litellm.cache=None, litellm.disable_cache=True,
             (c) stripping all caching kwargs before every completion call.
- Anthropic "credit balance too low": permanent failure for the whole run. The slot is
  blacklisted immediately so we don't waste retries on a billing error.
- gemini-2.5-pro is EXCLUDED: hits daily free-tier quota immediately (limit: 0 RPM).
- Groq is EXCLUDED: incompatible schema (rejects 'images' in assistant role).
- On all-slots-rate-limited, waits 60s before cycling through again.
"""

import os
import re
import sys
import time
import random

# ── Disable ALL Gemini context/prompt caching BEFORE importing litellm ────────
# These env vars are checked by litellm at import time and at call time.
# Must be set early to prevent the "Cached content is too small" 400 error.
os.environ["LITELLM_DISABLE_PROMPT_CACHING"]          = "true"
os.environ["LITELLM_GOOGLE_DISABLE_CONTEXT_CACHING"]  = "true"
# ─────────────────────────────────────────────────────────────────────────────

try:
    import litellm
except ImportError:
    print("Error: litellm is not installed. Please install mini-swe-agent first.")
    sys.exit(1)

# Disable litellm's internal cache objects too (belt-and-suspenders).
litellm.cache         = None
litellm.disable_cache = True

# Save original completion function AFTER cache is disabled.
_original_completion = litellm.completion

# ── Anthropic (Claude) — PRIMARY ──────────────────────────────────────────────
_anthropic_key = os.environ.get("ANTHROPIC_API_KEY", "").strip()

# ── Gemini — SECONDARY ────────────────────────────────────────────────────────
_gemini_keys = []
for i in range(1, 6):
    key_name = "GEMINI_API_KEY" if i == 1 else f"GEMINI_API_KEY_{i}"
    k = os.environ.get(key_name, "").strip()
    if k:
        _gemini_keys.append(k)

# Build fallback chain:
# 1. Claude Haiku (fast, cheap, great at code)
# 2. Gemini Flash / Flash-Lite (free tier)
# gemini-2.5-pro is intentionally excluded — exhausts free daily quota immediately.
# Groq is excluded — incompatible schema (rejects 'images' in assistant role).
FALLBACK_CHAIN: list[tuple[str, str]] = []

if _anthropic_key:
    # MUST use the 'anthropic/' prefix — litellm uses this to identify the provider.
    # Without it you get: "LLM Provider NOT provided" even with ANTHROPIC_API_KEY set.
    FALLBACK_CHAIN.append(("anthropic/claude-haiku-4-5-20251001", _anthropic_key))

for key in _gemini_keys:
    FALLBACK_CHAIN.append(("gemini/gemini-2.5-flash",      key))
    FALLBACK_CHAIN.append(("gemini/gemini-2.5-flash-lite", key))

if not FALLBACK_CHAIN:
    print("❌ No API keys found! Set ANTHROPIC_API_KEY or GEMINI_API_KEY in environment.")
    sys.exit(1)

print(f"✅ Mini-SWE-Agent Multi-provider fallback ready. {len(FALLBACK_CHAIN)} slots configured.")
if _anthropic_key:
    print("  ✓ Anthropic Claude (primary)")
if _gemini_keys:
    print(f"  ✓ Gemini ({len(_gemini_keys)} key(s), secondary)")

_current_slot = 0

# Slots permanently disabled for this run (e.g. no credits, invalid key).
# Once blacklisted, a slot is never retried — cycling back to it just wastes minutes.
_blacklisted_slots: set[int] = set()


def _should_try_next(err_str: str) -> bool:
    """True for transient errors where retrying later may succeed."""
    lower = err_str.lower()
    keywords = [
        "rate_limit", "rate limit", "quota", "resource_exhausted",
        "429", "503", "502", "504",
        "tpm", "tokens per minute", "overloaded",
    ]
    return any(k in lower for k in keywords)


def _is_permanent_failure(err_str: str) -> bool:
    """True for errors where this slot will NEVER succeed this run.
    Examples: no credits, invalid API key, account suspended.
    """
    lower = err_str.lower()
    permanent_keywords = [
        "credit balance is too low",
        "credit balance",
        "billing",
        "payment required",
        "invalid_api_key",
        "authentication",
        "your api key is invalid",
        "permission_denied",
        "account has been suspended",
    ]
    return any(k in lower for k in permanent_keywords)


def _extract_retry_delay(err_str: str) -> float:
    """Extract retryDelay from Gemini's error body (e.g. 'retryDelay': '17s')."""
    match = re.search(r'"retryDelay"\s*:\s*"(\d+(?:\.\d+)?)s"', err_str)
    if match:
        return float(match.group(1))
    return 0.0


def _backoff(attempt: int, retry_delay: float = 0.0) -> float:
    """Exponential backoff capped at 60s, respecting Gemini's own retry hint."""
    jitter = random.uniform(0.5, 1.5)
    exp_wait = min(60.0, (2.0 ** attempt) * jitter)
    return max(exp_wait, retry_delay)


def _strip_caching_kwargs(kwargs: dict) -> dict:
    """Remove all caching-related kwargs that trigger Gemini's Context Cache API.
    Gemini requires ≥ 2048 tokens to create a cache entry; small requests get 400.
    """
    for key in ("caching", "cache", "use_google_context_caching", "cache_control"):
        kwargs.pop(key, None)
    kwargs["use_google_context_caching"] = False   # explicit override
    return kwargs


def fallback_completion(*args, **kwargs):
    global _current_slot

    requested_model = kwargs.get("model", "")
    is_managed = (
        requested_model.startswith("gemini/")
        or requested_model.startswith("gemma/")
        or requested_model.startswith("groq/")
        or requested_model.startswith("anthropic/")
        or requested_model.startswith("claude")  # bare name fallback
    )

    if not is_managed:
        return _original_completion(*args, **kwargs)

    last_exception = None
    num_slots = len(FALLBACK_CHAIN)
    all_rate_limited_rounds = 0
    active_slots = [i for i in range(num_slots) if i not in _blacklisted_slots]

    if not active_slots:
        raise RuntimeError("❌ All slots have been permanently blacklisted. No usable API keys remain.")

    for attempt in range(len(active_slots) * 3):  # up to 3 rotations through active slots
        slot_idx = active_slots[attempt % len(active_slots)]
        model, api_key = FALLBACK_CHAIN[slot_idx]

        try:
            kwargs["model"]   = model
            kwargs["api_key"] = api_key
            _strip_caching_kwargs(kwargs)   # prevent Gemini 400 "cached content too small"
            res = _original_completion(*args, **kwargs)
            _current_slot = slot_idx
            return res

        except Exception as e:
            err_str = str(e)
            short_err = err_str[:300]
            print(f"  ⚠️  [{model}] Error: {short_err}...")

            if _is_permanent_failure(err_str):
                # Billing / auth errors won't resolve — blacklist immediately.
                _blacklisted_slots.add(slot_idx)
                active_slots = [i for i in range(num_slots) if i not in _blacklisted_slots]
                print(f"     ↳ Permanent failure — blacklisting slot {slot_idx} ({model}) for this run.")
                if not active_slots:
                    raise RuntimeError(
                        "❌ All API slots have been permanently blacklisted.\n"
                        f"Last error: {short_err}"
                    ) from e
                last_exception = e
                time.sleep(1)

            elif _should_try_next(err_str):
                # Rate limit / quota — retry later.
                last_exception = e
                retry_delay = _extract_retry_delay(err_str)

                # Check if we've exhausted all active slots in this rotation.
                if (attempt + 1) % max(len(active_slots), 1) == 0:
                    all_rate_limited_rounds += 1
                    wait = max(60.0, retry_delay)
                    print(f"     ↳ All active slots rate-limited. Waiting {wait:.0f}s before retry round {all_rate_limited_rounds + 1}...")
                    time.sleep(wait)
                else:
                    sleep_sec = _backoff(attempt % max(len(active_slots), 1), retry_delay)
                    print(f"     ↳ Switching slot. Waiting {sleep_sec:.1f}s...")
                    time.sleep(sleep_sec)

            else:
                # Unknown non-retryable error — skip this slot.
                last_exception = e
                print(f"     ↳ Non-retryable error. trying next slot...")
                time.sleep(1)

    if last_exception:
        raise last_exception


litellm.completion = fallback_completion

# Execute mini-swe-agent
if __name__ == "__main__":
    from minisweagent.run.mini import app
    app()
