export ZSH="/root/.oh-my-zsh"

ZSH_THEME="pygmalion"

plugins=(
    git
)

DISABLE_AUTO_TITLE="true"
zstyle ':omz:update' mode disabled

source "$ZSH/oh-my-zsh.sh"

[[ -r /root/.techrelay-zsh ]] &&
    source /root/.techrelay-zsh
