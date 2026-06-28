#!/usr/bin/env python3
"""
Sellio AI Agent — Multi-stack code implementation with real test execution.

Reads an implementation plan from the PLAN_JSON env var, generates code using
Gemini, writes files to disk, runs the appropriate test/build command for the
detected stack, and self-corrects on failures. Up to MAX_RETRIES attempts.

Key design decisions:
  - ALL files are generated in ONE Gemini call per attempt (not one call per file).
    This reduces quota usage from N*retries to just retries (e.g. 3 calls total
    instead of 39), making the free tier viable even for large tasks.
  - On retry, only files that caused errors are regenerated (targeted learning).
  - Model fallback chain: tries the next model when one is exhausted.
  - 429 errors are handled with automatic wait + retry.

Stacks supported:
  flutter  → flutter pub get + flutter analyze + flutter test (app-scoped)
  kotlin   → ./gradlew compileKotlin (+ test if under 5 min)
  node     → npm ci + npm run build + npm test
  unknown  → skips test step, commits as-is

Exit codes:
  0 → success (committed to current branch)
  1 → all retries exhausted
"""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

from google import genai

# ── Configuration ─────────────────────────────────────────────────────────────

GEMINI_API_KEY = os.environ["GEMINI_API_KEY"]
PLAN_JSON      = os.environ["PLAN_JSON"]
STACK          = os.environ.get("STACK", "unknown")
ISSUE_NUMBER   = os.environ.get("ISSUE_NUMBER", "0")
MAX_RETRIES    = 3

# Model fallback chain — ordered by preference.
# Based on actual free-tier quotas visible in Google AI Studio:
#   gemini-3.1-flash-lite  → 500 RPD  ✅ Best for this use case
#   gemini-2.5-flash-lite  →  20 RPD  (fallback)
#   gemini-2.5-flash       →  20 RPD  (last resort)
GEMINI_MODELS = [
    "gemini-3.1-flash-lite",
    "gemini-2.5-flash-lite",
    "gemini-2.5-flash",
]
_model_index = 0  # current model index
_current_app_dir = "."  # set in main() after resolving stack config; used by generate_files

client = genai.Client(api_key=GEMINI_API_KEY)

# Delimiter used to separate files in the batched prompt/response
FILE_START = "<<<FILE:"
FILE_END   = "<<<END>>>"

# ── Helpers ───────────────────────────────────────────────────────────────────

def run(cmd: list[str], cwd: str = ".") -> tuple[bool, str]:
    """Run a shell command. Returns (success, combined output)."""
    if not cmd:
        return True, ""
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, cwd=cwd, timeout=300,
        )
        output = (result.stdout + "\n" + result.stderr).strip()
        if result.returncode != 0:
            print(f"  [exit {result.returncode}] {' '.join(cmd)}")
        return result.returncode == 0, output
    except subprocess.TimeoutExpired:
        return False, "Command timed out after 5 minutes"
    except FileNotFoundError:
        return False, f"Command not found: {cmd[0]}"


def read_file(path: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8")
    except Exception:
        return ""


def write_file(path: str, content: str) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding="utf-8")
    print(f"  ✅ {path}")


