source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# opencode
fish_add_path /home/phuctruong/.opencode/bin

# === CachyOS dotfiles additions ===

# Package management aliases
alias update "sudo pacman -Syu && paru -Sua"
alias cleanup "sudo pacman -Rns (pacman -Qdtq) 2>/dev/null; sudo paccache -r"

# Git aliases
alias gs "git status"
alias ga "git add"
alias gc "git commit"
alias gp "git push"
alias gpl "git pull"
alias gd "git diff"
alias gl "git log --oneline --graph"

# File listing aliases
alias ll "ls -la"
alias la "ls -a"

# Export GITHUB_TOKEN for MCP github server
if type -q gh
    set -gx GITHUB_TOKEN (gh auth token 2>/dev/null)
end

# direnv hook
if type -q direnv
    direnv hook fish | source
end

# starship prompt
if type -q starship
    starship init fish | source
end
