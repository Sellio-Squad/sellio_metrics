#!/usr/bin/env python3
"""
Sellio AI Agent — ReAct (Reasoning + Acting) agent loop.

Architecture: real agent loop, NOT a single LLM call.

  Task → Search → Read → Write → Compile → Error → Search → Read → Fix → Compile → ...

The LLM decides ONE action per step. We execute it. The LLM sees the result.
It reasons again. It decides the next action. Repeats until flutter analyze
passes with no new errors, then the agent commits.

Available tools:
  search    — grep the repo for any class/method/widget definition
  read      — read any file in full
  list_dir  — list directory contents
  write     — write/overwrite a Dart file
  dart_fix  — run dart fix --apply
  analyze   — run flutter analyze (filtered to new errors only)
  done      — commit and finish (only when analyze is clean)
  fail      — give up (explains why)

Exit codes:
  0 → success (committed to current branch)
  1 → agent gave up or max steps reached
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

# Each step = 1 LLM call. 60 steps covers a full feature implementation.
MAX_STEPS = 60

GEMINI_MODELS = [
    "gemini-3.1-flash-lite",   # 500 RPD free — primary
    "gemini-2.5-flash-lite",   #  20 RPD free — fallback
    "gemini-2.5-flash",        #  20 RPD free — last resort
]
_model_index = 0

client = genai.Client(api_key=GEMINI_API_KEY)

# ── Low-level helpers ─────────────────────────────────────────────────────────

def run(cmd: list[str], cwd: str = ".") -> tuple[bool, str]:
    """Run a shell command. Returns (success, combined_output)."""
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
    print(f"  ✅ written: {path}")


def call_gemini(prompt: str) -> str:
    """Call Gemini with automatic rate-limit retry and model fallback."""
    global _model_index
    max_api_retries = 4

    for attempt in range(max_api_retries):
        model = GEMINI_MODELS[_model_index]
        try:
            response = client.models.generate_content(model=model, contents=prompt)
            if not response:
                raise ValueError("Gemini returned an empty response object")
            if response.text is None:
                finish_reason = "Unknown"
                if response.candidates and response.candidates[0].finish_reason:
                    finish_reason = str(response.candidates[0].finish_reason)
                raise ValueError(f"Gemini response.text is None. Finish reason: {finish_reason}")
            return response.text
        except Exception as e:
            err_str = str(e)
            is_retryable = (
                "429" in err_str or "RESOURCE_EXHAUSTED" in err_str
                or "503" in err_str or "UNAVAILABLE" in err_str
                or "500" in err_str or isinstance(e, ValueError)
            )
            if is_retryable:
                if "limit: 0" in err_str or isinstance(e, ValueError):
                    if _model_index < len(GEMINI_MODELS) - 1:
                        _model_index += 1
                        print(f"  ⚠️  {model} exhausted — switching to {GEMINI_MODELS[_model_index]}")
                        continue
                    else:
                        print("  ❌ All models exhausted.")
                        raise
                wait_match = re.search(r"retry in (\d+(?:\.\d+)?)s", err_str)
                wait_secs = min(float(wait_match.group(1)) if wait_match else 20.0, 65.0)
                print(f"  ⏳ Rate limited on {model}. Waiting {wait_secs:.0f}s... ({attempt+1}/{max_api_retries})")
                time.sleep(wait_secs)
                if attempt == max_api_retries - 1:
                    raise
            else:
                raise

    raise RuntimeError("Gemini call failed after all retries")


# ── Stack config ──────────────────────────────────────────────────────────────

def resolve_stack_config(all_paths: list[str]) -> tuple[str, list[list[str]], list[str], list[str]]:
    if STACK == "flutter":
        app_dir = "."
        for path in all_paths:
            parts = Path(path).parts
            for i in range(len(parts), 0, -1):
                candidate = str(Path(*parts[:i]))
                if (Path(candidate) / "pubspec.yaml").exists():
                    app_dir = candidate
                    break
            if app_dir != ".":
                break

        if app_dir == ".":
            for pub in sorted(Path(".").rglob("pubspec.yaml")):
                if "build" not in pub.parts and ".dart_tool" not in pub.parts:
                    app_dir = str(pub.parent)
                    break

        print(f"  📁 Scoped Flutter commands to: {app_dir}/")
        return (
            app_dir,
            [["flutter", "pub", "get"]],
            ["flutter", "analyze", "--no-pub", "--fatal-warnings"],
            ["flutter", "test", "--no-pub"],
        )
    elif STACK == "kotlin":
        return ".", [], ["./gradlew", "compileKotlin"], ["./gradlew", "test"]
    elif STACK == "node":
        return ".", [["npm", "ci"]], ["npm", "run", "build"], ["npm", "test"]
    return ".", [], [], []


def install_deps(app_dir: str, install_cmds: list[list[str]]) -> tuple[bool, str]:
    for cmd in install_cmds:
        print(f"  📦 {' '.join(cmd)} (in {app_dir}/)")
        ok, out = run(cmd, cwd=app_dir)
        if not ok:
            return False, out
    return True, ""


def git_commit(issue_number: str, title: str) -> None:
    run(["git", "add", "-A"])
    run(["git", "commit", "-m", f"feat(ai): implement #{issue_number} — {title[:72]}"])


# ── ReAct Agent ───────────────────────────────────────────────────────────────

AGENT_SYSTEM_PROMPT = """\
You are a senior Flutter/Dart engineer implementing a GitHub issue AUTONOMOUSLY.
You are running INSIDE the target repository with full file system read/write access.

