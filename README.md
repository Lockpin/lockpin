# Lockpin

A hard spend cap for AI agents. Lockpin prices every call at its worst case and refuses the one that won't fit, before it reaches the provider. Your keys never leave your machine.

This repository holds Lockpin's releases. Website and docs: **https://lockpin.dev**

## Install

macOS and Linux:

```sh
curl --proto '=https' --tlsv1.2 -fsSL https://lockpin.dev/install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://lockpin.dev/install.ps1 | iex
```

The installers download a release from this repository and check it against its `SHA256SUMS` before installing.

## Licence

Lockpin is free to use. It is proprietary software and its source code is not published. See [lockpin.dev/terms](https://lockpin.dev/terms).

## Security

Report a vulnerability to security@lockpin.dev, not in a public issue.
