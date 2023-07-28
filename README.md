## my linux dotfiles

### Components
+ [sway](https://github.com/swaywm/sway)
+ [waybar](https://github.com/Alexays/Waybar)
+ [alacritty](https://github.com/alacritty/alacritty)
+ [wofi](https://hg.sr.ht/~scoopta/wofi)
+ [nvim](https://github.com/neovim/neovim)

### auto start sway
```bash
# export WLR_RENDERER=vulkan
[ $(tty) = "/dev/tty1" ] && exec sway
```

### 输入法
```bash
export GTK_IM_MODULE="fcitx"
export QT_IM_MODULE="fcitx"
export XMODIFIERS="@im=fcitx"
export INPUT_METHOD="fcitx"
export XIM="fcitx"
export XIM_PROGRAM="fcitx"
export SDL_IM_MODULE="fcitx"
export GLFW_IM_MODULE="ibus"
```

### 终端选词
```bash
# 将 alacritty 切换到 x11
env WINIT_UNIX_BACKEND=x11 alacritty
```

