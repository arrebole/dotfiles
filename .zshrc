################ 环境变量 ####################

# 增加用户 PATH 环境变量
export $HOME/.local/bin:/usr/local/bin:$PATH
# ls 颜色环境变量
export LS_COLORS="$(vivid generate molokai)"

############ zsh 配置 ###########################

# 内存中保存的命令条数（设为较大值，如 100000）
HISTSIZE=100000

# 历史文件中实际保存的条数（必须 >= HISTSIZE，这里设为相同值）
SAVEHIST=100000

# 实时写入：每执行一条命令，立刻追加到 HISTFILE，而不是等退出时才写入
setopt INC_APPEND_HISTORY

# 跨会话共享：允许正在运行的会话读取其他会话新写入的历史
setopt SHARE_HISTORY

# 去除连续重复的命令，保持历史精简
setopt HIST_IGNORE_DUPS

############# zsh 插件配置 ################

# 加载 zsh 包管理
source /home/developer/.local/share/zinit/zinit.git/zinit.zsh

# 灰色建议
zinit ice lucid wait="0" atload='_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

# 补全增强
zinit ice lucid wait='0'
zinit light zsh-users/zsh-completions

# 高亮
zinit ice lucid wait='0' atinit='zpcompinit'
zinit light zsh-users/zsh-syntax-highlighting

# git 插件
zinit ice wait'0' lucid
zinit snippet OMZP::git

# 加载异步库 (Pure主题实现非阻塞提示符所必需的依赖)
zinit ice wait"0a" lucid
zinit light mafredri/zsh-async

# 安装并加载 Pure 主题
zinit ice pick"async.zsh" src"pure.zsh"
zinit light sindresorhus/pure

############ alias ###################

# ls 输出默认使用颜色
alias ls='ls --color=tty'
alias ll='ls -la --color=tty'
