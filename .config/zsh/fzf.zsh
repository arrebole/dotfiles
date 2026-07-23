# strip-cwd-prefix removes the leading ./ from results
# fzf 命令包含隐藏文件
# Ctrl-T 排除隐藏文件
export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix'  
export FZF_CTRL_T_COMMAND='fd --type f --no-hidden --strip-cwd-prefix'

# UI央视
export FZF_DEFAULT_OPTS='
  --height=60%
  --layout=reverse
  --border=rounded
  --prompt="  "
  --pointer="  "
  --preview-window=right:65%:wrap:border-left'

# 预览
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=plain,numbers --line-range=:500 {}'"
