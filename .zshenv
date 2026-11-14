# 增加用户 PATH 环境变量
export PATH=$HOME/.local/share/npm/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# 指定程序配置文件目录
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/.npmrc"

# 如果需要在 wsl 中使用 PLAYWRIGHT-CLI 控制浏览器 需要打开以下变量
# 然后使用 cli 命令连接浏览器 `playwright-cli -s=win-chrome-ipv4 attach --extension=chrome`
# export NODE_OPTIONS=--dns-result-order=ipv4first
# export PLAYWRIGHT_MCP_EXECUTABLE_PATH='/mnt/c/Program Files/Google/Chrome/Application/chrome.exe'
# export PLAYWRIGHT_MCP_PROFILE_DIR_NAME=Default
# export PLAYWRIGHT_MCP_EXTENSION_TOKEN='你的扩展令牌'
