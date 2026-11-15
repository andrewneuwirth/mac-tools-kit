# Kit (MacToolsKit)

MacToolsKit: the shared code behind the newi tools Mac apps: the design-system tokens in Swift (colours, spacing, radii,
motion, status, partner colours), the usage reading Pier writes, the project list Pier and Projects share, the Open at Login toggle, and the
icon plate generator (`tools/icon.swift`). The tokens mirror the newi tools design system; change a value there and here together.

The apps use a checkout next to them named `Kit` when there is one, otherwise SwiftPM fetches this repo. To work on
Kit and an app together, clone it next to the app:

```sh
git clone https://github.com/andrewneuwirth/mac-tools-kit.git Kit
```

`swift test` runs its checks.

`tools/BuildJanitor` holds BuildJanitor, the Claude Code hook and nightly janitor that keep agent Xcode
builds and simulators from filling the disk (Python, see its README). Point its hooks at your
checkout's `tools/BuildJanitor` (or a symlink to it).

## License

[MIT](LICENSE). Contributing: [CONTRIBUTING.md](CONTRIBUTING.md). Security: [SECURITY.md](SECURITY.md).