## Your tools

| Tool       | Purpose                                                    |
|------------|------------------------------------------------------------|
| search     | Grep the repo for any class, method, widget, pattern       |
| read       | Read a file in full — ALWAYS do before using any API       |
| list_dir   | Explore directory structure                                |
| write      | Write or overwrite a complete Dart/ARB/YAML file           |
| dart_fix   | Run dart fix --apply (fixes unused imports, @override)     |
| analyze    | Run flutter analyze — shows only NEW errors you introduced |
| done       | Commit the task — ONLY when analyze shows no new errors    |
| fail       | Give up — ONLY if truly impossible                         |

## Mandatory workflow — follow this EXACTLY

STEP 1 — EXPLORE:
  - Call list_dir on lib/ to understand project structure.
  - Call list_dir on relevant subdirectories.

STEP 2 — RESEARCH (before writing ANY code):
  - For EVERY class/widget/repository you plan to use: call search, then read.
  - Example: need StoreRepository → search("StoreRepository") → read that file.
  - Example: need a widget → search("class WidgetName") → read its constructor.
  - NEVER assume a class exists or what its parameters are.

STEP 3 — WRITE:
  - Write files using ONLY verified APIs from files you have read.
  - Every import path must have been verified to exist via search.

STEP 4 — VERIFY:
  - Call dart_fix (fixes simple lint issues automatically).
  - Call analyze. Read every error carefully.

STEP 5 — FIX (if errors exist):
  - For EACH error: identify the missing symbol → search → read → fix the file.
  - NEVER retry by guessing. Every change must be based on code you have read.
  - Repeat steps 4-5 until analyze shows no new errors.

STEP 6 — DONE:
  - Call done when analyze is clean.

## Rules — violation causes compile failure
- NEVER invent a class name, method, constructor parameter, or import path.
- EVERY import must be verified to exist before writing it.
- If analyze says "undefined class X": search("class X"), read the file, fix.
- If analyze says "wrong parameter": read the class definition, use actual params.

## Response format — EXACTLY one JSON object per response, no other text

{
  "thought": "explain what you know and why you chose this action",
  "tool": "tool_name",
  "params": { ... }
}

Parameter reference:
  search:   { "query": "text to grep for" }
  read:     { "path": "relative/path/to/file.dart" }
  list_dir: { "path": "lib/path/to/dir" }
  write:    { "path": "path/to/file.dart", "content": "COMPLETE file content" }
  dart_fix: {}
  analyze:  {}
  done:     { "message": "what was implemented" }
  fail:     { "reason": "why this cannot be completed" }
