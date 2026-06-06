#!/usr/bin/env bash
# 性能指标采集器 - 稳健版

DATA_DIR="./data"
mkdir -p "$DATA_DIR"

log_collect() {
    echo "[$(date +'%H:%M:%S')] $1"
}

# 确保数值返回，若计算失败强制返回 0
normalize() {
    local val=${1:-0}
    # 去除可能的百分号或非数字字符，若为空则返回 0
    local clean_val=$(echo "$val" | tr -d '%' | tr -d '[:space:]')
    if [[ -z "$clean_val" || ! "$clean_val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "0"
    else
        echo "$clean_val"
    fi
}

# 【1】 采集 CPU
log_collect "采集 CPU 利用率..."
# 提取 cpu(s) 的 id(空闲) 列，用 100 减去它
CPU_RAW=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
CPU_VAL=$(normalize "$CPU_RAW")
echo "$CPU_VAL" > "$DATA_DIR/cpu.tmp"
log_collect "CPU 利用率: ${CPU_VAL}%"

# 【2】 采集内存 (直接读取总数和已用数，避免单位换算麻烦)
log_collect "采集内存利用率..."
# 使用 -m 参数，以 MB 为单位，避免 Gi/Mi 转换错误
MEM_VAL=$(free -m | awk '/^Mem:/ {printf "%.1f", ($3/$2)*100}')
MEM_VAL=$(normalize "$MEM_VAL")
echo "$MEM_VAL" > "$DATA_DIR/mem.tmp"
log_collect "内存: ${MEM_VAL}%"

# 【3】 采集磁盘
log_collect "采集磁盘占用率..."
DISK_RAW=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
DISK_VAL=$(normalize "$DISK_RAW")
echo "$DISK_VAL" > "$DATA_DIR/disk.tmp"
log_collect "磁盘: ${DISK_VAL}%"

# 【4】 采集系统负载
log_collect "采集系统负载..."
LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1" "$2" "$3}' || echo "0 0 0")
echo "$LOAD" > "$DATA_DIR/load.tmp"
log_collect "系统负载: $LOAD"

# 【5】 采集进程数
log_collect "采集运行进程数..."
PROC_COUNT=$(ps aux | wc -l)
echo "$PROC_COUNT" > "$DATA_DIR/proc_count.tmp"
log_collect "进程数: $PROC_COUNT"

sync
log_collect "✓ 采集周期完成，所有数据已持久化"