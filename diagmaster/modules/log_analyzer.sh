#!/usr/bin/env bash
set -euo pipefail
# ============================================================================
# 日志分析与特征提取模块 - 深度检索内核/安全日志
# 特性：权限预检查、多源回退策略、异常处理
# ============================================================================

DATA_DIR="./data"
mkdir -p "$DATA_DIR"

# 日志函数
log_analyze() {
    echo "[$(date +'%H:%M:%S')] $1"
}

# 【1】 OOM-Killer 事件计数（内存溢出）
log_analyze "分析 OOM-Killer 事件..."
OOM_COUNT=0

if [ -r /var/log/kern.log ] 2>/dev/null; then
    OOM_COUNT=$(grep -c -i "Out of memory\|OOM\|kill process" /var/log/kern.log 2>/dev/null || echo "0")
    log_analyze "从 /var/log/kern.log 检测到 $OOM_COUNT 次 OOM 事件"
elif command -v dmesg &>/dev/null; then
    OOM_COUNT=$(dmesg 2>/dev/null | grep -c -i "Out of memory\|OOM" || echo "0")
    log_analyze "从 dmesg 缓冲区检测到 $OOM_COUNT 次 OOM 事件"
else
    log_analyze "⚠ 无法读取 OOM 数据（权限不足或日志不存在）"
    OOM_COUNT=0
fi

echo "$OOM_COUNT" > "$DATA_DIR/oom_count.tmp"

# 【2】 SSH 暴力破解检测
log_analyze "分析 SSH 登录失败尝试..."
SSH_FAIL_COUNT=0

if [ -r /var/log/auth.log ] 2>/dev/null; then
    # 统计失败的密码认证（SSH 暴力破解典型特征）
    SSH_FAIL_COUNT=$(grep -c "Failed password\|Invalid user" /var/log/auth.log 2>/dev/null || echo "0")
    log_analyze "从 /var/log/auth.log 检测到 $SSH_FAIL_COUNT 次 SSH 失败尝试"
elif [ -r /var/log/secure ] 2>/dev/null; then
    # RedHat/CentOS 系统使用 /var/log/secure
    SSH_FAIL_COUNT=$(grep -c "Failed password\|Invalid user" /var/log/secure 2>/dev/null || echo "0")
    log_analyze "从 /var/log/secure 检测到 $SSH_FAIL_COUNT 次 SSH 失败尝试"
else
    log_analyze "⚠ 无法读取 SSH 日志（权限不足或日志不存在）"
    SSH_FAIL_COUNT=0
fi

echo "$SSH_FAIL_COUNT" > "$DATA_DIR/ssh_fail.tmp"

# 【3】 系统错误日志统计
log_analyze "扫描系统错误日志..."
SYSTEM_ERRORS=0

if [ -r /var/log/syslog ] 2>/dev/null; then
    SYSTEM_ERRORS=$(grep -c -i "error\|critical\|fatal" /var/log/syslog 2>/dev/null | head -c 10 || echo "0")
elif [ -r /var/log/messages ] 2>/dev/null; then
    SYSTEM_ERRORS=$(grep -c -i "error\|critical\|fatal" /var/log/messages 2>/dev/null | head -c 10 || echo "0")
fi

echo "$SYSTEM_ERRORS" > "$DATA_DIR/system_errors.tmp"
log_analyze "检测到 $SYSTEM_ERRORS 条系统错误"

# 【4】 最终状态同步 - 确保所有临时文件存在且非空
log_analyze "执行最终数据同步..."
for tmpfile in oom_count.tmp ssh_fail.tmp system_errors.tmp; do
    if [ ! -f "$DATA_DIR/$tmpfile" ] || [ ! -s "$DATA_DIR/$tmpfile" ]; then
        echo "0" > "$DATA_DIR/$tmpfile"
    fi
done

log_analyze "✓ 日志分析完成，所有指标已输出"
