#!/usr/bin/env python3
"""
Sellio AI Agent — Multi-stack code implementation with real test execution.

Reads an implementation plan from the PLAN_JSON env var, generates code using
Gemini 2.0 Flash (1500 req/day free tier), writes files to disk, runs the
appropriate test/build command for the detected stack, and self-corrects on
failures. Up to MAX_RETRIES attempts.

Key features:
  - Scopes flutter commands to the specific app subfolder (monorepo safe)
  - On retry: only regenerates files that CAUSED errors (learns from faults)
  - Handles 429 rate-limit errors with exponential backoff (up to 60s wait)

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
from google.genai import errors as genai_errors

# ── Configuration ─────────────────────────────────────────────────────────────

GEMINI_API_KEY = os.environ["GEMINI_API_KEY"]
PLAN_JSON      = os.environ["PLAN_JSON"]
STACK          = os.environ.get("STACK", "unknown")
ISSUE_NUMBER   = os.environ.get("ISSUE_NUMBER", "0")
MAX_RETRIES    = 3

# gemini-2.0-flash: 1500 requests/day free (vs 25/day for gemini-2.5-flash)
GEMINI_MODEL = "gemini-2.0-flash"

client = genai.Client(api_key=GEMINI_API_KEY)

# ── Helpers ───────────────────────────────────────────────────────────────────

def run(cmd: list[str], cwd: str = ".") -> tuple[bool, str]:
    """Run a shell command. Returns (success, combined output)."""
    if not cmd:
        return True, ""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=300,
        )
        output = (result.stdout + "\n" + result.stderr).strip()
        success = result.returncode == 0
        if not success:
            print(f"  [exit {result.returncode}] {' '.join(cmd)}")
        return success, output
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


def strip_fences(text: str) -> str:
    """Remove markdown ``` fences from LLM output."""
    lines = text.strip().splitlines()
    if lines and lines[0].startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].strip() == "```":
        lines = lines[:-1]
    return "\n".join(lines).strip()


def call_gemini(prompt: str, retry_count: int = 3) -> str:
    """
    Call Gemini with automatic retry on 429 rate-limit errors.
    Waits up to 60 seconds when rate-limited before retrying.
    """
    for attempt in range(retry_count):
        try:
            response = client.models.generate_content(
                model=GEMINI_MODEL,
                contents=prompt,
            )
            return response.text
        except genai_errors.ClientError as e:
            if e.status_code == 429:
                # Parse the retry-after hint from the error message
                wait_match = re.search(r"retry in (\d+(?:\.\d+)?)s", str(e))
                wait_secs = min(float(wait_match.group(1)) if wait_match else 30.0, 60.0)
                print(f"  ⏳ Gemini rate-limited (429). Waiting {wait_secs:.0f}s before retry...")
                time.sleep(wait_secs)
                if attempt == retry_count - 1:
                    raise
            else:
                raise
    raise RuntimeError("Gemini call failed after all retries")


# ── Flutter app subfolder detection (monorepo safe) ──────────────────────────