def call_gemini(prompt: str) -> str:
    """
    Call Gemini with automatic retry on 429 rate-limit errors.
    Falls back to the next model in GEMINI_MODELS when quota is exhausted.
    """
    global _model_index
    max_api_retries = 4

    for attempt in range(max_api_retries):
        model = GEMINI_MODELS[_model_index]
        try:
            response = client.models.generate_content(model=model, contents=prompt)
            if not response:
                raise ValueError("Gemini returned an empty response object")
            if response.text is None:
                # Log why the response was empty/None
                finish_reason = "Unknown"
                if response.candidates and response.candidates[0].finish_reason:
                    finish_reason = str(response.candidates[0].finish_reason)
                raise ValueError(f"Gemini response.text is None. Finish reason: {finish_reason}")
            return response.text
        except Exception as e:
            err_str = str(e)
            # Treat 429 (rate limits), 503/500 (server overloads/errors), and ValueError as retryable/fallback conditions
            is_retryable = (
                "429" in err_str or 
                "RESOURCE_EXHAUSTED" in err_str or
                "503" in err_str or 
                "UNAVAILABLE" in err_str or
                "500" in err_str or
                isinstance(e, ValueError)
            )
            is_value_error = isinstance(e, ValueError)

            if is_retryable:
                # If the model has permanently exhausted its daily quota or got blocked, switch model
                # Also switch model if we get a persistent 503/500 error
                if "limit: 0" in err_str or is_value_error:
                    if _model_index < len(GEMINI_MODELS) - 1:
                        _model_index += 1
                        next_model = GEMINI_MODELS[_model_index]
                        reason = "blocked/empty response" if is_value_error else "daily quota exhausted/error"
                        print(f"  ⚠️  {model} {reason} — switching to {next_model}")
                        continue
                    else:
                        print("  ❌ All models have exhausted their daily quota or failed.")
                        raise

                # Temporary rate limit or server overload — wait and retry
                wait_match = re.search(r"retry in (\d+(?:\.\d+)?)s", err_str)
                wait_secs  = min(float(wait_match.group(1)) if wait_match else 20.0, 65.0)
                print(f"  ⏳ Temporary error on {model} ({err_str[:100]}). Waiting {wait_secs:.0f}s... (attempt {attempt+1}/{max_api_retries})")
                time.sleep(wait_secs)
                if attempt == max_api_retries - 1:
                    raise
            else:
                raise

    raise RuntimeError("Gemini call failed after all retries")


# ── Batched code generation ───────────────────────────────────────────────────

LANG_HINT = {
    "flutter": "Dart / Flutter",
    "kotlin":  "Kotlin / Spring Boot 3 / JPA",
    "node":    "TypeScript / Node.js",
    "unknown": "the project's language",
}


def _build_file_tree(root: str, max_depth: int = 4, max_files: int = 200) -> str:
    """
    Build a compact directory tree of the project, like `find` or `tree`.
    Only shows Dart/YAML files. Lets the AI understand the project layout.
    """
    lines: list[str] = []
    count = 0
    root_path = Path(root)

    for path in sorted(root_path.rglob("*")):
        if count >= max_files:
            lines.append("  ... (truncated)")
            break
        # Only show .dart and .yaml files, skip generated/build dirs
        if any(part in path.parts for part in [".dart_tool", "build", ".git", ".fvm", "__pycache__"]):
            continue
        if path.suffix not in (".dart", ".yaml", ".yml", ".arb"):
            continue
        # Respect depth limit
        rel = path.relative_to(root_path)
        if len(rel.parts) > max_depth:
            continue
        indent = "  " * (len(rel.parts) - 1)
        lines.append(f"{indent}{rel.name}")
        count += 1

    return "\n".join(lines)


_cached_project_context = None


def strip_comments_and_empty_lines(code: str) -> str:
    """
    Remove single-line and multi-line comments and strip empty lines.
    This keeps the code context compact, clean, and token-efficient for the LLM.
    """
    # Remove single line comments (// ...)
    code = re.sub(r'//.*$', '', code, flags=re.MULTILINE)
    # Remove multi-line comments (/* ... */)
    code = re.sub(r'/\*.*?\*/', '', code, flags=re.DOTALL)
    # Filter out empty lines
    lines = [line for line in code.splitlines() if line.strip()]
    return "\n".join(lines)


