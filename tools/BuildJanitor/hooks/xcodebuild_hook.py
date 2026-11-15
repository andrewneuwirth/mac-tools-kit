#!/usr/bin/python3
"""Claude Code hook for the Bash tool.

  pre   (PreToolUse):  rewrites `xcodebuild` (and `xcrun xcodebuild`) at a command
                       position to bin/agent-xcodebuild. Only that one word changes; the
                       rest of the command stays byte-identical, so quoting can't break.
                       Commands without xcodebuild get no output at all (left untouched).
                       Also snapshots the simulator list before any `simctl create/clone`.
  post (PostToolUse / PostToolUseFailure): diffs the simulator list against that
                       snapshot and appends new devices to agent-builds/simulators.json.

Any error inside the hook exits 0 silently, so a bug here can never block a command.
"""
import fcntl
import json
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

WRAPPER = str(Path(__file__).resolve().parent.parent / "bin" / "agent-xcodebuild")
ROOT = Path.home() / "Library/Caches/agent-builds"
REGISTRY = ROOT / "simulators.json"
SNAPSHOTS = ROOT / ".sim-snapshots"
SIM_NEW = re.compile(r"\bsimctl\s+(create|clone)\b")
# Docs: updatedInput is meant to be combined with "allow" (auto-approve) or "ask".
# None leaves the decision to the normal permission rules, which Claude Code evaluates
# against the rewritten command. If testing shows the rewrite is ignored without a
# decision, set this to "ask" (prompts) or "allow" (auto-approves the whole command).
DECISION = None

SEPARATORS = set(";&|()`\n")
# Words after which the next word is still a command: env/time-style prefixes and shell keywords.
PREFIXES = {"env", "time", "nohup", "exec", "command", "caffeinate", "nice", "builtin",
            "if", "then", "else", "elif", "do", "while", "until", "!", "{"}
ASSIGNMENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")


def xcodebuild_spans(cmd):
    """(start, end) of each `xcodebuild` / `.../xcodebuild` / `xcrun xcodebuild` that the
    shell would run as a command.

    shortcut: a tiny shell scanner, not a full parser. Not seen (left as is): xcodebuild
    inside quotes (bash -c '...', "$(...)"), `xcrun -sdk x xcodebuild`, `xargs xcodebuild`,
    and scripts that call xcodebuild themselves. Heredoc bodies are scanned as commands.
    Upgrade to a real parser (e.g. bashlex) if agents start hiding builds in those forms.
    """
    spans, i, n = [], 0, len(cmd)
    at_command, after_prefix, xcrun_at = True, False, None
    while i < n:
        c = cmd[i]
        if c in " \t":
            i += 1
            continue
        if cmd.startswith("$(", i):
            at_command, after_prefix, xcrun_at = True, False, None
            i += 2
            continue
        if c in SEPARATORS:
            at_command, after_prefix, xcrun_at = True, False, None
            i += 1
            continue
        if c == "#":  # comment to end of line
            j = cmd.find("\n", i)
            i = n if j < 0 else j
            continue
        start, plain = i, True
        while i < n:
            c = cmd[i]
            if c == "\\":
                i, plain = i + 2, False
            elif c == "'":
                j = cmd.find("'", i + 1)
                i, plain = (n if j < 0 else j + 1), False
            elif c == '"':
                j = i + 1
                while j < n and cmd[j] != '"':
                    j += 2 if cmd[j] == "\\" else 1
                i, plain = j + 1, False
            elif c in "<>":  # redirection: keep 2>&1, >|, >> inside this word
                i += 1
                if i < n and cmd[i] in "&>|":
                    i += 1
            elif c in " \t" or c in SEPARATORS or cmd.startswith("$(", i):
                break
            else:
                i += 1
        i = min(i, n)
        word = cmd[start:i]
        if not at_command:
            continue
        if plain and (word == "xcodebuild" or word.endswith("/xcodebuild")):
            spans.append((start if xcrun_at is None else xcrun_at, i))
            at_command = False
        elif plain and word == "xcrun" and xcrun_at is None:
            xcrun_at = start
        elif plain and xcrun_at is None and (ASSIGNMENT.match(word) or word in PREFIXES):
            after_prefix = word in PREFIXES or after_prefix
        elif plain and after_prefix and xcrun_at is None and word.startswith("-"):
            pass  # an option of a prefix, e.g. `caffeinate -i xcodebuild`
        else:
            at_command, after_prefix, xcrun_at = False, False, None
    return spans


def rewrite(cmd, wrapper=WRAPPER):
    for start, end in reversed(xcodebuild_spans(cmd)):
        cmd = cmd[:start] + shlex.quote(wrapper) + cmd[end:]
    return cmd


def sim_udids():
    out = subprocess.run(["xcrun", "simctl", "list", "devices", "-j"],
                         capture_output=True, text=True, timeout=30).stdout
    return {d["udid"]: d.get("name", "") for devs in json.loads(out)["devices"].values() for d in devs}


def snapshot_path(tool_use_id):
    return SNAPSHOTS / (re.sub(r"[^\w-]", "_", tool_use_id or "unknown") + ".json")


def record_new_sims(data, cmd):
    snap = snapshot_path(data.get("tool_use_id"))
    if not snap.exists():
        return
    before = json.loads(snap.read_text())
    snap.unlink()
    # shortcut: a diff, so a simulator you create in Xcode during the same second is
    # also logged, and a run_in_background create that finishes later is missed.
    new = {u: name for u, name in sim_udids().items() if u not in before}
    if not new:
        return
    ROOT.mkdir(parents=True, exist_ok=True)
    with open(ROOT / "simulators.json.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        reg = json.loads(REGISTRY.read_text()) if REGISTRY.exists() else []
        now = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        reg += [{"udid": u, "name": name, "created": now, "cwd": data.get("cwd"),
                 "session_id": data.get("session_id"), "command": cmd[:500]}
                for u, name in new.items()]
        tmp = REGISTRY.with_suffix(".tmp")
        tmp.write_text(json.dumps(reg, indent=2))
        tmp.replace(REGISTRY)


def main():
    event = sys.argv[1] if len(sys.argv) > 1 else "pre"
    data = json.load(sys.stdin)
    if data.get("tool_name") != "Bash":
        return
    tool_input = data.get("tool_input") or {}
    cmd = tool_input.get("command") or ""
    if event == "post":
        record_new_sims(data, cmd)
        return
    if SIM_NEW.search(cmd):
        SNAPSHOTS.mkdir(parents=True, exist_ok=True)
        snapshot_path(data.get("tool_use_id")).write_text(json.dumps(sim_udids()))
    new_cmd = rewrite(cmd)
    if new_cmd == cmd:
        return
    out = {
        "hookEventName": "PreToolUse",
        "updatedInput": {**tool_input, "command": new_cmd},  # replaces the whole input
        "additionalContext": "xcodebuild was routed through agent-xcodebuild: DerivedData lives in a "
                             "shared slot under ~/Library/Caches/agent-builds (path printed on stderr); "
                             "any -derivedDataPath you passed is a symlink to that slot.",
    }
    if DECISION:
        out["permissionDecision"] = DECISION
    print(json.dumps({"hookSpecificOutput": out}))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # never block a command because of this hook
        print(f"xcodebuild_hook: {e}", file=sys.stderr)
    sys.exit(0)
