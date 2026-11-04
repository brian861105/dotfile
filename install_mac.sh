#!/bin/bash
set -euo pipefail
ROOT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

main() {
    local stage="${1:-shell}"
    if [[ $# -gt 1 ]]; then
        err "Usage: $0 [shell|tools|languages|neovim|git]"
    fi
    case "$stage" in
        shell|tools|languages|neovim) ;;
        git) setup_git; return ;;
        -h|--help) printf 'Usage: %s [shell|tools|languages|neovim|git]\n' "$0"; return ;;
        *) err "Unknown stage: $stage" ;;
    esac

    require curl
    require git
    install_homebrew
    brew update
    "install_$stage"
}

setup_git() {
    info "setting up git"
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.com commit
    git config --global alias.st status
    git config --global credential.helper osxkeychain

    # Updated git requires a way to resolve divergent, this makes it so divergent branch pulls
    # will only fast foward.  A diveragent branch will fail.  A normal thing to do is to pull a
    # into your working copy, such as "git pull origin master".  A divergence can occur if the
    # remote was force pushed with a missing ancestor from your local copy.
    git config --global pull.ff only

    if [ -z "$(git config --global --get user.name)" ]; then
        local user_name
        echo "Git user.name:"
        read -r user_name
        git config --global user.name "$user_name"
    fi
    if [ -z "$(git config --global --get user.email)" ]; then
        local user_email
        echo "Git user.email:"
        read -r user_email
        git config --global user.email "$user_email"
    fi
}

install_homebrew() {
    if ! check_cmd brew; then
        if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        else
            info "Installing homebrew"
            local installer
            installer=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
            /bin/bash -c "$installer"
            if [[ -x /opt/homebrew/bin/brew ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            else
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        fi
    fi
    eval "$(brew shellenv)"
}

install_packages() {
    brew install "$@"
    brew upgrade "$@"
}

install_languages() {
    install_packages --formula go lua node yarn luarocks sccache
    # nvm upstream does not support Homebrew installation.
    local nvm_installer
    nvm_installer=$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh)
    NVM_DIR="${NVM_DIR:-$HOME/.nvm}" PROFILE=/dev/null bash -c "$nvm_installer"

    if ! check_cmd rustup; then
        local installer
        installer=$(curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs)
        sh -c "$installer" -- -y --default-toolchain stable
        source "$HOME/.cargo/env"
    fi

    rustup update stable
    rustup update nightly
    rustup default stable
    rustup component add clippy --toolchain stable
    local toolchain
    for toolchain in stable nightly; do
        rustup target add \
            aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios \
            aarch64-apple-darwin x86_64-apple-darwin \
            aarch64-linux-android armv7-linux-androideabi i686-linux-android \
            wasm32-wasip1 wasm32-unknown-unknown --toolchain "$toolchain"
    done
    # Native Cargo supports WASI; cargo-wasi is archived.
    cargo +stable install --locked cargo-remote

    sym_link "$ROOT_PATH/cargo-config.toml" "$HOME/.cargo/config.toml"
}

install_shell() {
    info "Setting up Oh My Zsh environment..."

    # 1. install Oh My Zsh
    # 使用 --unattended 避免安裝後直接進入 zsh shell 中斷腳本
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        info "Installing Oh My Zsh..."
        local installer
        installer=$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)
        sh -c "$installer" "" --unattended
    else
        git -C "$HOME/.oh-my-zsh" pull --ff-only
    fi

    # define ZSH_CUSTOM variable
    local _zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # 2. install Powerlevel10k (Oh My Zsh way)
    if [ ! -d "$_zsh_custom/themes/powerlevel10k" ]; then
        info "Cloning Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$_zsh_custom/themes/powerlevel10k"
    else
        git -C "$_zsh_custom/themes/powerlevel10k" pull --ff-only
    fi

    # 3. install Plugins (install to custom/plugins)
    
    # zsh-autosuggestions
    if [ ! -d "$_zsh_custom/plugins/zsh-autosuggestions" ]; then
        info "Cloning zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$_zsh_custom/plugins/zsh-autosuggestions"
    else
        git -C "$_zsh_custom/plugins/zsh-autosuggestions" pull --ff-only
    fi

    # zsh-syntax-highlighting
    if [ ! -d "$_zsh_custom/plugins/zsh-syntax-highlighting" ]; then
        info "Cloning zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$_zsh_custom/plugins/zsh-syntax-highlighting"
    else
        git -C "$_zsh_custom/plugins/zsh-syntax-highlighting" pull --ff-only
    fi

    # 4. install Nerd Fonts (maintain original Brew method, this is the fastest way)
    install_packages --cask font-meslo-lg-nerd-font font-fira-code-nerd-font

    # 5. configuration file Symlink
    mkdir -p ~/.config
    sym_link "$ROOT_PATH/zsh/.zshrc" "$HOME/.zshrc"
    sym_link "$ROOT_PATH/zsh/.zfuncs" "$HOME/.zfuncs"
    sym_link "$ROOT_PATH/zsh/.zcustom" "$HOME/.zcustom"
    sym_link "$ROOT_PATH/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
}