def _collect_project_context(app_dir: str, all_paths: list[str]) -> str:
    """
    Actively explore the project before generating code — same strategy Antigravity uses.
    Caches results globally so we don't repeat expensive file operations during retries.
    """
    global _cached_project_context
    if _cached_project_context is not None:
        return _cached_project_context

    sections: list[str] = []
    task_paths_set = set(all_paths)

    # ── 1. pubspec.yaml ────────────────────────────────────────────────────────
    pubspec_path = Path(app_dir) / "pubspec.yaml"
    if pubspec_path.exists():
        content = pubspec_path.read_text(encoding="utf-8")
        sections.append(
            f"### pubspec.yaml — ALL available packages (only use these):\n```yaml\n{content[:4000]}\n```"
        )

    # ── 2. File tree ───────────────────────────────────────────────────────────
    lib_dir = Path(app_dir) / "lib"
    if lib_dir.exists():
        tree = _build_file_tree(str(lib_dir), max_depth=5, max_files=150)
        if tree:
            sections.append(
                f"### Project file tree (lib/ directory — use these exact paths for imports):\n```\n{tree}\n```"
            )

    # ── 3. Key architectural files ────────────────────────────────────────────
    # These are the files the AI most often gets wrong imports for.
    # Read them fully so the AI can copy exact import statements.
    key_file_patterns = [
        # DI / injection
        f"{app_dir}/lib/di/injection_container.dart",
        f"{app_dir}/lib/di/modules/bloc_module.dart",
        f"{app_dir}/lib/di/service_locator.dart",
        # Router / navigation
        f"{app_dir}/lib/core/navigate/app_routes.dart",
        f"{app_dir}/lib/core/navigate/route_manager.dart",
        f"{app_dir}/lib/core/navigate/app_navigator.dart",
        f"{app_dir}/lib/core/navigate/app_navigator_impl.dart",
        # App entry / base
        f"{app_dir}/lib/app.dart",
        f"{app_dir}/lib/main.dart",
    ]
    key_files_content = ""
    for path in key_file_patterns:
        if path in task_paths_set:
            continue  # skip files we're generating (we'll show their current state separately)
        content = read_file(path)
        if content:
            cleaned_content = strip_comments_and_empty_lines(content)
            key_files_content += f"\n#### `{path}`:\n```dart\n{cleaned_content[:2000]}\n```\n"

    if key_files_content:
        sections.append(
            f"### Key architectural files (copy import patterns from these EXACTLY):{key_files_content}"
        )

    # ── 4. Find 2 complete existing screens as examples ───────────────────────
    # Find existing screen files that are NOT in our task — these are the best
    # examples of how a complete, working screen looks in this project.
    screens_dir = Path(app_dir) / "lib" / "presentation" / "screens"
    example_screens: list[tuple[str, str]] = []

    if screens_dir.exists():
        for dart_file in sorted(screens_dir.rglob("*_screen.dart")):
            rel = str(dart_file)
            if rel in task_paths_set:
                continue
            content = read_file(rel)
            if content and len(content) > 200:
                cleaned_content = strip_comments_and_empty_lines(content)
                example_screens.append((rel, cleaned_content))
            if len(example_screens) >= 2:
                break

    if example_screens:
        examples_text = ""
        for path, content in example_screens:
            examples_text += f"\n#### `{path}` (complete existing screen — copy its structure):\n```dart\n{content[:3000]}\n```\n"
        sections.append(
            f"### Complete existing screen examples (use these as structural templates):{examples_text}"
        )

    # ── 5. Existing cubit examples ─────────────────────────────────────────────
    cubits_found: list[tuple[str, str]] = []
    if screens_dir.exists():
        for dart_file in sorted(screens_dir.rglob("*_cubit.dart")):
            rel = str(dart_file)
            if rel in task_paths_set:
                continue
            content = read_file(rel)
            if content and len(content) > 100:
                cleaned_content = strip_comments_and_empty_lines(content)
                cubits_found.append((rel, cleaned_content))
            if len(cubits_found) >= 1:
                break

    if cubits_found:
        cubit_text = ""
        for path, content in cubits_found:
            cubit_text += f"\n#### `{path}`:\n```dart\n{content[:2000]}\n```\n"
        sections.append(f"### Existing Cubit example (use same pattern):{cubit_text}")

    _cached_project_context = "\n\n".join(sections)
    return _cached_project_context


