#!/usr/bin/env sh
# 渲染紧凑的 Claude Code 状态栏。
# 配色取自 Catppuccin Mocha，与 tmux 状态栏保持同一套视觉语言。

set -eu

input=$(cat)

json() {
    printf '%s' "$input" | jq -r "$1"
}

model=$(json '.model.display_name')
cwd=$(json '.workspace.current_dir')
think=$(json '.effort.level // "-"')
context_tokens=$(json '(.context_window.current_usage.input_tokens // 0) + (.context_window.current_usage.output_tokens // 0) + (.context_window.current_usage.cache_creation_input_tokens // 0) + (.context_window.current_usage.cache_read_input_tokens // 0)')
context_percentage=$(json '.context_window.used_percentage // 0')
total_tokens=$(json '(.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)')
added=$(json '.cost.total_lines_added // 0')
removed=$(json '.cost.total_lines_removed // 0')

# ---------------------------------------------------------------------------
# 配色 —— Catppuccin Mocha 24bit 真实色（与 tmux 状态栏同一组取值）
#   不用 ANSI-16，避免落到终端那套偏灰的柔和色上。
# ---------------------------------------------------------------------------
if [ -n "${NO_COLOR:-}" ]; then
    blue='' mauve='' teal='' green='' yellow='' red='' surface='' overlay='' reset=''
else
    escape=$(printf '\033')
    blue="${escape}[38;2;137;180;250m"    # #89b4fa 模型
    mauve="${escape}[38;2;203;166;247m"   # #cba6f7 思考等级 / 分支
    teal="${escape}[38;2;148;226;213m"    # #94e2d5 目录
    green="${escape}[38;2;166;227;161m"   # #a6e3a1 安全 / 新增
    yellow="${escape}[38;2;249;226;175m"  # #f9e2af 告警
    red="${escape}[38;2;243;139;168m"     # #f38ba8 危险 / 删除
    surface="${escape}[38;2;69;71;90m"    # #45475a 分隔符
    overlay="${escape}[38;2;108;112;134m" # #6c7086 次要信息
    reset="${escape}[0m"
fi

# 段间分隔 —— 与 tmux 状态栏同款细竖线，替掉 ASCII | 的锯齿感。
sep() {
    printf ' %s│%s ' "$surface" "$reset"
}

branch=-
if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null \
        || git -C "$cwd" rev-parse --short HEAD 2>/dev/null \
        || printf '%s' '-')
fi

case "$cwd" in
    */) directory=${cwd%/}; directory=${directory##*/} ;;
    *) directory=${cwd##*/} ;;
esac
[ -n "$directory" ] || directory=/

# 将 token 数格式化为易读的 k 或 M 单位。
format_tokens() {
    awk -v value="$1" 'BEGIN {
        if (value >= 1000000) printf "%.1fM", value / 1000000
        else if (value >= 1000) printf "%.1fk", value / 1000
        else printf "%d", value
    }'
}

total_tokens=$(printf '%.0f' "$total_tokens" 2>/dev/null) || total_tokens=0
context_tokens=$(printf '%.0f' "$context_tokens" 2>/dev/null) || context_tokens=0
context_percentage=$(printf '%.1f' "$context_percentage" 2>/dev/null) || context_percentage=0
context_percentage_int=$(printf '%.0f' "$context_percentage" 2>/dev/null) || context_percentage_int=0

if [ "$context_percentage_int" -ge 90 ]; then
    context_color=$red
elif [ "$context_percentage_int" -ge 70 ]; then
    context_color=$yellow
else
    context_color=$green
fi

# 上下文占用条 —— 10 格，非零时至少点亮 1 格，避免「明明用了却全空」。
filled=$(awk -v p="$context_percentage" 'BEGIN {
    if (p < 0) p = 0
    if (p > 100) p = 100
    n = int(p / 10 + 0.5)
    if (p > 0 && n < 1) n = 1
    if (n > 10) n = 10
    printf "%d", n
}')

bar=''
i=1
while [ "$i" -le 10 ]; do
    if [ "$i" -le "$filled" ]; then
        bar="${bar}█"
    else
        bar="${bar}░"
    fi
    i=$((i + 1))
done

context=$(format_tokens "$context_tokens")
total=$(format_tokens "$total_tokens")

# ---------------------------------------------------------------------------
# 输出
# ---------------------------------------------------------------------------
printf '%s%s%s %s%s%s' "$blue" "$model" "$reset" "$mauve" "$think" "$reset"
sep
printf '%s%s %s%s%%%s %s· %s%s' "$context_color" "$bar" "$context_color" "$context_percentage_int" "$reset" "$overlay" "$context" "$reset"
sep
printf '%s󰉋 %s%s' "$teal" "$directory" "$reset"
sep
printf '%s󰘬 %s%s' "$mauve" "$branch" "$reset"
sep
printf '%s+%s%s %s−%s%s' "$green" "$added" "$reset" "$red" "$removed" "$reset"
sep
printf '%sΣ %s%s\n' "$overlay" "$total" "$reset"