install_neovim() {
    install_packages --formula neovim
}

install_tools() {
    brew tap hashicorp/tap
    # Homebrew 7 requires explicit trust for third-party packages.
    if brew help trust >/dev/null 2>&1; then
        brew trust --formula hashicorp/tap/vault
    fi

    install_packages --formula \
        ripgrep fzf fd bat eza zoxide jq yq grex hashicorp/tap/vault \
        tmux just \
        protobuf helm gh libpq kubernetes-cli kubectx \
        docker docker-compose colima
    
    install_packages --cask gcloud-cli visual-studio-code rectangle

    sym_link "$ROOT_PATH/tmux/tmux.conf" "$HOME/.tmux.conf"

    configure_docker
}

configure_docker() {
    require jq
    local config_dir="${DOCKER_CONFIG:-$HOME/.docker}"
    local config_file="$config_dir/config.json"
    if [[ -L "$config_file" ]]; then
        [[ -f "$config_file" ]] || err "Docker configuration link must resolve to a regular file: $config_file"
        config_file=$(realpath "$config_file")
        config_dir=$(dirname -- "$config_file")
    fi
    local plugin_path
    plugin_path="$(brew --prefix)/lib/docker/cli-plugins"
    mkdir -p "$config_dir"
    local input=/dev/stdin
    if [[ -e "$config_file" ]]; then
        input="$config_file"
    fi
    local temporary
    temporary=$(mktemp "$config_dir/config.json.XXXXXX")
    if ! jq -e -s --arg path "$plugin_path" '
        if length != 1 then error("Expected one Docker configuration object")
        else .[0] end |
        if type != "object" then error("Docker config must be an object")
        elif .cliPluginsExtraDirs != null and (.cliPluginsExtraDirs | type) != "array" then
            error("cliPluginsExtraDirs must be an array")
        else .cliPluginsExtraDirs = ((.cliPluginsExtraDirs // []) + [$path] | unique)
        end' "$input" <<< '{}' > "$temporary"; then
        rm -f "$temporary"
        err "Invalid Docker configuration: $config_file"
    fi
    mv "$temporary" "$config_file"
    info "Updated Docker CLI plugin directory"
}

uninstall_neovim() {
    rm -rf ~/.cache/nvim
    rm -rf ~/.local/share/nvim
}

## Utils

info() {
    printf '\r  [ \033[00;34m..\033[0m ] %s\n' "$1"
}

ok() {
    printf "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}

err() {
    printf '\r\033[2K  [\033[0;31mERR\033[0m] %s\n' "$1" >&2
    exit 1
}

ensure() {
    if ! "$@"; then err "command failed: $*"; fi
}

require() {
    if ! check_cmd "$1"; then
        err "need '$1' (command not found)"
    fi
}

check_cmd() {
    command -v "$1" >/dev/null 2>&1
}

append_not_exists() {
    if [ -f "$2" ] && grep -q "$1" "$2"; then
        info "PATH exists in \'$2\'"
        return
    fi

    info "\'$1\' >> \'$2\'"
    echo "$1" >>"$2"
}

sym_link() {
    [[ -e "$1" ]] || err "Missing symlink source: $1"
    if [[ -L "$2" && "$(readlink "$2")" == "$1" ]]; then
        info "Symlink skipped $1"
        return 0
    fi
    mkdir -p "$(dirname -- "$2")"
    if [[ -e "$2" || -L "$2" ]]; then
        [[ ! -e "$2.bak" && ! -L "$2.bak" ]] || err "Backup already exists: $2.bak"
        mv "$2" "$2.bak"
        info "Symlink moved $2 to $2.bak"
    fi
    ln -s "$1" "$2"
    info "Symlinked $1 to $2"
}

downloader() {
    local _dld
    if check_cmd curl; then
        _dld=curl
    elif check_cmd wget; then
        _dld=wget
    else
        _dld='curl or wget' # to be used in error message of require
    fi

    if [ "$1" = --check ]; then
        require "$_dld"
    elif [ "$_dld" = curl ]; then
        curl --proto '=https' --tlsv1.2 --silent --show-error --fail --location "$1" --output "$2"
    elif [ "$_dld" = wget ]; then
        wget --https-only --secure-protocol=TLSv1_2 "$1" -O "$2"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
