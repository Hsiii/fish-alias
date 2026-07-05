# fish-alias

Personal [Fish](https://fishshell.com/) aliases and helper functions that are not Git-specific.

This repo is a public mirror of my dotfiles-local general alias config. On my machine, `config.fish` is a symlink to `/Users/hsi/.config/fish/aliases.fish`.

## Combine with your own config

Source the config from your local Fish config:

```fish
source /Users/hsi/.config/fish/aliases.fish
```

## Command Reference

- `cf`: open this general Fish alias config in VS Code
- `cfg`: open the Git-focused Fish alias config in VS Code
- `debun`: kill Bun dev server processes started as `bun dev` or `bun run dev`
- `setcur "Project folder Name"`: create or update a symlink at `/Users/hsi/Projects/Current/Project folder Name`
- `decur "Project folder Name"`: remove a symlink at `/Users/hsi/Projects/Current/Project folder Name`
- `lscur`: list symlinks under `/Users/hsi/Projects/Current`

`setcur` searches for an exact folder name under `/Users/hsi/Projects`, skips `/Users/hsi/Projects/Current`, and refuses to replace a real folder with a symlink.
`decur` removes only symlinks under `/Users/hsi/Projects/Current` and refuses to remove real folders or files.
`lscur` prints current project symlinks as `name -> target`.

Examples:

```fish
setcur Comux
setcur "Project folder Name"
setcur /Users/hsi/Projects/DevTools/fish-alias
lscur
decur Comux
```
