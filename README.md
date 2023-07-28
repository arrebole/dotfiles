## my linux dotfiles

### Components
+ [sway](https://github.com/swaywm/sway)
+ [waybar](https://github.com/Alexays/Waybar)
+ [alacritty](https://github.com/alacritty/alacritty)
+ [wofi](https://hg.sr.ht/~scoopta/wofi)
+ [nvim](https://github.com/neovim/neovim)

### auto start sway
```bash
export WLR_RENDERER=vulkan
[ $(tty) = "/dev/tty1" ] && exec sway
```