def detect_flutter_app_dir(all_paths: list[str]) -> str:
    """
    Detect the target app subfolder from plan file paths.

    In a monorepo (e.g. sellio_mobile), files live under apps/customer/...
    Running flutter analyze at root picks up ALL apps (incl. broken ones like
    apps/admin). We scope commands to the specific app being modified.
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
        # Fallback: detect from apps/X pattern
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


# ── Error attribution: which files caused the failure? ───────────────────────

def parse_failing_files(error_output: str, all_paths: list[str]) -> list[str]:
    """
    Parse flutter analyze / compiler output to find which files had errors.

    flutter analyze format:
      error • <message> • path/to/file.dart:line:col • lint_code
    Returns paths from all_paths that appear in the error output.
    If we can't detect specific files, returns all_paths (full regeneration).
    """
    failing: list[str] = []
    for path in all_paths:
        # Match both full path and filename
        if path in error_output or Path(path).name in error_output:
            failing.append(path)

    if not failing:
        print("  ⚠️  Could not attribute errors to specific files — regenerating all")
        return all_paths

    print(f"  🎯 Errors attributed to {len(failing)} file(s): {', '.join(failing)}")
    return failing


# ── Stack configuration ───────────────────────────────────────────────────────

def resolve_stack_config(all_paths: list[str]) -> tuple[str, list[list[str]], list[str], list[str]]:
    """Return (app_dir, install_cmds, build_cmd, test_cmd)."""
    if STACK == "flutter":
        app_dir = detect_flutter_app_dir(all_paths)
        install  = [["flutter", "pub", "get"]]
        # --fatal-warnings only: info-level lint notes don't block the agent
        build    = ["flutter", "analyze", "--no-pub", "--fatal-warnings"]
        test     = ["flutter", "test", "--no-pub", "--reporter=compact"]
        return app_dir, install, build, test

    if STACK == "kotlin":
        return ".", [], ["./gradlew", "compileKotlin", "--no-daemon", "-q"], ["./gradlew", "test", "--no-daemon", "-q"]

    if STACK == "node":
        return ".", [["npm", "ci", "--prefer-offline"]], ["npm", "run", "build"], ["npm", "test", "--if-present"]

    return ".", [], [], []


# ── Code generation ───────────────────────────────────────────────────────────

LANG_HINT = {
    "flutter": "Dart / Flutter",
    "kotlin":  "Kotlin / Spring Boot 3 / JPA",
    "node":    "TypeScript / Node.js",
    "unknown": "the project's language",
}


def build_prompt(
    file_path: str,
    existing_content: str,
    plan: dict,
    all_paths: list[str],
    file_feedback: str,
) -> str:
    lang = LANG_HINT.get(STACK, "the project's language")
    existing_block = (
        f"## Current content of `{file_path}`:\n```\n{existing_content}\n```\n"
        if existing_content
        else f"## `{file_path}` does not exist yet — create it.\n"
    )
    feedback_block = (
        f"## ⚠️ This file had errors in the previous attempt — fix ONLY these issues:\n```\n{file_feedback[:2500]}\n```\n"
        if file_feedback
        else ""
    )
    cross_ref = "\n".join(
        f"  - `{p}` ({'modify' if p in plan.get('filesToModify', []) else 'create'})"
        for p in all_paths
        if p != file_path
    )

    return f"""You are a senior {lang} engineer implementing a GitHub issue.

## Issue
Title: {plan.get("issueTitle", "")}
Summary: {plan.get("summary", "")}
Approach: {plan.get("approach", "")}

## File to generate
`{file_path}`

{existing_block}

## Other files in this task (for cross-reference only):
{cross_ref or "  (none)"}

{feedback_block}

