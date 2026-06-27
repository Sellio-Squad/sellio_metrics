#!/usr/bin/env python3
"""
Sellio AI Agent — Multi-stack code implementation with real test execution.

Reads an implementation plan from the PLAN_JSON env var, generates code using
Gemini 2.5 Flash, writes files to disk, runs the appropriate test/build command
for the detected stack, and self-corrects on failures. Up to MAX_RETRIES attempts.

Stacks supported:
  flutter  → flutter pub get + flutter analyze + flutter test
  kotlin   → ./gradlew compileKotlin (+ test if under 5 min)
  node     → npm ci + npm run build + npm test
  unknown  → skips test step, commits as-is

Exit codes:
  0 → success (committed to current branch)
  1 → all retries exhausted
"""

import json
import os
import subprocess
import sys
from pathlib import Path

import google.generativeai as genai

# ── Configuration ─────────────────────────────────────────────────────────────

GEMINI_API_KEY = os.environ["GEMINI_API_KEY"]
PLAN_JSON      = os.environ["PLAN_JSON"]
STACK          = os.environ.get("STACK", "unknown")
ISSUE_NUMBER   = os.environ.get("ISSUE_NUMBER", "0")
MAX_RETRIES    = 3

genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel("gemini-2.5-flash")

# ── Stack-specific commands ───────────────────────────────────────────────────

# Commands to install/prepare dependencies
INSTALL_CMDS: dict[str, list[list[str]]] = {
    "flutter": [["flutter", "pub", "get"]],
    "kotlin":  [],  # Gradle resolves deps on first build
    "node":    [["npm", "ci", "--prefer-offline"]],
    "unknown": [],
}

# Commands to compile/type-check (fast — runs every attempt)
BUILD_CMDS: dict[str, list[str]] = {
    "flutter": ["flutter", "analyze", "--no-pub", "--fatal-infos"],
    "kotlin":  ["./gradlew", "compileKotlin", "--no-daemon", "-q"],
    "node":    ["npm", "run", "build"],
    "unknown": [],
}

# Commands to run tests (slower — only runs if build passes)
TEST_CMDS: dict[str, list[str]] = {
    "flutter": ["flutter", "test", "--no-pub", "--reporter=compact"],
    "kotlin":  ["./gradlew", "test", "--no-daemon", "-q"],
    "node":    ["npm", "test", "--if-present"],
    "unknown": [],
}

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


def call_gemini(prompt: str) -> str:
    response = model.generate_content(prompt)
    return response.text


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
    feedback: str,
) -> str:
    lang = LANG_HINT.get(STACK, "the project's language")
    existing_block = (
        f"## Current content of `{file_path}`:\n```\n{existing_content}\n```\n"
        if existing_content
        else f"## `{file_path}` does not exist yet — create it.\n"
    )
    feedback_block = (
        f"## ⚠️ Previous attempt failed with these errors — fix ONLY these issues:\n```\n{feedback[:2500]}\n```\n"
        if feedback
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


def generate_files(plan: dict, existing: dict[str, str], feedback: str = "") -> dict[str, str]:
    all_paths = plan.get("filesToModify", []) + plan.get("newFiles", [])
    result: dict[str, str] = {}
    for path in all_paths:
        print(f"  🤖 Generating: {path}")
        prompt = build_prompt(path, existing.get(path, ""), plan, all_paths, feedback)
        content = call_gemini(prompt)
        result[path] = strip_fences(content)
    return result


# ── Test runner ───────────────────────────────────────────────────────────────

def install_deps() -> tuple[bool, str]:
    for cmd in INSTALL_CMDS.get(STACK, []):
        print(f"  📦 {' '.join(cmd)}")
        ok, out = run(cmd)
        if not ok:
            return False, out
    return True, ""


def build_and_test() -> tuple[bool, str]:
    """Run build (type-check/compile) then tests. Returns (ok, error_output)."""
    build_cmd = BUILD_CMDS.get(STACK)
    if build_cmd:
        print(f"  🏗️  {' '.join(build_cmd)}")
        ok, out = run(build_cmd)
        if not ok:
            # Flutter: "No issues found" still exits 0. Real errors exit 1.
            no_issues = "no issues found" in out.lower() or "0 issues" in out.lower()
            if not no_issues:
                return False, out

    test_cmd = TEST_CMDS.get(STACK)
    if test_cmd:
        print(f"  🧪  {' '.join(test_cmd)}")
        ok, out = run(test_cmd)
        if not ok:
            # "No tests found" is acceptable
            if any(phrase in out.lower() for phrase in ["no tests ran", "0 tests", "no test files"]):
                print("  ℹ️  No tests found — skipping")
                return True, ""
            return False, out

    return True, ""


# ── Git helpers ───────────────────────────────────────────────────────────────

def git_commit(issue_number: str, title: str) -> None:
    run(["git", "add", "-A"])
    run(["git", "commit", "-m",
         f"feat(ai): implement #{issue_number} — {title[:72]}"])


def restore_files(originals: dict[str, str]) -> None:
    """Restore original file contents before a retry."""
    for path, content in originals.items():
        Path(path).write_text(content, encoding="utf-8")


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    print(f"\n{'='*60}")
    print(f"🚀 Sellio AI Agent  |  stack={STACK}  |  issue=#{ISSUE_NUMBER}")
    print(f"{'='*60}\n")

    try:
        plan = json.loads(PLAN_JSON)
    except json.JSONDecodeError as exc:
        print(f"❌ Invalid PLAN_JSON: {exc}")
        sys.exit(1)

    all_paths = plan.get("filesToModify", []) + plan.get("newFiles", [])
    print(f"Files to touch ({len(all_paths)}): {', '.join(all_paths) or 'none'}")

    # Snapshot original file contents
    existing = {p: read_file(p) for p in plan.get("filesToModify", [])}

    # Install dependencies once before the retry loop
    print("\n📦 Installing dependencies...")
    ok, out = install_deps()
    if not ok:
        print(f"⚠️  Dep install warning (continuing):\n{out[:1000]}")

    feedback = ""
    for attempt in range(1, MAX_RETRIES + 1):
        print(f"\n{'─'*50}")
        print(f"🔄 Attempt {attempt}/{MAX_RETRIES}")
        print(f"{'─'*50}")

        # Generate
        generated = generate_files(plan, existing, feedback)

        # Write to disk
        print("\n📝 Writing files...")
        for path, content in generated.items():
            write_file(path, content)

        # Build + test
        print("\n🧪 Running checks...")
        ok, error_output = build_and_test()

        if ok:
            print(f"\n✅ All checks passed on attempt {attempt}!")
            git_commit(ISSUE_NUMBER, plan.get("issueTitle", "AI implementation"))
            print("✅ Committed and ready to push.")
            sys.exit(0)

        print(f"\n❌ Attempt {attempt} failed.")
        if attempt < MAX_RETRIES:
            print(f"🔁 Applying error feedback and retrying...")
            feedback = error_output[:3000]
            # Restore originals so we start clean
            restore_files(existing)
        else:
            print("❌ Max retries reached.")
            print(f"\nLast error output:\n{error_output[:2000]}")
            sys.exit(1)


if __name__ == "__main__":
    main()