def build_batched_prompt(
    plan: dict,
    all_paths: list[str],
    paths_to_generate: list[str],
    existing: dict[str, str],
    per_file_errors: dict[str, str],
    app_dir: str = ".",
) -> str:
    """
    Build a single prompt that asks Gemini to generate ALL requested files at once.

    This is the key optimization: 1 API call per attempt instead of N calls,
    reducing quota usage by ~13x for a typical task.
    """
    lang = LANG_HINT.get(STACK, "the project's language")

    # Collect project-specific context (pubspec + existing import patterns)
    project_context = _collect_project_context(app_dir, all_paths) if STACK == "flutter" else ""

    # Describe each file to generate
    files_section = ""
    for path in paths_to_generate:
        existing_content = existing.get(path, "")
        file_error = per_file_errors.get(path, "")

        if existing_content:
            files_section += f"\n### File: `{path}` (MODIFY)\n"
            files_section += f"Current content:\n```\n{existing_content[:3000]}\n```\n"
        else:
            files_section += f"\n### File: `{path}` (CREATE — does not exist yet)\n"

        if file_error:
            files_section += f"⚠️ Errors from previous attempt — fix ALL of these:\n```\n{file_error[:2000]}\n```\n"

    # List all paths in the task (for cross-referencing imports)
    all_files_list = "\n".join(f"  - {p}" for p in all_paths)

    context_block = f"\n## Project context (use ONLY these packages and import patterns):\n{project_context}\n" if project_context else ""

    return f"""You are a senior {lang} engineer implementing a GitHub issue.

## Issue
Title: {plan.get("issueTitle", "")}
Summary: {plan.get("summary", "")}
Approach: {plan.get("approach", "")}
{context_block}
## All files in this task (for cross-referencing imports):
{all_files_list}

## Files to generate
{files_section}

## Output format — CRITICAL
Output EACH file using this EXACT delimiter format. No other text allowed outside these blocks.

{FILE_START} path/to/file.dart>>>
[complete file content here]
{FILE_END}

{FILE_START} path/to/another.dart>>>
[complete file content here]
{FILE_END}

## Rules
- Use the exact delimiters shown above. Do NOT use markdown fences inside the blocks.
- Output ALL {len(paths_to_generate)} file(s) listed above. Do not skip any.
- CRITICAL: Only use imports from pubspec.yaml or files that exist in the repository.
  Do NOT invent package names. Copy import patterns from the existing files shown above.
- Remove any import that you are not 100% sure is used — unused imports cause build failures.
- Every method that overrides a parent must have the @override annotation.
- Match the existing code style and conventions precisely.
- For {lang}: follow idiomatic patterns (null-safety, DI, clean architecture, etc.).
"""


def parse_batched_response(response_text: str, expected_paths: list[str]) -> dict[str, str]:
    """
    Parse the batched Gemini response into {file_path: content} dict.
    Falls back to returning an empty dict for files that weren't found.
    """
    result: dict[str, str] = {}

    # Split by FILE_START delimiter
    parts = response_text.split(FILE_START)
    for part in parts[1:]:  # skip text before first <<<FILE:
        # Extract path from the first line: " path/to/file.dart>>>"
        header_end = part.find(">>>")
        if header_end == -1:
            continue
        path = part[:header_end].strip()

        # Find matching expected path (handle slight formatting differences)
        matched_path = None
        for expected in expected_paths:
            if expected == path or expected.endswith(path) or path.endswith(expected):
                matched_path = expected
                break
        if not matched_path:
            # Try fuzzy match by filename
            fname = Path(path).name
            for expected in expected_paths:
                if Path(expected).name == fname:
                    matched_path = expected
                    break

        if not matched_path:
            print(f"  ⚠️  Unmatched file in response: '{path}' — skipping")
            continue

        # Extract content between >>> and <<<END>>>
        content_start = header_end + len(">>>")
        content_end   = part.find(FILE_END)
        content = part[content_start:content_end].strip() if content_end != -1 else part[content_start:].strip()

        # Strip any accidental ``` fences
        lines = content.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        result[matched_path] = "\n".join(lines).strip()

    return result


