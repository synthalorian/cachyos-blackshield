# aliases.fish — synth-aligned shortcuts

# git
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit -v'
alias gp='git push'
alias gl='git log --oneline --graph --decorate -20'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch -a'
alias gpl='git pull --rebase'
alias gst='git stash -u'
alias gsta='git stash apply'
alias glg='git log --stat --oneline --decorate'

# navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias desk='cd ~/Desktop'
alias proj='cd ~/Projects'
alias opena='cd ~/Projects/active'
alias arch='cd ~/Projects/archived'

# CachyOS / Arch
alias up='sudo pacman -Syu'
alias pac='sudo pacman'
alias par='paru'
alias paci='sudo pacman -S'
alias pacr='sudo pacman -Rns'
alias pqs='pacman -Qs'
alias pqi='pacman -Qi'
alias orphans='pacman -Qdtq'
alias clean-orphans='sudo pacman -Rns (pacman -Qdtq)'
alias mirrors='cachyos-rate-mirrors'
alias paci='sudo pacman -S --needed'

# media / obsessed
alias vloud='pavucontrol'
alias sonics='cd ~/Projects/active/this-is-the-wave && this-is-the-wave'

# Flutter / mobile
alias fclear='flutter clean && rm -rf build && rm -rf ios/Pods && rm -rf android/.gradle'
alias frun='flutter run --enable-impeller'
alias fbuild='flutter build apk --debug'

# files / safety
alias ll='ls -alF --color=auto'
alias la='ls -A'
alias lt='ls -lt'
alias mk='mkdir -p'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias rmf='rm -rf'  # deliberate force

# monitoring
alias now='date "+%Y-%m-%d %H:%M:%S %Z"'
alias mem='free -h'
alias diskinfo='df -hT'
alias ports='ss -tlnp'
alias myip='curl -s ifconfig.me'
alias weather='curl -s wttr.in'

# devtools
alias n='nvim'
alias nt='nvim -c "set ft=text"'
alias grep='grep --color=auto'
alias rg='rg --smart-case'
alias ka='kwriteconfig6'
alias krc='kwriteconfig6 --file ~/.config/kwinrc'
