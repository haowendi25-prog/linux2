#!/usr/bin/env bash
set -euo pipefail
# ============================================================================
# 磁盘清理与自愈模块 - 智能清理垃圾文件释放空间
# 特性：多策略清理、进度报告、事务日志
# ============================================================================

# 常量定义
DATA_DIR="./data"
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/activity.log"

# 确保必要的目录存在
mkdir -p "$DATA_DIR" "$LOG_DIR"

# 日志函数
log_cleanup() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [CLEANUP] $1" | tee -a "$LOG_FILE"
}

log_summary() {
    echo "$1"
}

# 【初始化】
log_cleanup "启动磁盘深度清理程序..."
echo ""

# 【获取清理前状态】
log_summary "════════════════════════════════════════"
log_summary "📊 清理前系统状态分析"
log_summary "════════════════════════════════════════"

BEFORE_USED=$(df -h / 2>/dev/null | tail -1 | awk '{print $3}' || echo "Unknown")
BEFORE_AVAIL=$(df -h / 2>/dev/null | tail -1 | awk '{print $4}' || echo "Unknown")
BEFORE_PERCENT=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0")

log_summary "  已用空间: $BEFORE_USED"
log_summary "  可用空间: $BEFORE_AVAIL"
log_summary "  占用比例: ${BEFORE_PERCENT}%"
echo ""

# 【清理步骤1】- 清理系统临时目录
log_cleanup "步骤1: 清理系统临时文件 (/tmp)"
if rm -rf /tmp/* 2>/dev/null; then
    log_cleanup "  ✓ /tmp 临时缓存已清理"
else
    log_cleanup "  ⚠ /tmp 清理遇到权限问题（非致命）"
fi

# 【清理步骤2】- 清理用户缓存
log_cleanup "步骤2: 清理用户缓存文件 (~/.cache)"
if [ -d "$HOME/.cache" ]; then
    if rm -rf "$HOME/.cache"/* 2>/dev/null; then
        log_cleanup "  ✓ 用户缓存已清理"
    else
        log_cleanup "  ⚠ 用户缓存清理部分成功"
    fi
fi

# 【清理步骤3】- 清理测试文件
log_cleanup "步骤3: 清理遗留的测试文件"
if [ -f "$HOME/big_test_file.img" ]; then
    SIZE=$(du -h "$HOME/big_test_file.img" 2>/dev/null | awk '{print $1}' || echo "Unknown")
    if rm -f "$HOME/big_test_file.img" 2>/dev/null; then
        log_cleanup "  ✓ 删除测试镜像文件 (释放 $SIZE 空间)"
    fi
fi

# 【清理步骤4】- 清理 journalctl 旧日志
log_cleanup "步骤4: 清理 systemd journal 旧日志"
if command -v journalctl &>/dev/null; then
    if journalctl --vacuum=10d 2>/dev/null; then
        log_cleanup "  ✓ 保留最近 10 天的 journal 日志"
    else
        log_cleanup "  ⚠ journal 清理需要 root 权限（跳过）"
    fi
fi

# 【清理步骤5】- 清理包管理器缓存
log_cleanup "步骤5: 清理包管理器缓存"
if command -v apt-get &>/dev/null; then
    if apt-get clean 2>/dev/null; then
        log_cleanup "  ✓ APT 包缓存已清理"
    else
        log_cleanup "  ⚠ APT 清理需要权限（跳过）"
    fi
fi

if command -v yum &>/dev/null; then
    if yum clean all 2>/dev/null; then
        log_cleanup "  ✓ YUM 包缓存已清理"
    else
        log_cleanup "  ⚠ YUM 清理需要权限（跳过）"
    fi
fi

# 【清理步骤6】- 清理监控临时数据（保留配置文件）
log_cleanup "步骤6: 清理监控采集缓存"
if rm -f "$DATA_DIR"/*.tmp 2>/dev/null; then
    log_cleanup "  ✓ 临时采集数据已清理"
fi

# 【获取清理后状态】
echo ""
log_summary "════════════════════════════════════════"
log_summary "✓ 清理完成 - 系统状态对比"
log_summary "════════════════════════════════════════"

AFTER_USED=$(df -h / 2>/dev/null | tail -1 | awk '{print $3}' || echo "Unknown")
AFTER_AVAIL=$(df -h / 2>/dev/null | tail -1 | awk '{print $4}' || echo "Unknown")
AFTER_PERCENT=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0")

log_summary "  已用空间: $AFTER_USED (之前: $BEFORE_USED)"
log_summary "  可用空间: $AFTER_AVAIL (之前: $BEFORE_AVAIL)"
log_summary "  占用比例: ${AFTER_PERCENT}% (之前: ${BEFORE_PERCENT}%)"

# 【计算优化效果】
if [[ "$BEFORE_PERCENT" != "0" ]] && [[ "$AFTER_PERCENT" != "0" ]]; then
    IMPROVEMENT=$((BEFORE_PERCENT - AFTER_PERCENT))
    if [ "$IMPROVEMENT" -gt 0 ]; then
        log_summary "  📊 优化效果: 磁盘占用率降低 ${IMPROVEMENT}% 🎉"
    else
        log_summary "  📊 系统已处于最优状态（或无可清理内容）"
    fi
fi

echo ""
log_cleanup "清理任务已完成"
