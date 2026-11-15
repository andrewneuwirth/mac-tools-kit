# Contributing

MacToolsKit is shared by every newi tools Mac app, so changes here reach all of them.

```sh
swift test                                   # Kit's checks
python3 tools/BuildJanitor/tests/selfcheck.py   # BuildJanitor's checks, no simulators or builds touched
```

- Apple frameworks only, no third-party dependencies.
- Token values (colours, spacing, radii, motion) follow the design system; change both together and say why in the PR.
- Small, focused changes; a one-line comment for each non-obvious *why*.
- Never put real names, paths, email addresses or credentials in code, tests or docs; use `/Users/YOU`, `example.com`.
- Swift 5 language mode.
