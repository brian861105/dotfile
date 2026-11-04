# macOS installer contract

Status: adopted (2026-11-04); 20 isolated regression tests pass. Real installation
and upstream builds are unverified.

The caller runs `install_mac.sh [shell|tools|languages|neovim|git]` from any
directory. No argument continues to select only `shell`. Invalid arguments fail
before installation. Package stages initialize Homebrew and refresh its metadata;
they install missing packages and explicitly request upgrades only for their named
packages (Homebrew may also update dependencies/dependents). Formulas and casks are
explicit. Any failed required command stops the stage with nonzero status.
The script may be sourced to exercise its functions without running installation.

Shell repositories are cloned when missing and otherwise updated with a fast-forward
pull. Local modifications and diverging history are never reset. nvm uses its
upstream-supported installer at the audited v0.40.8 release; shell loading prefers
that installation with a Homebrew fallback for existing machines. Existing Yarn
workflows stay compatible; changing package managers is outside this repair.
Rust uses stable by default and configures the same cross-compilation targets for
both stable and nightly on every run. A default Cargo cross-compilation command must
not lack its target merely because it was installed only for nightly. Archived
cargo-wasi is replaced by native Cargo WASI support.
Neovim installation does not assume an absent configuration or plugin manager.
The obsolete Alacritty setup is removed: its cask is disabled and this repository
has no Alacritty configuration; official manual installation remains available.

Configuration links use the script directory as their source. Correct links are
idempotent. Existing files, directories, and broken links move to `.bak` before
replacement. An existing backup is never overwritten; a missing source fails
without changing the destination.

Docker Compose registration respects `DOCKER_CONFIG`, preserves unrelated JSON
settings, and includes the Homebrew plugin directory once. A malformed/empty JSON
file or non-array plugin list fails without replacing the original. The replacement
is written through a private temporary file in the same directory and renamed only
after successful validation; failed temporary files are removed. An existing
configuration symlink remains intact: resolve it to an existing regular file and
atomically replace that target using a temporary file in the target's directory.
Relative and absolute links are supported. Dangling/cyclic links fail before
creating a temporary file or changing either the link or its target.

Git setup checks `user.name` and `user.email` independently. If exactly one field is
missing, prompt for and write only that field; keep the existing field unchanged.

For a new machine, the documented order is `tools`, `languages`, `neovim`, then
`shell`, with optional `git` setup. Install tools and editor dependencies before
activating the shell configuration that references them. No argument still selects
only `shell`; this correction does not add a full-install entry point.

Observable scenarios are verified in `tests/test_install_mac.py`: stage selection,
required package failure, package upgrade scope, directory-independent source paths,
link idempotency/backup preservation, and Docker JSON preservation/failure/retry.
Package availability and release status require live upstream verification; isolated
tests intentionally do not install software or update user repositories.
