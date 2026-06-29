#!/usr/bin/env python3
"""
run_mini_swe.py — Mini-SWE-Agent wrapper with multi-provider rate-limit fallback.
Intercepts all litellm.completion calls and automatically routes them to the next available slot.

Key design decisions:
- gemini-2.5-pro is EXCLUDED: it hits daily free-tier quota almost immediately (limit: 0 RPM).
- Only gemini-2.5-flash and gemini-2.5-flash-lite are used — better per-minute and per-day limits.
- On all-slots-rate-limited, we wait 60s before cycling through again.
"""

import os
import re
import sys
import time
import random

try:
    import litellm
except ImportError:
    print("Error: litellm is not installed. Please install mini-swe-agent first.")
    sys.exit(1)

# ── Gather all available Gemini API keys (multi-key rotation) ─────────────────
_gemini_keys = []
for i in range(1, 6):
    key_name = "GEMINI_API_KEY" if i == 1 else f"GEMINI_API_KEY_{i}"
    k = os.environ.get(key_name, "").strip()
    if k:
        _gemini_keys.append(k)

# NOTE: gemini-2.5-pro is intentionally excluded — it exhausts its
# free-tier daily quota (0 RPM/RPD) on the very first call.
# Only flash models are used here.
FALLBACK_CHAIN: list[tuple[str, str]] = []

for key in _gemini_keys:
    FALLBACK_CHAIN.append(("gemini/gemini-2.5-flash",      key))
    FALLBACK_CHAIN.append(("gemini/gemini-2.5-flash-lite", key))

if not FALLBACK_CHAIN:
    print("❌ No API keys found for fallback chain! Set GEMINI_API_KEY in environment.")
    sys.exit(1)

print(f"✅ Mini-SWE-Agent Multi-provider fallback ready. {len(FALLBACK_CHAIN)} slots configured.")
_current_slot = 0

# Save original completion function
_original_completion = litellm.completion

def _should_try_next(err_str: str) -> bool:
    lower = err_str.lower()
    keywords = ["rate_limit", "rate limit", "quota", "resource_exhausted", "429", "503", "502", "504", "tpm", "tokens per minute"]
    return any(k in lower for k in keywords)

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

def fallback_completion(*args, **kwargs):
    global _current_slot

    requested_model = kwargs.get("model", "")
    is_managed = (
        requested_model.startswith("gemini/")
        or requested_model.startswith("gemma/")
        or requested_model.startswith("groq/")
    )

    if not is_managed:
        return _original_completion(*args, **kwargs)

    last_exception = None
    num_slots = len(FALLBACK_CHAIN)
    all_rate_limited_rounds = 0

    for attempt in range(num_slots * 3):  # allow up to 3 full rotations
        slot_idx = (_current_slot + attempt) % num_slots
        model, api_key = FALLBACK_CHAIN[slot_idx]

        try:
            kwargs["model"] = model
            kwargs["api_key"] = api_key
            res = _original_completion(*args, **kwargs)
            _current_slot = slot_idx
            return res
        except Exception as e:
            err_str = str(e)
            print(f"  ⚠️  [{model}] Error: {err_str[:250]}...")
            if _should_try_next(err_str):
                last_exception = e
                _current_slot = (slot_idx + 1) % num_slots
                retry_delay = _extract_retry_delay(err_str)

                # If we've rotated through all slots, pause 60s before next round
                if (attempt + 1) % num_slots == 0:
                    all_rate_limited_rounds += 1
                    wait = max(60.0, retry_delay)
                    print(f"     ↳ All slots rate-limited. Waiting {wait:.0f}s before retry round {all_rate_limited_rounds + 1}...")
                    time.sleep(wait)
                else:
                    sleep_sec = _backoff(attempt % num_slots, retry_delay)
                    print(f"     ↳ Switching slot. Waiting {sleep_sec:.1f}s...")
                    time.sleep(sleep_sec)
            else:
                last_exception = e
                print(f"     ↳ Non-retryable error. trying next slot...")
                _current_slot = (slot_idx + 1) % num_slots
                time.sleep(1)

    if last_exception:
        raise last_exception

litellm.completion = fallback_completion

# Execute mini-swe-agent
if __name__ == "__main__":
    from minisweagent.run.mini import app
    app()
