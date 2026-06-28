#!/usr/bin/env python3
"""
Sellio AI Agent — Multi-stack code implementation with real test execution.

Reads an implementation plan from the PLAN_JSON env var, generates code using
Gemini 2.5 Flash, writes files to disk, runs the appropriate test/build command
for the detected stack, and self-corrects on failures. Up to MAX_RETRIES attempts.

Stacks supported:
  flutter  → flutter pub get + flutter analyze + flutter test (scoped to app subfolder)
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

from google import genai

# ── Configuration ─────────────────────────────────────────────────────────────

GEMINI_API_KEY = os.environ["GEMINI_API_KEY"]
PLAN_JSON      = os.environ["PLAN_JSON"]
STACK          = os.environ.get("STACK", "unknown")
ISSUE_NUMBER   = os.environ.get("ISSUE_NUMBER", "0")
MAX_RETRIES    = 3

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


def call_gemini(prompt: str) -> str:
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt,
    )
    return response.text


# ── App subfolder detection (Flutter monorepo support) ────────────────────────

def detect_flutter_app_dir(all_paths: list[str]) -> str:
    """
    Detect the target app subfolder from the plan's file paths.

    In a monorepo like sellio_mobile, files are under apps/customer/...
    Running flutter analyze at the root picks up ALL apps (including broken ones
    like apps/admin). We scope the analyze command to the specific app being modified.

    Returns the deepest common prefix that contains a pubspec.yaml.
    Falls back to "." if we can't determine it.
    """
    candidates: list[Path] = []
    for p in all_paths:
        parts = Path(p).parts
        # Walk up from the file and find the first dir that has pubspec.yaml
        for i in range(len(parts) - 1, 0, -1):
            candidate = Path(*parts[:i])
            if (candidate / "pubspec.yaml").exists():
                candidates.append(candidate)
                break

    if not candidates:
        # Try common monorepo conventions: apps/customer, apps/merchant, etc.
        for p in all_paths:
            parts = Path(p).parts
            if len(parts) >= 2 and parts[0] == "apps":
                candidate = Path(parts[0]) / parts[1]
                if candidate.is_dir():
                    candidates.append(candidate)
                    break

    if candidates:
        # Use the most common candidate
        from collections import Counter
        most_common = Counter(str(c) for c in candidates).most_common(1)[0][0]
        print(f"  📁 Scoped Flutter commands to: {most_common}/")
        return most_common

    print("  📁 Could not detect app subfolder — using repo root '.'")
    return "."


# ── Stack-specific commands ───────────────────────────────────────────────────

LANG_HINT = {
    "flutter": "Dart / Flutter",
    "kotlin":  "Kotlin / Spring Boot 3 / JPA",
    "node":    "TypeScript / Node.js",
    "unknown": "the project's language",
}


def get_flutter_commands(app_dir: str) -> tuple[list[list[str]], list[str], list[str]]:
    """
    Return (install_cmds, build_cmd, test_cmd) scoped to app_dir.
    We use --no-fatal-infos (only warnings are fatal) to avoid info-level lint
    issues in external packages triggering a failure.
    """
    install  = [["flutter", "pub", "get"]]
    # --fatal-warnings only: info-level lints (e.g. missing analysis_options in
    # sibling apps) don't block the agent.
    build    = ["flutter", "analyze", "--no-pub", "--fatal-warnings"]
    test     = ["flutter", "test", "--no-pub", "--reporter=compact"]
    return install, build, test


# ── Code generation ───────────────────────────────────────────────────────────

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

def install_deps(app_dir: str, install_cmds: list[list[str]]) -> tuple[bool, str]:
    for cmd in install_cmds:
        print(f"  📦 {' '.join(cmd)} (in {app_dir}/)")
        ok, out = run(cmd, cwd=app_dir)
        if not ok:
            return False, out
    return True, ""


def build_and_test(app_dir: str, build_cmd: list[str], test_cmd: list[str]) -> tuple[bool, str]:
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

    # Detect Flutter app subfolder (scopes pub get + analyze to the right app)
    if STACK == "flutter":
        app_dir = detect_flutter_app_dir(all_paths)
        install_cmds, build_cmd, test_cmd = get_flutter_commands(app_dir)
    elif STACK == "kotlin":
        app_dir = "."
        install_cmds = []
        build_cmd = ["./gradlew", "compileKotlin", "--no-daemon", "-q"]
        test_cmd  = ["./gradlew", "test", "--no-daemon", "-q"]
    elif STACK == "node":
        app_dir = "."
        install_cmds = [["npm", "ci", "--prefer-offline"]]
        build_cmd = ["npm", "run", "build"]
        test_cmd  = ["npm", "test", "--if-present"]
    else:
        app_dir = "."
        install_cmds, build_cmd, test_cmd = [], [], []

    # Install dependencies once before the retry loop
    print("\n📦 Installing dependencies...")
    ok, out = install_deps(app_dir, install_cmds)
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
        ok, error_output = build_and_test(app_dir, build_cmd, test_cmd)

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
