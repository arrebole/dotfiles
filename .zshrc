# 增加用户 PATH 环境变量
export PATH=$HOME/.local/share/npm/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# zsh 历史记录配置
HISTSIZE=1000000
SAVEHIST=1000000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_FIND_NO_DUPS


# 加载 zsh 包管理
source /home/dev/.local/share/zinit/zinit.git/zinit.zsh

# 灰色建议
zinit ice lucid wait="0" atload='_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

# 补全增强
zinit ice lucid wait='0'
zinit light zsh-users/zsh-completions

# 高亮
zinit ice lucid wait='0' atinit='zpcompinit'
zinit light zsh-users/zsh-syntax-highlighting

# shell 信息前缀
zinit ice pick"async.zsh" src"pure.zsh"
zinit light sindresorhus/pure

# alias
# ls 输出默认使用颜色
alias ls='ls --color=tty'
alias ll='ls -la --color=tty'
