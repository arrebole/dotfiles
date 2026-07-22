
# dotfiles config


### set /etc/zshenv
```bash
if [[ -z "$XDG_CONFIG_HOME" ]]
then
    export XDG_CONFIG_HOME="$HOME/.config"
fi

if [[ -d "$XDG_CONFIG_HOME/zsh" ]]
then
    export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
fi
```

### System Components
+ [sway](https://github.com/swaywm/sway)
+ [waybar](https://github.com/Alexays/Waybar)
+ [alacritty](https://github.com/alacritty/alacritty)
+ [wofi](https://hg.sr.ht/~scoopta/wofi)
+ [podman](https://github.com/podman-container-tools/podman)
+ [nvim](https://github.com/neovim/neovim)
+ [tmux](https://github.com/tmux/tmux)
+ [fzf](https://github.com/junegunn/fzf)
+ [eza](https://github.com/eza-community/eza)
+ [atuin](https://github.com/atuinsh/atuin)

#### AI Codeing
+ [vscode](https://github.com/microsoft/vscode)
+ [claudecode](https://github.com/anthropics/claude-code)
+ [codex](https://github.com/openai/codex)
+ [pi-agent](https://github.com/earendil-works/pi)
+ [codegraph](https://github.com/colbymchenry/codegraph)
+ [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp)
+ [cc-switch](https://github.com/farion1231/cc-switch)
