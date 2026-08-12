#!/usr/bin/env sh
# Render a compact system summary for tmux status-right.

set -eu

state_dir="${XDG_RUNTIME_DIR:-/tmp}"
state_file="$state_dir/tmux-status-system-${UID:-$(id -u)}"
now=$(date +%s)

set -- $(awk '/^cpu / {
    total = 0
    for (i = 2; i <= NF; i++) total += $i
    idle = $5 + $6
    print total, total - idle
}' /proc/stat)
cpu_total=$1
cpu_busy=$2

set -- $(awk -F: 'NR > 2 {
    iface = $1
    gsub(/^[[:space:]]+/, "", iface)
    if (iface != "lo" && iface != "loopback0") {
        data = $2
        sub(/^[[:space:]]+/, "", data)
        split(data, fields, /[[:space:]]+/)
        rx += fields[1]
        tx += fields[9]
    }
}
END { print rx + 0, tx + 0 }' /proc/net/dev)
net_rx=$1
net_tx=$2

if [ -r "$state_file" ]; then
    read -r old_time old_total old_busy old_rx old_tx < "$state_file" || true
else
    old_time=0
    old_total=0
    old_busy=0
    old_rx=0
    old_tx=0
fi

printf '%s %s %s %s %s\n' "$now" "$cpu_total" "$cpu_busy" "$net_rx" "$net_tx" > "$state_file"

if [ "$old_time" -gt 0 ] && [ "$cpu_total" -gt "$old_total" ]; then
    cpu=$(( (cpu_busy - old_busy) * 100 / (cpu_total - old_total) ))
else
    cpu="--"
fi

if [ "$old_time" -gt 0 ] && [ "$now" -gt "$old_time" ]; then
    elapsed=$((now - old_time))
    rx_rate=$(( (net_rx - old_rx) / elapsed ))
    tx_rate=$(( (net_tx - old_tx) / elapsed ))
else
    rx_rate=0
    tx_rate=0
fi

set -- $(awk '/^MemTotal:/ { total = $2 } /^MemAvailable:/ { available = $2 }
END { print total - available, total }' /proc/meminfo)
mem_used=$1
mem_total=$2

mem=$(awk -v used="$mem_used" -v total="$mem_total" 'BEGIN {
    printf "%.1f/%.1fG", used / 1048576, total / 1048576
}')

rate() {
    awk -v value="$1" 'BEGIN {
        if (value < 1024) printf "%dB", value
        else if (value < 1048576) printf "%.1fK", value / 1024
        else printf "%.1fM", value / 1048576
    }'
}

# Nerd Font: CPU, memory, and compact network throughput glyphs.
printf '󰻠 %s%%  󰍛 %s  󰈀 ↓%s ↑%s/s' \
    "$cpu" "$mem" "$(rate "$rx_rate")" "$(rate "$tx_rate")"