## Rules
- Output ONLY the complete final file content for `{file_path}`.
- Do NOT wrap output in markdown code fences.
- Do NOT include any explanation outside the code.
- All imports must reference files that actually exist in the repository.
- Match the existing style and conventions precisely.
- For {lang}: follow idiomatic patterns (null-safety, DI, etc.).
"""


def generate_files(
    plan: dict,
    existing: dict[str, str],
    paths_to_generate: list[str],
    error_output: str = "",
) -> dict[str, str]:
    """
    Generate (or regenerate) only the specified paths.

    On retry, error_output is parsed per-file so each prompt gets
    only the errors relevant to THAT file — the AI learns precisely.
    """
    all_paths = plan.get("filesToModify", []) + plan.get("newFiles", [])

    # Build per-file error context from the error output
    per_file_errors: dict[str, list[str]] = {}
    if error_output:
        for line in error_output.splitlines():
            for path in paths_to_generate:
                if path in line or Path(path).name in line:
                    per_file_errors.setdefault(path, []).append(line)

    result: dict[str, str] = {}
    for path in paths_to_generate:
        file_feedback = "\n".join(per_file_errors.get(path, []))
        if not file_feedback and error_output and path in paths_to_generate:
            # File is being regenerated but no specific lines attributed —
            # give it the full error for context
            file_feedback = error_output[:1500]

        print(f"  🤖 Generating: {path}")
        prompt = build_prompt(path, existing.get(path, ""), plan, all_paths, file_feedback)
        content = call_gemini(prompt)
        result[path] = strip_fences(content)
    return result


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
) -> tuple[bool, str]:
    """Run build (type-check/compile) then tests. Returns (ok, error_output)."""
    if build_cmd:
        print(f"  🏗️  {' '.join(build_cmd)} (in {app_dir}/)")
        ok, out = run(build_cmd, cwd=app_dir)
        if not ok:
            no_issues = "no issues found" in out.lower() or "0 issues" in out.lower()
            if not no_issues:
                return False, out

    if test_cmd:
        print(f"  🧪  {' '.join(test_cmd)} (in {app_dir}/)")
        ok, out = run(test_cmd, cwd=app_dir)
        if not ok:
            if any(phrase in out.lower() for phrase in ["no tests ran", "0 tests", "no test files"]):
                print("  ℹ️  No tests found — skipping")
                return True, ""
            return False, out

    return True, ""


# ── Git helpers ───────────────────────────────────────────────────────────────

def git_commit(issue_number: str, title: str) -> None:
    run(["git", "add", "-A"])
    run(["git", "commit", "-m", f"feat(ai): implement #{issue_number} — {title[:72]}"])


def restore_files(originals: dict[str, str]) -> None:
    """Restore original file contents before a retry."""
    for path, content in originals.items():
        Path(path).write_text(content, encoding="utf-8")


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    print(f"\n{'='*60}")
    print(f"🚀 Sellio AI Agent  |  stack={STACK}  |  model={GEMINI_MODEL}  |  issue=#{ISSUE_NUMBER}")
    print(f"{'='*60}\n")

    try:
        plan = json.loads(PLAN_JSON)
    except json.JSONDecodeError as exc:
        print(f"❌ Invalid PLAN_JSON: {exc}")
        sys.exit(1)

    all_paths = plan.get("filesToModify", []) + plan.get("newFiles", [])
    print(f"Files to touch ({len(all_paths)}): {', '.join(all_paths) or 'none'}")

    # Snapshot original file contents (for restore on retry)
    existing = {p: read_file(p) for p in plan.get("filesToModify", [])}

    # Resolve stack-specific commands (scoped to the right app dir)
    app_dir, install_cmds, build_cmd, test_cmd = resolve_stack_config(all_paths)

    # Install dependencies once before the retry loop
    print("\n📦 Installing dependencies...")
    ok, out = install_deps(app_dir, install_cmds)
    if not ok:
        print(f"⚠️  Dep install warning (continuing):\n{out[:1000]}")

    # Track which files are "good" across attempts to avoid regenerating them
    generated_files: dict[str, str] = {}
    paths_to_generate = list(all_paths)
    error_output = ""

    for attempt in range(1, MAX_RETRIES + 1):
        print(f"\n{'─'*50}")
        print(f"🔄 Attempt {attempt}/{MAX_RETRIES}")
        if attempt > 1:
            print(f"  🎓 Regenerating only {len(paths_to_generate)} failing file(s)")
        print(f"{'─'*50}")

        # Generate only the files that need it
        new_generated = generate_files(plan, existing, paths_to_generate, error_output)
        generated_files.update(new_generated)

        # Write ALL current files to disk
        print("\n📝 Writing files...")
        for path, content in generated_files.items():
            write_file(path, content)

        # Build + test
        print("\n🧪 Running checks...")
        ok, error_output = build_and_test(app_dir, build_cmd, test_cmd)

        if ok:
            print(f"\n✅ All checks passed on attempt {attempt}!")
            git_commit(ISSUE_NUMBER, plan.get("issueTitle", "AI implementation"))
            print("✅ Committed and ready to push.")
            sys.exit(0)

        print(f"\n❌ Attempt {attempt} failed.")
        if attempt < MAX_RETRIES:
            # Identify which files actually caused the errors
            paths_to_generate = parse_failing_files(error_output, all_paths)
            print(f"🔁 Retrying {len(paths_to_generate)} file(s) with targeted feedback...")
            # Restore only originals that will be regenerated
            restore_files({p: existing[p] for p in paths_to_generate if p in existing})
        else:
            print("❌ Max retries reached.")
            print(f"\nLast error output:\n{error_output[:2000]}")
            sys.exit(1)


if __name__ == "__main__":
    main()