def generate_files(
    plan: dict,
    existing: dict[str, str],
    paths_to_generate: list[str],
    error_output: str = "",
) -> dict[str, str]:
    """
    Generate all requested files in ONE Gemini call.
    Attributes errors to specific files so each gets targeted feedback.
    """
    all_paths = plan.get("filesToModify", []) + plan.get("newFiles", [])

    # Attribute error lines to specific files
    per_file_errors: dict[str, str] = {}
    if error_output:
        unattributed_lines: list[str] = []
        for line in error_output.splitlines():
            attributed = False
            for path in paths_to_generate:
                if path in line or Path(path).name in line:
                    per_file_errors.setdefault(path, "")
                    per_file_errors[path] += line + "\n"
                    attributed = True
            if not attributed:
                unattributed_lines.append(line)

        # For files with no specific error lines, give them unattributed context
        unattributed_text = "\n".join(unattributed_lines[:30])
        for path in paths_to_generate:
            if path not in per_file_errors and unattributed_text:
                per_file_errors[path] = unattributed_text

    print(f"  🤖 Calling Gemini [{GEMINI_MODELS[_model_index]}] for {len(paths_to_generate)} file(s)...")
    prompt   = build_batched_prompt(plan, all_paths, paths_to_generate, existing, per_file_errors, app_dir=_current_app_dir)
    response = call_gemini(prompt)

    result = parse_batched_response(response, paths_to_generate)

    # Warn about any files that weren't parsed from the response
    missing = [p for p in paths_to_generate if p not in result]
    if missing:
        print(f"  ⚠️  {len(missing)} file(s) missing from response: {', '.join(missing)}")
        print("  🔁 Will retry missing files individually...")
        for path in missing:
            print(f"     🤖 Individual call for: {path}")
            solo_prompt = build_batched_prompt(plan, all_paths, [path], existing, per_file_errors)
            solo_response = call_gemini(solo_prompt)
            solo_result   = parse_batched_response(solo_response, [path])
            if path in solo_result:
                result[path] = solo_result[path]
            else:
                print(f"     ❌ Still missing: {path} — will leave original")

    return result


# ── Flutter app subfolder detection ──────────────────────────────────────────

def detect_flutter_app_dir(all_paths: list[str]) -> str:
    """
    Detect the target app subfolder from plan file paths (monorepo safe).
    Scopes flutter pub get + flutter analyze to the specific app, not repo root.
    """
    candidates: list[Path] = []
    for p in all_paths:
        parts = Path(p).parts
        for i in range(len(parts) - 1, 0, -1):
            candidate = Path(*parts[:i])
            if (candidate / "pubspec.yaml").exists():
                candidates.append(candidate)
                break

    if not candidates:
        for p in all_paths:
            parts = Path(p).parts
            if len(parts) >= 2 and parts[0] == "apps":
                candidate = Path(parts[0]) / parts[1]
                if candidate.is_dir():
                    candidates.append(candidate)
                    break

    if candidates:
        from collections import Counter
        most_common = Counter(str(c) for c in candidates).most_common(1)[0][0]
        print(f"  📁 Scoped Flutter commands to: {most_common}/")
        return most_common

    print("  📁 Could not detect app subfolder — using repo root '.'")
    return "."


# ── Stack configuration ───────────────────────────────────────────────────────

def resolve_stack_config(all_paths: list[str]) -> tuple[str, list[list[str]], list[str], list[str]]:
    """Return (app_dir, install_cmds, build_cmd, test_cmd)."""
    if STACK == "flutter":
        app_dir = detect_flutter_app_dir(all_paths)
        install  = [["flutter", "pub", "get"]]
        build    = ["flutter", "analyze", "--no-pub", "--fatal-warnings"]
        test     = ["flutter", "test", "--no-pub", "--reporter=compact"]
        return app_dir, install, build, test

    if STACK == "kotlin":
        return ".", [], \
            ["./gradlew", "compileKotlin", "--no-daemon", "-q"], \
            ["./gradlew", "test", "--no-daemon", "-q"]

    if STACK == "node":
        return ".", [["npm", "ci", "--prefer-offline"]], \
            ["npm", "run", "build"], \
            ["npm", "test", "--if-present"]

    return ".", [], [], []