"""


def parse_tool_call(text: str) -> dict | None:
    """Extract JSON tool call from LLM response. Tries multiple strategies."""
    text = text.strip()

    # Strategy 1: direct JSON parse
    try:
        obj = json.loads(text)
        if "tool" in obj:
            return obj
    except json.JSONDecodeError:
        pass

    # Strategy 2: extract from markdown code block
    for pattern in [r"```json\s*(\{.*?\})\s*```", r"```\s*(\{.*?\})\s*```"]:
        m = re.search(pattern, text, re.DOTALL)
        if m:
            try:
                obj = json.loads(m.group(1))
                if "tool" in obj:
                    return obj
            except json.JSONDecodeError:
                pass

    # Strategy 3: find first { ... } block by brace matching
    start = text.find("{")
    if start != -1:
        depth = 0
        for i, ch in enumerate(text[start:], start):
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    try:
                        obj = json.loads(text[start : i + 1])
                        if "tool" in obj:
                            return obj
                    except json.JSONDecodeError:
                        break
    return None


def execute_tool(
    tool: str,
    params: dict,
    app_dir: str,
    baseline_errors: set[str],
    written_files: set[str],
) -> str:
    """Execute a tool and return an observation string for the agent."""

    # ── search ────────────────────────────────────────────────────────────────
    if tool == "search":
        query = params.get("query", "").strip()
        if not query:
            return "Error: 'query' parameter is required."

        _, find_out = run(
            ["find", "lib", "-name", "*.dart", "-not", "-path", "*/build/*"],
            cwd=app_dir,
        )
        dart_files = [f for f in find_out.splitlines() if f.strip()]
        if not dart_files:
            return "No .dart files found under lib/. Verify app_dir."

        ok, grep_out = run(["grep", "-rn", query] + dart_files, cwd=app_dir)
        if grep_out.strip():
            lines = grep_out.splitlines()
            extra = f"\n... ({len(lines) - 80} more lines truncated)" if len(lines) > 80 else ""
            return f"Results for '{query}':\n" + "\n".join(lines[:80]) + extra
        return f"No matches for '{query}' across {len(dart_files)} dart files."

    # ── read ──────────────────────────────────────────────────────────────────
    elif tool == "read":
        path = params.get("path", "").strip()
        if not path:
            return "Error: 'path' parameter is required."
        content = read_file(path) or read_file(str(Path(app_dir) / path))
        if not content:
            return f"File not found or empty: {path}"
        truncated = f"\n... [{len(content)-8000} bytes omitted]" if len(content) > 8000 else ""
        return f"Content of '{path}':\n```dart\n{content[:8000]}\n```{truncated}"

    # ── list_dir ──────────────────────────────────────────────────────────────
    elif tool == "list_dir":
        path = params.get("path", "lib").strip()
        full = str(Path(app_dir) / path) if not Path(path).is_absolute() else path
        ok, out = run(
            ["find", full, "-maxdepth", "3", "-name", "*.dart",
             "-not", "-path", "*/build/*", "-not", "-path", "*/.dart_tool/*"],
            cwd=".",
        )
        if not out.strip():
            _, out = run(["ls", "-la", full])
        if not out.strip():
            return f"Directory not found or empty: {path}"
        lines = out.splitlines()
        extra = f"\n... ({len(lines)-100} more)" if len(lines) > 100 else ""
        return f"Files in '{path}':\n" + "\n".join(lines[:100]) + extra

    # ── write ─────────────────────────────────────────────────────────────────
    elif tool == "write":
        path = params.get("path", "").strip()
        content = params.get("content", "")
        if not path:
            return "Error: 'path' is required."
        if not content.strip():
            return "Error: 'content' is empty. Provide the full file content."
        write_file(path, content)
        written_files.add(path)
        return f"✅ Written '{path}' ({len(content)} bytes, {content.count(chr(10))} lines)"

    # ── dart_fix ──────────────────────────────────────────────────────────────
    elif tool == "dart_fix":
        print(f"  🔧 dart fix --apply (in {app_dir}/)")
        ok, out = run(["dart", "fix", "--apply"], cwd=app_dir)
        return f"dart fix result:\n{out[:3000]}"

    # ── analyze ───────────────────────────────────────────────────────────────
    elif tool == "analyze":
        print(f"  🏗️  flutter analyze (in {app_dir}/)")
        ok, out = run(["flutter", "analyze", "--no-pub", "--fatal-warnings"], cwd=app_dir)

        if ok:
            return "✅ flutter analyze: No issues found! Call done."

        new_lines = [
            line for line in out.splitlines()
            if line.strip() and line.strip() not in baseline_errors
        ]

        if not new_lines:
            return (
                "✅ All remaining errors are pre-existing (baseline). "
                "No new errors from your changes. Call done."
            )

        return (
            f"❌ flutter analyze: {len(new_lines)} new error(s) introduced by this task:\n"
            + "\n".join(new_lines[:100])
        )

    else:
        return (
            f"Unknown tool '{tool}'. "
            "Valid: search, read, list_dir, write, dart_fix, analyze, done, fail"
        )


def build_step_prompt(
    task_description: str,
    history: list[dict],
    step: int,
) -> str:
    """Build the full prompt for one agent step, including condensed history."""
    history_text = ""
    if history:
        # Keep first 3 steps (orientation) + last 22 (recent context)
        shown = history[:3] + history[max(3, len(history) - 22):]
        omitted = len(history) - len(shown)
        history_text = "\n## Steps taken so far:\n"
        if omitted > 0:
            history_text += f"[{omitted} earlier steps omitted]\n\n"
        for h in shown:
            history_text += (
                f"\n### Step {h['step']}\n"
                f"**Thought:** {h['thought']}\n"
                f"**Tool:** `{h['tool']}` | Params: `{json.dumps(h['params'])[:300]}`\n"
                f"**Result:**\n{h['result'][:2000]}\n"
            )

    return (
        f"{AGENT_SYSTEM_PROMPT}\n\n"
        f"{task_description}"
        f"{history_text}\n\n"
        f"---\nStep {step}/{MAX_STEPS}. "
        f"What is your next action? One JSON object only."
    )


def agent_loop(
    plan: dict,
    app_dir: str,
    baseline_errors: set[str],
) -> tuple[bool, str]:
    """Main ReAct loop. Returns (success, message)."""
    all_paths = plan.get("filesToModify", []) + plan.get("newFiles", [])

    task_description = (
        f"## Task: GitHub Issue #{ISSUE_NUMBER}\n"
        f"**Title:** {plan.get('issueTitle', '(no title)')}\n\n"
        f"**Summary:** {plan.get('summary', '')}\n\n"
        f"**Approach:** {plan.get('approach', '')}\n\n"
        f"**Files to create/modify:**\n"
        + "\n".join(f"  - `{p}`" for p in all_paths)
        + f"\n\n**App directory:** `{app_dir}/`\n\n"
    )

    history: list[dict] = []
    written_files: set[str] = set()
    consecutive_parse_failures = 0

    for step in range(1, MAX_STEPS + 1):
        print(f"\n{'─'*50}")
        print(f"🤖 Step {step}/{MAX_STEPS}")
        print(f"{'─'*50}")

        prompt = build_step_prompt(task_description, history, step)

        try:
            response_text = call_gemini(prompt)
        except Exception as exc:
            print(f"  ❌ Gemini call failed: {exc}")
            return False, f"LLM call failed: {exc}"

        tool_call = parse_tool_call(response_text)
        if not tool_call:
            consecutive_parse_failures += 1
            print(f"  ⚠️  Invalid JSON response (failure #{consecutive_parse_failures})")
            print(f"     Raw: {response_text[:300]}")
            if consecutive_parse_failures >= 3:
                return False, "Agent returned invalid JSON 3 times. Giving up."
            history.append({
                "step": step,
                "thought": "[parse error]",
                "tool": "error",
                "params": {},
                "result": (
                    "ERROR: Your response was not valid JSON. "
                    'Respond with exactly ONE JSON object: {"thought":"...","tool":"...","params":{...}}'
                    f"\nYour response was:\n{response_text[:400]}"
                ),
            })
            continue

        consecutive_parse_failures = 0
        thought = tool_call.get("thought", "")
        tool    = tool_call.get("tool", "")
        params  = tool_call.get("params", {})

        print(f"  💭 {thought[:120]}")
        print(f"  🔧 [{tool}] {json.dumps(params)[:120]}")

        if tool == "done":
            message = params.get("message", "Task complete")
            print(f"\n✅ Agent done: {message}")
            print(f"   Files written: {', '.join(written_files) or 'none'}")
            return True, message

        if tool == "fail":
            reason = params.get("reason", "Unknown")
            print(f"\n❌ Agent gave up: {reason}")
            return False, reason

        result = execute_tool(tool, params, app_dir, baseline_errors, written_files)
        print(f"  📤 {result.replace(chr(10), ' ')[:200]}")

        history.append({
            "step": step,
            "thought": thought,
            "tool": tool,
            "params": params,
            "result": result,
        })

    return False, f"Max steps ({MAX_STEPS}) reached."


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    print(f"\n{'='*60}")
    print(f"🚀 Sellio AI Agent  |  stack={STACK}  |  issue=#{ISSUE_NUMBER}")
    print(f"   Mode: ReAct Agent Loop  |  Max steps: {MAX_STEPS}")
    print(f"   Models: {' → '.join(GEMINI_MODELS)}")
    print(f"{'='*60}\n")

    try:
        plan = json.loads(PLAN_JSON)
    except json.JSONDecodeError as exc:
        print(f"❌ Invalid PLAN_JSON: {exc}")
        sys.exit(1)

    all_paths = plan.get("filesToModify", []) + plan.get("newFiles", [])
    print(f"Files to touch ({len(all_paths)}): {', '.join(all_paths) or 'none'}")

    app_dir, install_cmds, build_cmd, _ = resolve_stack_config(all_paths)

    print("\n📦 Installing dependencies...")
    ok, out = install_deps(app_dir, install_cmds)
    if not ok:
        print(f"⚠️  Dep install warning (continuing):\n{out[:1000]}")

    # Baseline: capture pre-existing errors so the agent only sees NEW ones
    baseline_errors: set[str] = set()
    if build_cmd:
        print("\n🔍 Capturing baseline analyzer state...")
        _, baseline_out = run(build_cmd, cwd=app_dir)
        for line in baseline_out.splitlines():
            c = line.strip()
            if c:
                baseline_errors.add(c)
        print(f"   {len(baseline_errors)} baseline lines captured (will be filtered from analyze output).")

    print("\n🤖 Starting ReAct agent loop...\n")
    success, message = agent_loop(plan, app_dir, baseline_errors)

    if success:
        git_commit(ISSUE_NUMBER, plan.get("issueTitle", "AI implementation"))
        print("\n✅ Committed. Ready for PR.")
        sys.exit(0)
    else:
        print(f"\n❌ Failed: {message}")
        sys.exit(1)


if __name__ == "__main__":
    main()
