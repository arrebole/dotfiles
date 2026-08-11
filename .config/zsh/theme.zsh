# Linux 虚拟控制台通常没有 Nerd Font，提示符改用纯 ASCII 字符。
if [[ $TERM == linux || $TTY == /dev/tty[0-9]* ]]; then
  source $XDG_CONFIG_HOME/zsh/p10k_tty.zsh
else
  source $XDG_CONFIG_HOME/zsh/p10k_tml.zsh
fi