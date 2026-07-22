# zsh 历史记录配置
HISTSIZE=1000000
SAVEHIST=1000000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS

setopt AUTOCD
setopt NOBEEP
setopt NUMERIC_GLOB_SORT

source $HOME/.config/alias.zsh
source $HOME/.config/plugins.zsh