def auto_fix_dart(app_dir: str) -> None:
    """
    Run `dart fix --apply` on the app directory to auto-correct lint issues
    that the AI commonly introduces:
      - unused_import       → removes hallucinated or leftover imports
      - annotate_overrides  → adds missing @override annotations
      - prefer_const_*      → const correctness

    This runs AFTER writing files and BEFORE flutter analyze, so the analyze
    step sees already-cleaned code. Many warning-level issues disappear entirely.
    """
    print(f"  🔧 dart fix --apply (in {app_dir}/)")
    ok, out = run(["dart", "fix", "--apply"], cwd=app_dir)
    if ok:
        changed = [l for l in out.splitlines() if "fix" in l.lower() or "change" in l.lower()]
        if changed:
            print("  ✅ dart fix applied:")
            for line in changed[:10]:
                print(f"     {line}")
        else:
            print("  ✅ dart fix: nothing to change")
    else:
        print(f"  ⚠️  dart fix warning (non-fatal): {out[:200]}")


# ── Error attribution ─────────────────────────────────────────────────────────

def parse_failing_files(error_output: str, all_paths: list[str]) -> list[str]:
    """
    Parse flutter analyze / compiler output to find which files had errors.
    If we can't detect specific files, returns all paths (full regeneration).
    """
    failing: list[str] = []
    for path in all_paths:
        if path in error_output or Path(path).name in error_output:
            failing.append(path)

    if not failing:
        print("  ⚠️  Could not attribute errors to specific files — regenerating all")
        return all_paths

    print(f"  🎯 Errors in {len(failing)} file(s): {', '.join(p.split('/')[-1] for p in failing)}")
    return failing


# ── Install / Build / Test ────────────────────────────────────────────────────

def install_deps(app_dir: str, install_cmds: list[list[str]]) -> tuple[bool, str]:
    for cmd in install_cmds:
        print(f"  📦 {' '.join(cmd)} (in {app_dir}/)")
        ok, out = run(cmd, cwd=app_dir)
        if not ok:
            return False, out
    return True, ""


def build_and_test(
    app_dir: str,
    build_cmd: list[str],
    test_cmd: list[str],
    touched_files: list[str],
    baseline_errors: set[str],
) -> tuple[bool, str]:
    # Auto-fix common lint issues before analyze (unused imports, missing @override, etc.)
    if STACK == "flutter":
        auto_fix_dart(app_dir)

    if build_cmd:
        print(f"  🏗️  {' '.join(build_cmd)} (in {app_dir}/)")
        ok, out = run(build_cmd, cwd=app_dir)
        if not ok:
            # Filter out baseline errors in files we did NOT touch
            new_errors = []
            for line in out.splitlines():
                cleaned = line.strip()
                if not cleaned:
                    continue

                # Check if this error line references any of our touched files
                is_touched = False
                for path in touched_files:
                    if path in line or Path(path).name in line:
                        is_touched = True
                        break

                if is_touched:
                    # We touched this file, so any error in it must be fixed/reported
                    new_errors.append(line)
                else:
                    # We did not touch this file. Only fail/report if it's a NEW error
                    if cleaned not in baseline_errors:
                        new_errors.append(line)

            if new_errors:
                filtered_output = "\n".join(new_errors)
                print(f"  ❌ Found {len(new_errors)} new error(s) introduced by this task:")
                for e in new_errors[:10]:
                    print(f"     {e}")
                return False, filtered_output
            else:
                print("  ✅ All build errors were pre-existing (baseline). Treating build as successful.")

    if test_cmd:
        print(f"  🧪  {' '.join(test_cmd)} (in {app_dir}/)")
        ok, out = run(test_cmd, cwd=app_dir)
        if not ok:
            if any(p in out.lower() for p in ["no tests ran", "0 tests", "no test files"]):
                print("  ℹ️  No tests found — skipping")
                return True, ""
            return False, out

    return True, ""


