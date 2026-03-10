# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnosterzak"

plugins=(
    git
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Matugen dynamic shell colors (generated on wallpaper changes)
[[ -f "$HOME/.cache/matugen/zsh-colors.zsh" ]] && source "$HOME/.cache/matugen/zsh-colors.zsh"

# Prefer Matugen-generated Starship config when available
if [[ -f "$HOME/.cache/matugen/starship.toml" ]]; then
  export STARSHIP_CONFIG="$HOME/.cache/matugen/starship.toml"
else
  export STARSHIP_CONFIG="$HOME/.config/starship.toml"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Check archlinux plugin commands here
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/archlinux

# Display Pokemon-colorscripts
# Project page: https://gitlab.com/phoneybadger/pokemon-colorscripts#on-other-distros-and-macos
#pokemon-colorscripts --no-title -s -r #without fastfetch
#pokemon-colorscripts --no-title -s -r | fastfetch -c $HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -

# fastfetch. Will be disabled if above colorscript was chosen to install
fastfetch -c $HOME/.config/fastfetch/config-compact.jsonc

# Set-up icons for files/directories in terminal using lsd
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'

# Set-up FZF key bindings (CTRL R for fuzzy history finder)
source <(fzf --zsh)

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

# user-local executables
export PATH=/home/phuctruong/.local/bin:/home/phuctruong/.opencode/bin:/home/phuctruong/.bun/bin:$PATH

# Suppress noisy non-actionable Qt warnings from Quickshell runtime
export QT_LOGGING_RULES="quickshell.dbus.properties.warning=false;quickshell.service.notifications.warning=false;qt.svg.warning=false"

# Ensure manual `quickshell ...` runs also inherit the warning filter
quickshell() {
  QT_LOGGING_RULES="$QT_LOGGING_RULES" command quickshell "$@"
}

# bun completions
[ -s "/home/phuctruong/.bun/_bun" ] && source "/home/phuctruong/.bun/_bun"

# pnpm
export PNPM_HOME="/home/phuctruong/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
