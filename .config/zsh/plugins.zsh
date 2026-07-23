# 加载 zsh 包管理
declare -A ZINIT
source $HOME/.local/share/zinit/zinit.git/zinit.zsh

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# 灰色建议
zinit ice lucid wait="0" atload='_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

# 下载补全插件- 提供补全规则数据
zinit ice lucid wait='0'
zinit light zsh-users/zsh-completions

# 高亮
zinit ice lucid wait='0'
zinit light zdharma-continuum/fast-syntax-highlighting

# shell 信息前缀
zinit ice pick"async.zsh" src"pure.zsh"
zinit light sindresorhus/pure

# 加载补全数据
ZINIT[ZCOMPDUMP_PATH]="$HOME/.cache/zsh/zcompdump"
autoload -Uz compinit
zicompinit