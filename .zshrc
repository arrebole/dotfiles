# 增加用户 PATH 环境变量
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

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
zinit ice lucid wait='1'
zinit snippet OMZP::git

# mvn 
zinit ice wait blockf
zinit snippet OMZP::nvm

# 主题
zinit ice pick"async.zsh" src"pure.zsh"
zinit light sindresorhus/pure
