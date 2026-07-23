# fish-alias

Personal [Fish](https://fishshell.com/) aliases and helper functions that are not Git-specific.

This repo owns my general alias config. On my machine, `/Users/hsi/.config/fish/aliases.fish` is a symlink to this repo's `config.fish`.

## Combine with your own config

Source the config from your local Fish config:

```fish
source /Users/hsi/.config/fish/aliases.fish
```

## Command Reference

- `cf`: open this general Fish alias config in VS Code
- `cfg`: open the Git-focused Fish alias config in VS Code
- `debun`: kill Bun dev server processes started as `bun dev` or `bun run dev`
- `prmedia-onboard name`: create a revocable PR-media token and setup script for a friend
- `prmedia-revoke name`: revoke a friend's PR-media token
- `trycf [port] [project-name]`: expose a local dev server through Cloudflare Tunnel
- `setcur "Project folder Name"`: create or update a symlink at `/Users/hsi/Projects/Current/Project folder Name`
- `decur "Project folder Name"`: remove a symlink at `/Users/hsi/Projects/Current/Project folder Name`
- `lscur`: list symlinks under `/Users/hsi/Projects/Current`

`trycf` defaults to port `3000` and the current folder name. It starts a Cloudflare Quick Tunnel, prints the generated `trycloudflare.com` URL, and copies it to the clipboard. Install the dependency first with `brew install cloudflared`.

`trycf` also prepares a stable dev alias like `https://dev.hsichen.dev/homepage`. Set `TRYCF_REGISTER_URL` to a registrar endpoint if you want the function to POST the generated quick tunnel URL there:

```fish
set -Ux TRYCF_REGISTER_URL https://dev.hsichen.dev/__trycf/register
set -Ux TRYCF_REGISTER_TOKEN your-token
```

The registrar receives:

```json
{"project":"homepage","target":"https://example.trycloudflare.com","origin":"http://localhost:3000"}
```

You can override the displayed stable base URL with `TRYCF_DEV_BASE`.

`prmedia-onboard alice` prints the one-time credentials and creates
`~/Downloads/pr-media-setup-alice.sh` with owner-only permissions. Send that
file to your friend securely. They run it with Bash to install the credentials
at `~/.config/pr-media/config`; it refuses to overwrite an existing config and
checks whether the uploader from `Hsiii/human-out-of-loop` is already
available. The setup file contains the access token, so both copies should be
deleted after it succeeds. The command also prints the destination and
permissions for friends who prefer to paste the `url=` and `token=` lines
manually with an editor.

Use `prmedia-revoke alice` to disable Alice's token without affecting anyone
else.

`setcur` searches for an exact folder name under `/Users/hsi/Projects`, skips `/Users/hsi/Projects/Current`, and refuses to replace a real folder with a symlink.
`decur` removes only symlinks under `/Users/hsi/Projects/Current` and refuses to remove real folders or files.
`lscur` prints current project symlinks as `name -> target`.

Examples:

```fish
trycf
trycf 5173 Atomize
prmedia-onboard alice
prmedia-revoke alice
setcur Comux
setcur "Project folder Name"
setcur /Users/hsi/Projects/DevTools/fish-alias
lscur
decur Comux
```
