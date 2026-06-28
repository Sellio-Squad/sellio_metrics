#!/usr/bin/env python3
"""
run_openhands.py — OpenHands wrapper with Gemini rate-limit fallback.

Intercepts all litellm.completion calls and automatically routes them to
the next available Gemini model if a 429 Rate Limit / Quota Exceeded error occurs.
This bypasses the strict 20 RPD (Requests Per Day) limit per model on the free tier.
"""

import sys
import time

try:
    import litellm
except ImportError:
    print("Error: litellm is not installed. Please install openhands-ai first.")
    sys.exit(1)

# Save the original completion function
_original_completion = litellm.completion

# Define our fallback list of Gemini models
GEMINI_MODELS = [
    "gemini/gemini-2.5-flash",
    "gemini/gemini-2.5-flash-lite",
    "gemini/gemma-3-27b-it",
    "gemini/gemma-3-12b-it",
    "gemini/gemma-3-4b-it",
]
_current_model_index = 0

def fallback_completion(*args, **kwargs):
    global _current_model_index
    
    requested_model = kwargs.get("model", "")
    
    # Only intercept Gemini/Gemma model calls
    if requested_model.startswith("gemini/") or requested_model.startswith("gemma/"):
        last_exception = None
        
        # Start trying from the current working model index
        for attempt in range(len(GEMINI_MODELS)):
            model_index = (_current_model_index + attempt) % len(GEMINI_MODELS)
            model = GEMINI_MODELS[model_index]
            
            try:
                kwargs["model"] = model
                res = _original_completion(*args, **kwargs)
                # If successful, save this model index for subsequent calls to avoid retrying failed models
                _current_model_index = model_index
                return res
            except Exception as e:
                err_str = str(e)
                print(f"  ⚠️  Error on model {model}: {err_str[:200]}...")
                if attempt < len(GEMINI_MODELS) - 1:
                    print(f"     Trying next fallback model in list...")
                    last_exception = e
                    # Update our current model index to the next one so we don't hit the failed one again
                    _current_model_index = (model_index + 1) % len(GEMINI_MODELS)
                    time.sleep(1)
                    continue
                else:
                    print("  ❌ All fallback Gemini models exhausted.")
                    last_exception = e
                    
        if last_exception:
            raise last_exception
    else:
        # Pass non-Gemini requests straight through
        return _original_completion(*args, **kwargs)

# Apply the global patch to litellm
litellm.completion = fallback_completion
print(f"✅ LiteLLM completion patched. Fallback order: {', '.join(GEMINI_MODELS)}")

# Execute OpenHands
if __name__ == "__main__":
    import runpy
    runpy.run_module("openhands.core.main", run_name="__main__")

