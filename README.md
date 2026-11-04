
## VS Code key settings


Copy ```keybindings.json``` to your vscode settings dir.
```
~/.config/Code/User/
```
### New Keys
- ```c-k 1``` Join all editor groups
- ```c-k 2``` Split Editor Orthogonal
- ```c-k 3``` Split Editor

### Relevant keys
- ```c-1``` Switch to editor group 1
- ```c-2``` Switch to editor group 2
- ```c-3``` etc.

## tmux

`./install_mac.sh tools` installs or upgrades tools and links `tmux/tmux.conf` to
`~/.tmux.conf`.

Start a session with `tmux`, or reattach with `tmux attach`.
Press `Ctrl-b`, then `h/j/k/l` to switch panes, `%` to split left/right,
`"` to split top/bottom, `c` to create a window, or `d` to detach.

## macOS installation

For a new machine, run these stages in order from the repository directory:

```bash
./install_mac.sh tools
./install_mac.sh languages
./install_mac.sh neovim
./install_mac.sh shell
./install_mac.sh git       # Optional: Git aliases, credentials, and identity
```

Install tools, language environments, and Neovim before activating the shell
configuration that references them. Each package stage initializes Homebrew and
refreshes its metadata before installation.

Run `./install_mac.sh` (or `./install_mac.sh shell`) to update shell plugins, fonts,
and configuration links only; this is not a full installation. On an existing
machine, run only the stages you need. Package stages install/upgrade
their named packages. They stop on errors and preserve existing configuration in
`.bak`; an existing backup must be resolved before replacing another configuration.

See [the package review](docs/macos-packages.md) for versions, compatibility notes,
and the Alacritty installation limitation. Run isolated checks with
`python3 -m unittest discover -s tests -v`.
