#!/bin/bash
set -e
ROOT_PATH=$(pwd -P)

main() {
    downloader --check

    # setup_git
    # install_homebrew
    # install_languages
    install_shell
    # install_terminal
    # install_tools
}

setup_git() {
    info "setting up git"
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.com commit
    git config --global alias.st status
    git config --global credential.helper osxkeychain
    git config --global http.postBuffer 157286400

    # Updated git requires a way to resolve divergent, this makes it so divergent branch pulls
    # will only fast foward.  A diveragent branch will fail.  A normal thing to do is to pull a
    # into your working copy, such as "git pull origin master".  A divergence can occur if the
    # remote was force pushed with a missing ancestor from your local copy.
    git config --global pull.ff only

    if [ -z "$(git config --global --get user.email)" ]; then
        echo "Git user.name:"
        read -r user_name
        echo "Git user.email:"
        read -r user_email
        git config --global user.name "$user_name"
        git config --global user.email "$user_email"
    fi
}

install_homebrew() {
    if ! which /opt/homebrew/bin/brew >/dev/null 2>&1; then
        info "Installing homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    fi
    eval $(/opt/homebrew/bin/brew shellenv)
}

install_languages() {
    brew install go lua node nvm yarn luarocks || true

    if ! which rustup >/dev/null 2>&1; then
        curl https://sh.rustup.rs -sSf | sh -s -- -y
    	source ~/.cargo/env

        # Rust toolchains and commands
        rustup default stable
        rustup update nightly
        rustup component add clippy
        rustup target add \
            aarch64-apple-ios x86_64-apple-ios aarch64-apple-darwin \
            aarch64-linux-android armv7-linux-androideabi i686-linux-android \
            wasm32-wasi wasm32-unknown-unknown wasm32-unknown-unknown --toolchain nightly
    else
        rustup update
    fi

    # Rust specific tooling
	brew install sccache
    cargo install cargo-remote cargo-wasi

    # Custom global settings, requires cachepot
    sym_link $ROOT_PATH/cargo-config.toml ~/.cargo/config.toml
}

install_shell() {
    info "Setting up Oh My Zsh environment..."

    # 1. install Oh My Zsh
    # 使用 --unattended 避免安裝後直接進入 zsh shell 中斷腳本
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        info "Oh My Zsh is already installed."
    fi

    # define ZSH_CUSTOM variable
    local _zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # 2. install Powerlevel10k (Oh My Zsh way)
    if [ ! -d "$_zsh_custom/themes/powerlevel10k" ]; then
        info "Cloning Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$_zsh_custom/themes/powerlevel10k"
    else
        info "Powerlevel10k already exists."
    fi

    # 3. install Plugins (install to custom/plugins)
    
    # zsh-autosuggestions
    if [ ! -d "$_zsh_custom/plugins/zsh-autosuggestions" ]; then
        info "Cloning zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$_zsh_custom/plugins/zsh-autosuggestions"
    fi

    # zsh-syntax-highlighting
    if [ ! -d "$_zsh_custom/plugins/zsh-syntax-highlighting" ]; then
        info "Cloning zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$_zsh_custom/plugins/zsh-syntax-highlighting"
    fi

    # 4. install Nerd Fonts (maintain original Brew method, this is the fastest way)
    brew install font-meslo-lg-nerd-font font-fira-code-nerd-font || true

    # 5. configuration file Symlink
    mkdir -p ~/.config
    sym_link $ROOT_PATH/zsh/.zshrc ~/.zshrc
    sym_link $ROOT_PATH/zsh/.zfuncs ~/.zfuncs
    sym_link $ROOT_PATH/zsh/.zcustom ~/.zcustom
    sym_link $ROOT_PATH/zsh/.p10k.zsh ~/.p10k.zsh
}

install_terminal() {
    # install alacritty terminal and terminfo
    # #NOTE as of v0.9.0 release, M1 builds are not available through
    # brew, so a manual clone of alacritty and 'make app', and copy to /Applications is required
    # brew install alacritty || true
    ensure downloader https://raw.githubusercontent.com/alacritty/alacritty/master/extra/alacritty.info /Applications/Alacritty.app/Contents/Resources/alacritty.info
    info "setting terminal tic, sudo required"
    sudo tic -xe alacritty,alacritty-direct /Applications/Alacritty.app/Contents/Resources/alacritty.info
    info "configuring terminal"
    sym_link $ROOT_PATH/.alacritty.yml ~/.alacritty.yml
}

install_neovim() {
    brew install neovim || true
    info "configuring neovim"

    mkdir -p ~/.config
    sym_link $ROOT_PATH/nvim ~/.config/nvim

    nvim --headless +PlugInstall +PlugClean +PlugUpdate +UpdateRemotePlugins +qall
    # undo history path
    mkdir -p ~/.vimdid
}

install_tools() {
    brew tap kdash-rs/kdash
    brew tap hashicorp/tap

    brew install \
        ripgrep fzf fd rg bat eza zoxide jq grex hashicorp/tap/vault \
        zellij just \
        protobuf helm gh libpq google-cloud-sdk visual-studio-code \
        kubectl kubectx || true
    
    brew install --cask rectangle

    # # install google cloud components
    # gcloud components install gke-gcloud-auth-plugin

    sym_link $ROOT_PATH/zellij ~/.config/zellij

    # install docker
    brew install docker
    brew install docker-compose

    # setup docker compose plugin (configure ~/.docker/config.json)
    mkdir -p ~/.docker
    [ ! -f ~/.docker/config.json ] && echo "{}" > ~/.docker/config.json

    local _plugin_path="$(brew --prefix)/lib/docker/cli-plugins"
    local _config_file="$HOME/.docker/config.json"

    if check_cmd jq; then
         # Add plugin path to cliPluginsExtraDirs if not present
         jq --arg path "$_plugin_path" \
            '.cliPluginsExtraDirs = ((.cliPluginsExtraDirs // []) + [$path] | unique)' \
            "$_config_file" > "$_config_file.tmp" && mv "$_config_file.tmp" "$_config_file"
         info "Updated docker config.json with cliPluginsExtraDirs"
    else
         echo "jq not found, skipping docker config update. Please install jq."
    fi

    # install colima
    brew install colima
}

uninstall_neovim() {
    rm -rf ~/.cache/nvim
    rm -rf ~/.local/share/nvim
}

## Utils

info() {
    printf "\r  [ \033[00;34m..\033[0m ] $1\n"
}

ok() {
    printf "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}

err() {
    printf "\r\033[2K  [\033[0;31mERR\033[0m] $1\n"
    exit
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
    if [[ -f $2 ]]; then
        if [ -e "$2" ]; then
            if [ "$(readlink "$2")" = "$1" ]; then
                info "Symlink skipped $1"
                return 0
            else
                mv "$2" "$2.bak"
                info "Symlink moved $2 to $2.bak"
            fi
        fi
    fi
    ln -sf "$1" "$2"
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

main "$@"
