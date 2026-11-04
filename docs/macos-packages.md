# macOS package review

Checked 2026-11-04 against the official Homebrew JSON APIs. All 32 entries below
are available, neither disabled nor deprecated. Versions are a review snapshot;
`install_mac.sh` resolves stable versions when each stage runs rather than pinning
these patch numbers. Homebrew may also update required dependencies and dependents.

| Package | Stable version checked | Stage |
| --- | --- | --- |
| [go](https://formulae.brew.sh/formula/go) | 1.27.3 | `languages` |
| [lua](https://formulae.brew.sh/formula/lua) | 5.5.1 | `languages` |
| [node](https://formulae.brew.sh/formula/node) | 26.13.0 | `languages` |
| [yarn](https://formulae.brew.sh/formula/yarn) | 1.22.22 | `languages` |
| [luarocks](https://formulae.brew.sh/formula/luarocks) | 3.13.0 | `languages` |
| [sccache](https://formulae.brew.sh/formula/sccache) | 0.19.0 | `languages` |
| [ripgrep](https://formulae.brew.sh/formula/ripgrep) | 15.2.0 | `tools` |
| [fzf](https://formulae.brew.sh/formula/fzf) | 0.74.5 | `tools` |
| [fd](https://formulae.brew.sh/formula/fd) | 10.5.0 | `tools` |
| [bat](https://formulae.brew.sh/formula/bat) | 0.26.1 | `tools` |
| [eza](https://formulae.brew.sh/formula/eza) | 0.23.5 | `tools` |
| [zoxide](https://formulae.brew.sh/formula/zoxide) | 0.10.0 | `tools` |
| [jq](https://formulae.brew.sh/formula/jq) | 1.8.2 | `tools` |
| [yq](https://formulae.brew.sh/formula/yq) | 4.54.1 | `tools` |
| [grex](https://formulae.brew.sh/formula/grex) | 1.4.6 | `tools` |
| [tmux](https://formulae.brew.sh/formula/tmux) | 3.8 | `tools` |
| [just](https://formulae.brew.sh/formula/just) | 1.59.0 | `tools` |
| [protobuf](https://formulae.brew.sh/formula/protobuf) | 36.2 | `tools` |
| [helm](https://formulae.brew.sh/formula/helm) | 4.3.1 | `tools` |
| [gh](https://formulae.brew.sh/formula/gh) | 2.103.3 | `tools` |
| [libpq](https://formulae.brew.sh/formula/libpq) | 18.6 | `tools` |
| [kubernetes-cli](https://formulae.brew.sh/formula/kubernetes-cli) | 1.37.2 | `tools` |
| [kubectx](https://formulae.brew.sh/formula/kubectx) | 0.11.0 | `tools` |
| [docker](https://formulae.brew.sh/formula/docker) | 29.9.3 | `tools` |
| [docker-compose](https://formulae.brew.sh/formula/docker-compose) | 5.7.0 | `tools` |
| [colima](https://formulae.brew.sh/formula/colima) | 0.10.3 | `tools` |
| [neovim](https://formulae.brew.sh/formula/neovim) | 0.12.6 | `neovim` |
| [font-meslo-lg-nerd-font](https://formulae.brew.sh/cask/font-meslo-lg-nerd-font) | 3.5.1 | `shell` |
| [font-fira-code-nerd-font](https://formulae.brew.sh/cask/font-fira-code-nerd-font) | 3.5.1 | `shell` |
| [gcloud-cli](https://formulae.brew.sh/cask/gcloud-cli) | 592.0.0 | `tools` |
| [visual-studio-code](https://formulae.brew.sh/cask/visual-studio-code) | 1.144.1 | `tools` |
| [rectangle](https://formulae.brew.sh/cask/rectangle) | 2.0.4 | `tools` |

Other installers and configuration decisions:

- [Homebrew](https://docs.brew.sh/Installation): use the official installer, detect Apple Silicon and Intel prefixes, and run `brew update` before package stages.
- [Vault](https://github.com/hashicorp/homebrew-tap/blob/master/Formula/vault.rb): official HashiCorp tap, reviewed stable release 2.2.1. On Homebrew versions supporting tap trust, trust only `hashicorp/tap/vault`; remove the unused kdash tap.
- [nvm](https://github.com/nvm-sh/nvm#installing-and-updating): official v0.40.8 installer (the current release reviewed), because upstream does not support Homebrew installation. `PROFILE=/dev/null` keeps the installer from modifying tracked shell files. The zsh configuration prefers this installation and falls back to the existing Homebrew installation. The old formula is not automatically uninstalled.
- [Node.js](https://nodejs.org/en/about/previous-releases): the checked 26.13.0 release is LTS. The `node` formula tracks stable releases, which will not always be LTS. Keep nvm for project-specific versions; this repair does not replace existing project defaults.
- [Yarn](https://yarnpkg.com/migration/guide): Homebrew packages Classic 1.22.22. Retain it for existing compatibility; moving individual projects to modern Yarn requires reviewing their lockfiles and plugins. This is not a claim that Classic is the best choice for new projects.
- [Rust](https://blog.rust-lang.org/2026/10/15/Rust-1.99.1/): reviewed stable release 1.99.1. Update stable/nightly on each language-stage run, use stable as default, install stable Clippy, and reapply the same cross-compilation targets to both stable and nightly even when rustup already exists.
- [WASI](https://doc.rust-lang.org/rustc/platform-support/wasm32-wasip1.html): replace removed `wasm32-wasi` with `wasm32-wasip1`; remove archived [cargo-wasi](https://github.com/bytecodealliance/cargo-wasi) and use native Cargo target support.
- [cargo-remote](https://crates.io/crates/cargo-remote): latest stable 0.2.0, last published in 2021 according to the crates.io API. Retain it because `zsh/.zfuncs/cargo-build-remote` invokes it. Use stable Cargo and the published lockfile; compilation and remote-host compatibility were not exercised, so compatibility with current Rust is not established by this version check.
- [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh), [Powerlevel10k](https://github.com/romkatv/powerlevel10k), [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), and [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting): clone upstream when absent; otherwise pull fast-forward only. These follow upstream branches, not pinned releases; local edits/history are never reset.
- [Alacritty](https://github.com/alacritty/alacritty/releases): Homebrew cask 0.17.0 is [disabled](https://github.com/Homebrew/homebrew-cask/blob/master/Casks/a/alacritty.rb) for Gatekeeper failure. Remove the obsolete installer and references to the nonexistent `.alacritty.yml`; use official releases manually if needed. This script does not bypass Gatekeeper or silently choose another terminal.
- Neovim: install/upgrade the editor without linking the nonexistent `nvim/` directory or invoking an unconfigured Vim-Plug installation.
- [Docker Compose](https://formulae.brew.sh/formula/docker-compose): retain the documented `cliPluginsExtraDirs` configuration; respect `DOCKER_CONFIG`, preserve other keys, validate JSON, deduplicate the plugin path, and replace the file atomically. Preserve configuration symlinks by updating their resolved regular-file targets; reject dangling or cyclic links without changing them.
- [kubectl compatibility](https://kubernetes.io/releases/version-skew-policy/#kubectl): a client must be within one minor version of the API server. No cluster version is recorded here, so the newest formula is not a guarantee of cluster compatibility. [Helm](https://helm.sh/docs/topics/version_skew/) compatibility and major-version/plugin migration must also match the actual cluster and projects.
- Git configuration: retain aliases, macOS credential storage and fast-forward-only pulls; remove the blanket HTTP postBuffer override, which is not a general network fix. Check name and email separately and prompt only for missing fields, preserving existing values.
- Configuration links: resolve repository paths from the script location, back up existing files/directories/broken links, skip correct links, and refuse to overwrite a previous `.bak`.

Verification: isolated Python tests exercise script entry points, required-command
failure, upgrade scoping, symlink preservation, and real jq JSON updates. Shell
syntax is checked separately. No full installation, Cargo build, cluster access,
or update of user repositories was performed.
