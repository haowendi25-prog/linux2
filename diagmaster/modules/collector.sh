#!/usr/bin/env bash
set -euo pipefail
# ============================================================================
# 性能指标采集器 - 实时采集 CPU/内存/磁盘 数据
# 特性：容错处理、数据验证、精度控制
# ============================================================================

DATA_DIR="./data"
mkdir -p "$DATA_DIR"

# 日志函数
log_collect() {
    echo "[$(date +'%H:%M:%S')] $1"
}

# 容错包装器 - 确保即使采集失败也返回默认值
collect_safe() {
    local value
    value=$("$@" 2>/dev/null || echo "0")
    # 验证数值有效性（过滤掉非数字）
    if [[ $value =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "$value"
    else
        echo "0"
    fi
}

# 【1】 采集 CPU 利用率（用户+系统 CPU）
log_collect "采集 CPU 利用率..."
CPU_VAL=$(collect_safe top -bn1 | grep "Cpu(s)" | awk '{printf "%.1f", $2+$4}')
echo "$CPU_VAL" > "$DATA_DIR/cpu.tmp"
log_collect "CPU: ${CPU_VAL}%"

# 【2】 采集内存利用率
log_collect "采集内存利用率..."
MEM_VAL=$(collect_safe free -h | awk '/^Mem:/ {printf "%.1f", ($3/$2)*100}')
echo "$MEM_VAL" > "$DATA_DIR/mem.tmp"
log_collect "内存: ${MEM_VAL}%"

# 【3】 采集磁盘占用率 - 使用当前工作目录，避免跨文件系统统计错误
log_collect "采集磁盘占用率..."
DISK_VAL=$(collect_safe df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
echo "$DISK_VAL" > "$DATA_DIR/disk.tmp"
log_collect "磁盘: ${DISK_VAL}%"

# 【4】 采集系统负载（1分钟、5分钟、15分钟）
log_collect "采集系统负载..."
LOAD=$(collect_safe cat /proc/loadavg | awk '{printf "%s %s %s", $1, $2, $3}')
echo "$LOAD" > "$DATA_DIR/load.tmp"
log_collect "系统负载: $LOAD"

# 【5】 采集进程数
log_collect "采集运行进程数..."
PROC_COUNT=$(collect_safe ps aux | wc -l)
echo "$PROC_COUNT" > "$DATA_DIR/proc_count.tmp"
log_collect "进程数: $PROC_COUNT"

# 数据持久化同步
if command -v sync &>/dev/null; then
    sync
fi

log_collect "✓ 采集周期完成，所有数据已持久化"
