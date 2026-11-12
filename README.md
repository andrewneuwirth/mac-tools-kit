# Kit (MacToolsKit)

The Mac Tools family's shared code: the design-system tokens in Swift (colours, spacing, radii,
motion, status, partner colours), the usage reading Pier writes, the project list Pier and Projects share, the Open at Login toggle, and the
icon plate generator (`tools/icon.swift`). The design system itself:
the design system

Pier and Projects (and the other Mac Tools) depend on it **by path** (`../Kit`), so on a new Mac clone it
next to them, named `Kit`:

```sh
cd ~/Developer/Mac-Tools
git clone git@github.com:andrewneuwirth/mac-tools-kit.git Kit
```

`swift test` runs its checks.
