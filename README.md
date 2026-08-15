# fish-alias

Personal [Fish](https://fishshell.com/) aliases and helper functions that are not Git-specific.

This repo owns my general alias config. On my machine, `/Users/hsi/.config/fish/aliases.fish` is a symlink to this repo's `config.fish`.

## Combine with your own config

Source the config from your local Fish config:

```fish
source /Users/hsi/.config/fish/aliases.fish
```

## Command Reference

- `debun`: show and stop all Bun dev server processes
- `dp`: switch to `main`, even when another worktree uses it, then deploy with Bun
- `forward [port]`: expose a local dev server through Cloudflare Tunnel

`forward` defaults to port `3000`. It uses the Git repository name, even inside a linked worktree, or falls back to the current folder name outside Git. It starts a Cloudflare Quick Tunnel, prints the generated `trycloudflare.com` URL, and copies it to the clipboard. Install the dependency first with `brew install cloudflared`.

Examples:

```fish
forward
forward 5173
```
