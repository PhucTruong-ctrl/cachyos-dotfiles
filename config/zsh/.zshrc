# ── Oh My Zsh ─────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"  # overridden by starship below
plugins=(git sudo docker)
source $ZSH/oh-my-zsh.sh

# ── PATH ──────────────────────────────────────────────
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"

# ── Editor ────────────────────────────────────────────
export EDITOR='vim'

# ── GITHUB_TOKEN (for MCP github server) ──────────────
if command -v gh &>/dev/null; then
    export GITHUB_TOKEN="$(gh auth token 2>/dev/null)"
fi

# ── Package management aliases ────────────────────────
alias update="sudo pacman -Syu && paru -Sua"
alias cleanup="sudo pacman -Rns \$(pacman -Qdtq) 2>/dev/null; sudo paccache -r"

# ── Git aliases ───────────────────────────────────────
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gpl="git pull"
alias gd="git diff"
alias gl="git log --oneline --graph"

# ── eza (modern ls replacement) ───────────────────────
alias ls="eza --icons --group-directories-first"
alias ll="eza -la --icons --group-directories-first --git"
alias la="eza -a --icons --group-directories-first"
alias lt="eza --tree --icons --level=2"

# ── bat (modern cat replacement) ──────────────────────
alias cat="bat --paging=never"
alias catp="bat"  # bat with pager

# ── fd (modern find) ─────────────────────────────────
alias find="fd"

# ── fzf ───────────────────────────────────────────────
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
source <(fzf --zsh 2>/dev/null)

# ── zoxide (smart cd) ────────────────────────────────
eval "$(zoxide init zsh)"

# ── direnv ────────────────────────────────────────────
if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# ── starship prompt (overrides Oh My Zsh theme) ──────
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi
