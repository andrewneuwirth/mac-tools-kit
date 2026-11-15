# Security

Please report vulnerabilities privately through GitHub: the repository's **Security** tab → **Report a vulnerability**,
or email hello@newitools.app. Don't open a public issue for a security problem.

In scope: anything that could expose data through the shared code (the usage file, the projects list, the login item),
and BuildJanitor's hooks and cleanup (it rewrites `xcodebuild` commands and deletes build folders and simulators, so a
bug that deletes the wrong thing matters). There is no hosted service to test.
