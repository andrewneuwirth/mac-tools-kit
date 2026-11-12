#!/usr/bin/python3
"""Assert-based self-check: command rewriting and slot picking. Runs nothing real.
    /usr/bin/python3 tests/selfcheck.py
"""
import importlib.util
import os
import tempfile
from importlib.machinery import SourceFileLoader
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent


def load(name, path):
    loader = SourceFileLoader(name, str(path))
    mod = importlib.util.module_from_spec(importlib.util.spec_from_loader(name, loader))
    loader.exec_module(mod)
    return mod


hook = load("hook", HERE / "hooks/xcodebuild_hook.py")
wrap = load("wrap", HERE / "bin/agent-xcodebuild")
W = "/W/agent-xcodebuild"


def rw(cmd):
    return hook.rewrite(cmd, W)


# Rewritten: only the command word changes, everything else byte-identical.
cases = {
    "xcodebuild -scheme App build": f"{W} -scheme App build",
    'cd "my dir" && xcodebuild -project "A B.xcodeproj" -derivedDataPath build/dd1 build | xcpretty':
        f'cd "my dir" && {W} -project "A B.xcodeproj" -derivedDataPath build/dd1 build | xcpretty',
    "xcrun xcodebuild -version": f"{W} -version",
    "FOO=1 time -p xcodebuild test 2>&1 | tail -5": f"FOO=1 time -p {W} test 2>&1 | tail -5",
    "APP=$(xcodebuild -showBuildSettings | grep X)": f"APP=$({W} -showBuildSettings | grep X)",
    "/usr/bin/xcodebuild build": f"{W} build",
    "make && xcodebuild build; xcodebuild test": f"make && {W} build; {W} test",
    "echo it\\'s; xcodebuild": f"echo it\\'s; {W}",
    "caffeinate -i xcodebuild -scheme 'P W' build >/tmp/log 2>&1 &":
        f"caffeinate -i {W} -scheme 'P W' build >/tmp/log 2>&1 &",
    "(cd ios\nxcodebuild build)": f"(cd ios\n{W} build)",
    "if xcodebuild build; then echo ok; fi": f"if {W} build; then echo ok; fi",
    "env DEVELOPER_DIR=/X xcodebuild": f"env DEVELOPER_DIR=/X {W}",
}
for src, want in cases.items():
    got = rw(src)
    assert got == want, f"\n  in:   {src!r}\n  got:  {got!r}\n  want: {want!r}"

# Untouched: no xcodebuild at a command position.
for src in [
    "git status && npm test",
    'echo "xcodebuild done"; grep xcodebuild log.txt',
    "which xcodebuild",
    "ls # xcodebuild build",
    "bash -c 'xcodebuild build'",  # known limit: quoted commands are not rewritten
    "xcrun simctl list devices",
    "cat 'unterminated",
    "",
    "echo $(( 1 + 2 )) | xargs echo",
]:
    assert rw(src) == src, f"changed: {src!r} -> {rw(src)!r}"

# Wrapper path with a space gets quoted.
assert hook.rewrite("xcodebuild", "/a b/w") == "'/a b/w'"

# simctl detection.
assert hook.SIM_NEW.search('UDID=$(xcrun simctl create "Demo · Phone" "iPhone 17")')
assert hook.SIM_NEW.search("xcrun simctl clone ABC new")
assert not hook.SIM_NEW.search("xcrun simctl list")

# Argument handling in the wrapper.
assert wrap.split_derived_data(["-scheme", "A", "-derivedDataPath", "build/dd1", "build"]) == \
    (["-scheme", "A", "build"], "build/dd1")
assert wrap.project_slug(["-workspace", "ios/Demo App.xcworkspace"], "/x") == "demo-app"
assert wrap.project_slug(["-project", "Foo.xcodeproj/"], "/x") == "foo"
assert wrap.project_slug(["build"], "/Users/a/Developer/MyApp") == "myapp"

# Slot picking.
with tempfile.TemporaryDirectory() as tmp:
    proj = Path(tmp) / "app"
    held = [wrap.acquire_slot(proj, wait=False) for _ in range(3)]
    assert [n for n, _ in held] == [1, 2, 3], held
    assert wrap.acquire_slot(proj, wait=False) == (None, None), "4th build must wait"
    os.close(held[1][1])  # build in slot 2 ends (same as the process dying)
    n, fd = wrap.acquire_slot(proj, wait=False)
    assert n == 2, n
    for f in (fd, held[0][1], held[2][1]):
        os.close(f)
    n, fd = wrap.acquire_slot(proj, prefer=3, wait=False)
    assert n == 3, "preferred slot first when free"
    os.close(fd)
    # The agent's own -derivedDataPath symlinked to slot-2 makes slot 2 preferred.
    (proj / "slot-2").mkdir()
    (Path(tmp) / "build").mkdir()
    (Path(tmp) / "build/dd1").symlink_to(proj / "slot-2")
    assert wrap.preferred_slot(proj, "build/dd1", tmp) == 2
    assert wrap.preferred_slot(proj, "build/other", tmp) is None
    assert wrap.preferred_slot(proj, None, tmp) is None

print("selfcheck: all good")
