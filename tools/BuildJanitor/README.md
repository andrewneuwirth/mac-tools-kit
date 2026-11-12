# BuildJanitor

Stops Claude Code agents from filling the disk with Xcode builds and simulator copies.

Agents pass their own `-derivedDataPath` (build/dd1, build/dd2, $SCRATCHPAD/dd, /tmp/ph-device, ...) so parallel builds don't collide. That made 2,000+ full clean builds of several GB each in 30 days, none ever deleted. They also create simulators that pile up (67 GB in CoreSimulator/Devices).

The fix: every agent `xcodebuild` goes through a wrapper that uses one of 3 shared, reused DerivedData slots per project (builds become incremental too), simulators agents create are logged, and a nightly janitor deletes what's stale.

## Where it lives

The code lives in the Kit repo at `Kit/tools/BuildJanitor`. `~/Developer/Mac-Tools/BuildJanitor` is a symlink to it, so the absolute paths below (Claude Code hooks, the launchd plist) keep working. On a new Mac, clone Kit and recreate the link:

```sh
cd ~/Developer/Mac-Tools && ln -s Kit/tools/BuildJanitor BuildJanitor
```

## Layout

| Path | What it is |
|---|---|
| `bin/agent-xcodebuild` | Same args as xcodebuild. Swaps `-derivedDataPath` for `~/Library/Caches/agent-builds/<project>/slot-<n>`, first free of 3 (flock, freed when the build ends or dies). All busy: waits. The agent's own path becomes a symlink to the slot, so `build/dd1/Build/Products/...` still works. |
| `hooks/xcodebuild_hook.py` | Claude Code hook for Bash. `pre` rewrites `xcodebuild` / `xcrun xcodebuild` to the wrapper (only that word changes) and snapshots simulators before `simctl create/clone`. `post` logs new UDIDs to `~/Library/Caches/agent-builds/simulators.json`. |
| `bin/buildjanitor` | Cleanup. Dry run by default; deletes only with `--apply`. |
| `launchd/app.newitools.buildjanitor.plist` | Runs `buildjanitor --apply` nightly at 03:30. Not installed. |
| `tests/selfcheck.py` | Assert-based check of the rewriting and slot picking. |

Plain Python 3 (`/usr/bin/python3`, stdlib only).

## Check

```sh
/usr/bin/python3 tests/selfcheck.py
bin/buildjanitor              # dry run: lists what it would delete, nothing is touched
```

## Install (after your OK)

```sh
chmod +x bin/agent-xcodebuild bin/buildjanitor hooks/xcodebuild_hook.py
```

Merge into the `hooks` object of `~/.claude/settings.json` (keep the AgentNotify entries already there):

```json
"PreToolUse": [
  { "matcher": "Bash", "hooks": [ { "type": "command", "command": "/usr/bin/python3 /Users/YOU/Developer/Mac-Tools/BuildJanitor/hooks/xcodebuild_hook.py pre" } ] }
],
"PostToolUse": [
  { "matcher": "Bash", "hooks": [ { "type": "command", "command": "/usr/bin/python3 /Users/YOU/Developer/Mac-Tools/BuildJanitor/hooks/xcodebuild_hook.py post" } ] }
],
"PostToolUseFailure": [
  { "matcher": "Bash", "hooks": [ { "type": "command", "command": "/usr/bin/python3 /Users/YOU/Developer/Mac-Tools/BuildJanitor/hooks/xcodebuild_hook.py post" } ] }
]
```

The hook returns `hookSpecificOutput.updatedInput` with no `permissionDecision`, so the normal permission rules decide (Claude Code checks them against the rewritten command). The docs pair `updatedInput` with `"allow"` or `"ask"`. If the rewrite doesn't take effect in a live test, set `DECISION = "ask"` at the top of the hook. `"allow"` works too, but it auto-approves the whole compound command.

Nightly cleanup:

```sh
cp launchd/app.newitools.buildjanitor.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/app.newitools.buildjanitor.plist
# log: ~/Library/Logs/buildjanitor.log
```

## What buildjanitor looks at

- **Agent build slots** `~/Library/Caches/agent-builds/*/slot-*`: deleted if untouched for 2+ days and not locked by a running build.
- **Stray DerivedData** under `~/Developer` (5 levels deep) and `/private/tmp` (6 levels, covers agent scratchpads and `/tmp/ph-device`). A folder counts only if it has `Build/` plus `Logs`, `ModuleCache.noindex`, `Index.noindex`, `info.plist` or `SourcePackages`, and it is named `dd*`, `DerivedData*` or `derived*`, or sits in a `build/` folder, or is in /tmp. Deleted if untouched for 2+ days. Skips `.git`, `node_modules`, `Pods`, `.build` and symlinks. `~/Library/Developer/Xcode/DerivedData` (the owner's own Xcode) is never scanned.
- **Agent simulators** (UDIDs in `simulators.json`): deleted if not booted for 7+ days.
- **Unavailable simulators**: `xcrun simctl delete unavailable`.
- **Needs your OK**: every other simulator, including the 25 that existed before the registry ("Demo · Phone", "Demo-UX-Audit-...", "demo-duo"), listed with size and a `xcrun simctl delete <udid>` line. Never deleted automatically.
- Prints the total for `~/Library/Caches/agent-builds` and warns above 40 GB.

## Limits

- The hook sees only the Bash command text. Not rewritten: `xcodebuild` inside quotes (`bash -c '...'`, `"$(...)"`), `xcrun -sdk x xcodebuild`, `xargs xcodebuild`, and scripts that call xcodebuild themselves. The CLAUDE.md text below covers those.
- `-showBuildSettings` without the agent's own `-derivedDataPath` reports slot-1, which may not be the slot its next build gets.
- Simulators are logged by diffing the device list before and after the command, so a `run_in_background` create that finishes later is missed, and a simulator the owner creates in Xcode in that same moment gets logged too.
- If the wrapper itself gets `kill -9`, its slot frees while xcodebuild keeps running.
- 3 slots per project name, shared across worktrees of the same project.

## Proposed text for ~/.claude/CLAUDE.md (not applied)

```md
## Xcode builds and simulators
- Build only with plain `xcodebuild ...` (a hook routes it through
  ~/Developer/Mac-Tools/BuildJanitor/bin/agent-xcodebuild) or call that wrapper directly.
  It gives each project 3 shared, incremental DerivedData slots under
  ~/Library/Caches/agent-builds and waits when all are busy. Don't invent new
  DerivedData folders (build/dd1, $SCRATCHPAD/dd, /tmp/...) and don't hide xcodebuild
  inside `bash -c` or scripts to get around it. Find products from the path the wrapper
  prints, or keep using your -derivedDataPath: it becomes a symlink to the slot.
- Don't create or clone simulators unless the owner asks. Use an existing booted or
  available one (`xcrun simctl list devices available`). If you must create one, do it
  from a plain Bash command (so it gets logged), and delete it when you're done.
```
