#!/usr/bin/env python3
"""
run_mini_swe.py — Mini-SWE-Agent wrapper with multi-provider rate-limit fallback.
Intercepts all litellm.completion calls and automatically routes them to the next available slot.
"""

import os
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

_groq_key = os.environ.get("GROQ_API_KEY", "").strip()
_groq_paid = os.environ.get("GROQ_PAID", "false").lower() == "true"

# For Mini-SWE-agent, since the token requests are smaller (~10k-20k tokens),
# Groq free tier (6,000 TPM limit) is STILL too small if the history grows past 6k tokens,
# but it is much more viable than in OpenHands (where it starts at 75k).
# We'll allow Groq on the fallback chain, but put it at the very end.
FALLBACK_CHAIN: list[tuple[str, str]] = []

for key in _gemini_keys:
    FALLBACK_CHAIN.append(("gemini/gemini-2.5-flash",      key))
    FALLBACK_CHAIN.append(("gemini/gemini-2.5-flash-lite", key))

for key in _gemini_keys:
    FALLBACK_CHAIN.append(("gemini/gemini-2.5-pro", key))

if _groq_key:
    # If the user sets GROQ_PAID=true, we prioritize Groq, otherwise it's a last resort
    # because of the 6k TPM free limit.
    FALLBACK_CHAIN.append(("groq/llama-3.3-70b-versatile", _groq_key))
    FALLBACK_CHAIN.append(("groq/llama-3.1-8b-instant", _groq_key))

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

def _backoff(attempt: int) -> float:
    return min(25.0, (2.0 ** attempt)) * random.random()

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

    for attempt in range(num_slots):
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
                if attempt < num_slots - 1:
                    sleep_sec = _backoff(attempt)
                    print(f"     ↳ Switching slot. Waiting {sleep_sec:.1f}s...")
                    time.sleep(sleep_sec)
            else:
                last_exception = e
                if attempt < num_slots - 1:
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
