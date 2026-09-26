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
transcript=$(json '.transcript_path // ""')
# 上下文体积 = 下一轮要重读的那些 token（新输入 + 两个 cache 半区）。
# 不算 output_tokens：它不进下一轮的上下文，算上会让这个数字跟 used_percentage
# 对不上（百分比只按这三项算），而且响应边流边涨，同一份上下文会来回跳。
context_tokens=$(json '(.context_window.current_usage.input_tokens // 0) + (.context_window.current_usage.cache_creation_input_tokens // 0) + (.context_window.current_usage.cache_read_input_tokens // 0)')
context_percentage=$(json '.context_window.used_percentage // 0')
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

# 会话累计 token 消耗 —— statusline 自己没给这个数，得从 transcript 累加：
#   · context_window.total_* 是「当前上下文」而不是会话累计（见上面那段注释）；
#   · transcript 里的 cost-state 行只在会话收尾/恢复时才写，实时会话里一条都没有
#     （实测：跑着的会话 0 条，收尾过的会话 16 条），所以它不能当实时数据源。
#
# 代价控制：一整场会话的 transcript 能到几十 MB，每次渲染全量扫一遍是 O(文件大小)
#   —— 实测 1MB 时 75ms/次，30MB 就是几百 ms。这里改成按字节 offset 增量读，
#   状态（offset + 累计值 + 上一行的 message.id）落在 TMPDIR，每次只处理新增的
#   那几 KB。状态丢了/文件被截断都只是重扫一次，不影响正确性。
#
# 去重：同一次 API 响应在 transcript 里会被写成连续 2~3 行（内容完全相同，实测
#   77 组重复全部连续且逐字相同），所以「和上一行同 message.id 就跳过」就能精确
#   去重，不必维护 id 集合。非连续重复不存在。
#
# 范围：主 transcript + <session-id>/subagents/agent-*.jsonl。subagent 烧的 token
#   也是这个会话烧的，一并计入；主 transcript 里若出现 isSidechain 行则跳过
#   （CLI 将来改成内联时不会和独立文件重复计数，这也是 ccstatusline PR#441 的守卫）。
#   注意 subagent 的 transcript 只记 input/cache，output 恒为 0（CLI 现状），
#   所以它们的 output 会少算一点点。
scan_transcript() {
    scan_file=$1
    scan_side=$2                  # 1 = 连 isSidechain 行一起算（subagent 自己那份）
    [ -r "$scan_file" ] || return 0
    scan_size=$(wc -c < "$scan_file" 2>/dev/null) || return 0
    scan_state="$state_dir/${scan_file##*/}.state"

    scan_off=0 scan_last= scan_i=0 scan_o=0 scan_c=0 scan_r=0
    if [ -r "$scan_state" ]; then
        read -r scan_off scan_last scan_i scan_o scan_c scan_r < "$scan_state" 2>/dev/null || true
    fi
    case "${scan_off}${scan_i}${scan_o}${scan_c}${scan_r}" in
        '' | *[!0-9]*) scan_off=0 scan_last= scan_i=0 scan_o=0 scan_c=0 scan_r=0 ;;
    esac
    if [ "${scan_size:-0}" -lt "${scan_off:-0}" ]; then   # 文件被截断/换掉 → 重头扫
        scan_off=0 scan_last= scan_i=0 scan_o=0 scan_c=0 scan_r=0
    fi

    if [ "$scan_size" -gt "${scan_off:-0}" ]; then
        scan_new=$(tail -c "+$(( ${scan_off:-0} + 1 ))" "$scan_file" 2>/dev/null \
            | jq -n -r --arg last "${scan_last:-}" --arg side "$scan_side" '
                reduce inputs as $r ({last: $last, i: 0, o: 0, c: 0, r: 0};
                    if $r.message.usage == null then .
                    elif $side != "1" and $r.isSidechain == true then .
                    elif $r.isApiErrorMessage == true then .
                    elif ($r.message.id // "") == .last then .
                    else {last: ($r.message.id // ""),
                          i: (.i + ($r.message.usage.input_tokens // 0)),
                          o: (.o + ($r.message.usage.output_tokens // 0)),
                          c: (.c + ($r.message.usage.cache_creation_input_tokens // 0)),
                          r: (.r + ($r.message.usage.cache_read_input_tokens // 0))}
                    end)
                | "\(.last) \(.i) \(.o) \(.c) \(.r)"' 2>/dev/null)
        # 解析失败（比如文件正写到一半）就保持原状态，下一轮再试，宁可少算不跳号。
        if [ -n "$scan_new" ]; then
            read -r scan_last scan_di scan_do scan_dc scan_dr <<EOF
$scan_new
EOF
            scan_i=$(( ${scan_i:-0} + ${scan_di:-0} ))
            scan_o=$(( ${scan_o:-0} + ${scan_do:-0} ))
            scan_c=$(( ${scan_c:-0} + ${scan_dc:-0} ))
            scan_r=$(( ${scan_r:-0} + ${scan_dr:-0} ))
            scan_off=$scan_size
            printf '%s %s %s %s %s %s\n' "$scan_off" "$scan_last" \
                "$scan_i" "$scan_o" "$scan_c" "$scan_r" > "$scan_state.$$" 2>/dev/null \
                && mv "$scan_state.$$" "$scan_state" 2>/dev/null
        fi
    fi

    SESS_IN=$(( ${SESS_IN:-0} + scan_i ))
    SESS_OUT=$(( ${SESS_OUT:-0} + scan_o ))
    SESS_CC=$(( ${SESS_CC:-0} + scan_c ))
    SESS_CR=$(( ${SESS_CR:-0} + scan_r ))
}

session_total() {
    SESS_IN=0 SESS_OUT=0 SESS_CC=0 SESS_CR=0
    [ -n "$transcript" ] && [ -r "$transcript" ] || { printf '0'; return; }

    state_dir=${TMPDIR:-/tmp}
    scan_transcript "$transcript" 0

    sess_stem=${transcript##*/}
    sess_stem=${sess_stem%.jsonl}
    sess_dir=${transcript%/*}
    for sess_cand in "$sess_dir/subagents" "$sess_dir/$sess_stem/subagents"; do
        [ -d "$sess_cand" ] || continue
        for sess_f in "$sess_cand"/agent-*.jsonl; do
            [ -e "$sess_f" ] || continue
            scan_transcript "$sess_f" 1
        done
    done

    printf '%s' "$(( SESS_IN + SESS_OUT + SESS_CC + SESS_CR ))"
}

# 将 token 数格式化为易读的 k 或 M 单位。
format_tokens() {
    awk -v value="$1" 'BEGIN {
        if (value >= 1000000) printf "%.1fM", value / 1000000
        else if (value >= 1000) printf "%.1fk", value / 1000
        else printf "%d", value
    }'
}

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
total=$(format_tokens "$(session_total)")

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
