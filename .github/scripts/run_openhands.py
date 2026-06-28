#!/usr/bin/env python3
"""
run_openhands.py — OpenHands wrapper with multi-provider rate-limit fallback.

Intercepts all litellm.completion calls and automatically routes them to
the next available model if a 429 Rate Limit / Quota Exceeded / 503 error
occurs, cycling through Gemini models first, then Groq as a final fallback.

Provider priority:
  1. Gemini 2.5 Flash        → primary (free, 500 RPD)
  2. Gemini 2.5 Flash-Lite   → fallback (free, higher RPM)
  3. Gemini 2.5 Pro          → emergency Gemini (very limited free)
  4. Groq Llama 3.3 70B      → cross-provider fallback (free, generous)
  5. Groq Llama 3.1 8B       → last resort (fast, free)
"""

import os
import sys
import time
import random

try:
    import litellm
except ImportError:
    print("Error: litellm is not installed. Please install openhands-ai first.")
    sys.exit(1)

# Save the original completion function
_original_completion = litellm.completion

# ── Model Fallback Chain ──────────────────────────────────────────────────────
# Each entry: (model_id, api_key_env_var)
# The api_key_env_var tells us which environment variable holds the key.
# litellm reads these automatically, but we track them so we can skip models
# whose API key is missing.
FALLBACK_CHAIN = [
    ("gemini/gemini-2.5-flash",        "GEMINI_API_KEY"),
    ("gemini/gemini-2.5-flash-lite",   "GEMINI_API_KEY"),
    ("gemini/gemini-2.5-pro",          "GEMINI_API_KEY"),
    ("groq/llama-3.3-70b-versatile",   "GROQ_API_KEY"),
    ("groq/llama-3.1-8b-instant",      "GROQ_API_KEY"),
]

# Filter out models whose API key is not available in the environment
AVAILABLE_MODELS = [
    (model, key_var)
    for model, key_var in FALLBACK_CHAIN
    if os.environ.get(key_var)
]

if not AVAILABLE_MODELS:
    print("❌ No API keys found! Set GEMINI_API_KEY or GROQ_API_KEY in the environment.")
    sys.exit(1)

print(f"✅ Multi-provider fallback ready. Available models ({len(AVAILABLE_MODELS)}):")
for model, key_var in AVAILABLE_MODELS:
    print(f"   • {model}  [{key_var}]")

_current_model_index = 0

# Error codes that indicate we should try the next model
RETRYABLE_STATUS_CODES = {429, 503, 502, 504}


def _should_retry(error_str: str) -> bool:
    """Check if the error is a transient rate-limit or availability issue."""
    retryable_keywords = [
        "rate_limit", "rate limit", "quota", "resource_exhausted",
        "service unavailable", "overloaded", "capacity", "too many requests",
        "503", "429", "502", "504",
    ]
    lower = error_str.lower()
    return any(kw in lower for kw in retryable_keywords)


def _exponential_backoff(attempt: int, base: float = 2.0, cap: float = 30.0) -> float:
    """Exponential backoff with full jitter: sleep between 0 and min(cap, base^attempt)."""
    sleep_time = min(cap, base ** attempt) * random.random()
    return sleep_time


def _set_groq_key_if_needed(model: str) -> None:
    """Ensure the correct API key env var is set for litellm to pick up."""
    if model.startswith("groq/"):
        groq_key = os.environ.get("GROQ_API_KEY", "")
        if groq_key:
            os.environ["GROQ_API_KEY"] = groq_key  # already set; litellm reads it
    # Gemini key is already set via GEMINI_API_KEY / LLM_API_KEY (OpenHands sets this)


def fallback_completion(*args, **kwargs):
    global _current_model_index

    requested_model = kwargs.get("model", "")

    # Only intercept calls for Gemini or Groq models (anything we manage)
    is_gemini = requested_model.startswith("gemini/") or requested_model.startswith("gemma/")
    is_groq = requested_model.startswith("groq/")

    if not (is_gemini or is_groq):
        # Non-managed provider (e.g. openai/) — pass straight through
        return _original_completion(*args, **kwargs)

    last_exception = None
    num_models = len(AVAILABLE_MODELS)

    for attempt in range(num_models):
        model_index = (_current_model_index + attempt) % num_models
        model, key_var = AVAILABLE_MODELS[model_index]

        try:
            _set_groq_key_if_needed(model)
            kwargs["model"] = model

            # For Groq, pass api_key explicitly from env to avoid confusion
            if model.startswith("groq/"):
                kwargs["api_key"] = os.environ.get("GROQ_API_KEY", "")

            res = _original_completion(*args, **kwargs)

            # Success: remember this model for next calls
            _current_model_index = model_index
            return res

        except Exception as e:
            err_str = str(e)
            short_err = err_str[:300]
            print(f"  ⚠️  [{model}] Error: {short_err}...")

            if _should_retry(err_str):
                # Rate limit or availability issue — advance to next model
                _current_model_index = (model_index + 1) % num_models
                last_exception = e

                if attempt < num_models - 1:
                    sleep_secs = _exponential_backoff(attempt)
                    next_model = AVAILABLE_MODELS[(_current_model_index) % num_models][0]
                    print(f"     ↳ Switching to [{next_model}] in {sleep_secs:.1f}s...")
                    time.sleep(sleep_secs)
                    continue
                else:
                    print("  ❌ All fallback models exhausted — no more alternatives.")
            else:
                # Non-retryable error (e.g. invalid request, auth failure on this model)
                # Still try next model, it might succeed
                last_exception = e
                if attempt < num_models - 1:
                    next_model = AVAILABLE_MODELS[(_current_model_index) % num_models][0]
                    print(f"     ↳ Non-retryable on this model. Trying [{next_model}]...")
                    time.sleep(1)
                    continue

    if last_exception:
        raise last_exception


# Apply the global patch to litellm
litellm.completion = fallback_completion

# Execute OpenHands
if __name__ == "__main__":
    import runpy
    runpy.run_module("openhands.core.main", run_name="__main__")
