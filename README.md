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
- `prmedia -a name`: create a revocable PR-media token and setup script for a friend
- `prmedia -d name`: revoke a friend's PR-media token
- `prmedia -l`: list active PR-media token names
- `media add <path>`: upload an image or short video for sharing and copy its URL
- `forward [port]`: expose a local dev server through Cloudflare Tunnel

`forward` defaults to port `3000`. It uses the Git repository name, even inside a linked worktree, or falls back to the current folder name outside Git. It starts a Cloudflare Quick Tunnel, prints the generated `trycloudflare.com` URL, and copies it to the clipboard. Install the dependency first with `brew install cloudflared`.

`prmedia -a alice` prints the one-time credentials and creates
`~/Downloads/pr-media-setup-alice.sh` with owner-only permissions. Send that
file to your friend securely. They run it with Bash to install the credentials
at `~/.config/pr-media/config`; it refuses to overwrite an existing config and
checks whether the uploader from `Hsiii/human-out-of-loop` is already
available. The setup file contains the access token, so both copies should be
deleted after it succeeds. The command also prints the destination and
permissions for friends who prefer to paste the `url=` and `token=` lines
manually with an editor.

Use `prmedia -d alice` to disable Alice's token without affecting anyone else.
Use `prmedia -l` to list active token names.

`media add <path>` uploads directly to the Oracle media host over SSH and copies
the public URL to the clipboard. MOV and oversized MP4 videos are converted to
720p with macOS `avconvert` before upload. This private SSH path accepts videos
up to 500 MiB; the public API's smaller limit is unchanged. Standalone media is
unreferenced and may be evicted if the media filesystem reaches its cleanup
watermark.

Examples:

```fish
forward
forward 5173
prmedia -a alice
prmedia -d alice
prmedia -l
media add ~/Downloads/demo.mov
```
