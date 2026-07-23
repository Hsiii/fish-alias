# fish-alias

Fish helpers for managing private PR-media access.

This repo owns `/Users/hsi/.config/fish/aliases.fish` through a symlink to
`config.fish`.

## Setup

Source the config from your Fish config:

```fish
source /Users/hsi/.config/fish/aliases.fish
```

## Commands

- `prmedia -a name`: create a revocable PR-media token and setup script
- `prmedia -d name`: revoke a PR-media token
- `prmedia -l`: list active PR-media token names

Names may contain lowercase letters, numbers, underscores, and hyphens.

`prmedia -a alice` prints the one-time credentials and creates
`~/Downloads/pr-media-setup-alice.sh` with owner-only permissions. Send the
file securely. The recipient runs it with Bash to install credentials at
`~/.config/pr-media/config`.

The setup file contains the access token, so both copies should be deleted
after it succeeds. The command also prints instructions for installing the
`url=` and `token=` lines manually.

Examples:

```fish
prmedia -a alice
prmedia -d alice
prmedia -l
```