# ── Git helpers ───────────────────────────────────────────────────────────────

def git_commit(issue_number: str, title: str) -> None:
    run(["git", "add", "-A"])
    run(["git", "commit", "-m", f"feat(ai): implement #{issue_number} — {title[:72]}"])


def restore_files(originals: dict[str, str]) -> None:
    for path, content in originals.items():
        Path(path).write_text(content, encoding="utf-8")


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    print(f"\n{'='*60}")
    print(f"🚀 Sellio AI Agent  |  stack={STACK}  |  issue=#{ISSUE_NUMBER}")
    print(f"   Models: {' → '.join(GEMINI_MODELS)}")
    print(f"   Strategy: 1 batched API call per attempt (quota-efficient)")
    print(f"{'='*60}\n")

    try:
        plan = json.loads(PLAN_JSON)
    except json.JSONDecodeError as exc:
        print(f"❌ Invalid PLAN_JSON: {exc}")
        sys.exit(1)

    all_paths = plan.get("filesToModify", []) + plan.get("newFiles", [])
    print(f"Files to touch ({len(all_paths)}): {', '.join(all_paths) or 'none'}")

    existing = {p: read_file(p) for p in plan.get("filesToModify", [])}
    app_dir, install_cmds, build_cmd, test_cmd = resolve_stack_config(all_paths)

    # Make app_dir available globally so generate_files can pass it to the prompt builder
    global _current_app_dir
    _current_app_dir = app_dir

    print("\n📦 Installing dependencies...")
    ok, out = install_deps(app_dir, install_cmds)
    if not ok:
        print(f"⚠️  Dep install warning (continuing):\n{out[:1000]}")

    # Establish baseline errors to filter out pre-existing unrelated compiler/analyzer errors
    baseline_errors = set()
    if build_cmd:
        print("\n🔍 Establishing baseline analyzer/compiler state...")
        _, baseline_out = run(build_cmd, cwd=app_dir)
        for line in baseline_out.splitlines():
            cleaned = line.strip()
            if cleaned:
                baseline_errors.add(cleaned)
        print(f"   Found {len(baseline_errors)} baseline warning/error lines.")

    generated_files: dict[str, str] = {}
    paths_to_generate = list(all_paths)
    error_output = ""

    for attempt in range(1, MAX_RETRIES + 1):
        print(f"\n{'─'*50}")
        print(f"🔄 Attempt {attempt}/{MAX_RETRIES}  "
              f"({'all files' if attempt == 1 else f'{len(paths_to_generate)} failing file(s)'})")
        print(f"{'─'*50}")

        new_generated = generate_files(plan, existing, paths_to_generate, error_output)
        generated_files.update(new_generated)

        print("\n📝 Writing files...")
        for path, content in generated_files.items():
            write_file(path, content)

        print("\n🧪 Running checks...")
        ok, error_output = build_and_test(
            app_dir,
            build_cmd,
            test_cmd,
            touched_files=all_paths,
            baseline_errors=baseline_errors
        )

        if ok:
            print(f"\n✅ All checks passed on attempt {attempt}!")
            git_commit(ISSUE_NUMBER, plan.get("issueTitle", "AI implementation"))
            print("✅ Committed and ready to push.")
            sys.exit(0)

        print(f"\n❌ Attempt {attempt} failed.")
        if attempt < MAX_RETRIES:
            paths_to_generate = parse_failing_files(error_output, all_paths)
            print(f"🔁 Retrying with targeted feedback for {len(paths_to_generate)} file(s)...")
            restore_files({p: existing[p] for p in paths_to_generate if p in existing})
        else:
            print("❌ Max retries reached.")
            print(f"\nLast error output:\n{error_output[:2000]}")
            sys.exit(1)


if __name__ == "__main__":
    main()
