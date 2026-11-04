# ==============================================================================
# 1. P10k Instant Prompt (Must remain at the very top)
# ==============================================================================
# Enable Powerlevel10k instant prompt.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==============================================================================
# 2. Environment & Path Settings (Pre-OMZ)
# ==============================================================================
# Load Homebrew Environment first so plugins can detect installed tools
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Global Editors
export EDITOR='vim'
export KUBE_EDITOR='nvim'

# FZF Configuration (Using ripgrep for better performance)
export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob '!.git'"

# ==============================================================================
# 3. Oh My Zsh Configuration
# ==============================================================================
export ZSH="$HOME/.oh-my-zsh"

# Set Theme to Powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins Configuration
# Notes:
# - zoxide: Replaces 'cd' (auto-initializes via plugin)
# - fzf: Integrated fuzzy finder
# - kubectl: Autocompletion and 'k' alias
# - rust: Cargo/rustc autocompletion
# - zsh-autosuggestions: Gray text suggestions based on history
# - zsh-syntax-highlighting: Must be the last plugin in the list
plugins=(
    git
    zoxide
    fzf
    kubectl
    rust
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# ==============================================================================
# 4. User Configuration
# ==============================================================================

# --- History Settings ---
HISTFILE=~/.zsh_history
SAVEHIST=10000
HISTSIZE=50000
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_verify            # show command with history expansion to user before running it
setopt share_history          # share command history data

# --- Custom File Loaders ---
# Load all custom .zsh files from ~/.zcustom
for file in ~/.zcustom/*.zsh; do
    source "$file"
done

# --- Functions & Completions ---
# Add custom functions path
fpath=(
    ~/.zfuncs
    $HOMEBREW_PREFIX/share/zsh/site-functions
    "${fpath[@]}"
)

# Autoload custom functions
autoload -Uz b64hex
autoload -Uz cargo-build-remote
autoload -Uz cp-agence-remote
autoload -Uz k8s-pod-bash
autoload -Uz k8s-pod-forcedelete

# --- External Tool Integrations (Manual Loading) ---

# Google Cloud SDK
if [ -f "$HOMEBREW_PREFIX/share/google-cloud-sdk/path.zsh.inc" ]; then
    source "$HOMEBREW_PREFIX/share/google-cloud-sdk/path.zsh.inc"
    source "$HOMEBREW_PREFIX/share/google-cloud-sdk/completion.zsh.inc"
fi

# NVM (Node Version Manager)
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    source "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
elif [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]; then
    source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
    [ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && source "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"
fi

# --- Key Bindings ---
bindkey "^ " autosuggest-accept
bindkey "^[[1;3D" backward-word
bindkey "^[[1;3C" forward-word

# --- Aliases ---
alias g="git"
alias j="just"
alias cat="bat -pp --theme 'Visual Studio Dark+'"
alias catt="bat --theme 'Visual Studio Dark+'"

# Modern 'ls' replacements using 'eza' (installed via your script)
# Note: 'ls -l --git' is valid for eza, but not standard ls
alias ls='eza --icons'
alias ll="eza -l --git --icons"
alias la="ll -a"

# Function Aliases
alias kpbash="k8s-pod-bash"
alias kpfd="k8s-pod-forcedelete"
alias cb-remote="cargo-build-remote"

# --- Extra PATH Exports ---
export WASMTIME_HOME="$HOME/.wasmtime"
export PATH="$PATH:/$WASMTIME_HOME/bin"
export PATH="$PATH:/Users/teddylee/.foundry/bin"
export PATH="$PATH:/Applications/Alacritty.app/Contents/MacOS"
export PATH="$PATH:/opt/homebrew/opt/libpq/bin"

# ==============================================================================
# 5. Powerlevel10k Configuration (Must remain at the bottom)
# ==============================================================================
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Added by Antigravity
export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"

alias vi='nvim'
alias vim='nvim'
alias oldvim='/usr/bin/vim'
