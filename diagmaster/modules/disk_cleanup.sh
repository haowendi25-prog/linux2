#!/usr/bin/env bash
# 智能化磁盘清理与自愈模块 - 联动重置版

# 确保能使用主脚本定义的 log_action (如果是在子shell中，可以直接写入)
log_to_file() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "./logs/activity.log"
}

echo -e "[INFO] 正在启动磁盘深度清理程序..."
log_to_file "启动磁盘清理任务"

# [核心改进]：检测并重置告警触发状态
if [ -f "./data/.force_alert" ]; then
    rm -f "./data/.force_alert"
    echo -e "${GREEN}[✓] 检测到系统处于告警状态，已同步解除触发锁。${NC}"
fi

# 1. 清理系统临时目录
rm -rf /tmp/* 2>/dev/null
echo -e "[✓] 已清理 /tmp 临时缓存目录"

# 2. 清理残留压测镜像
if [ -f "$HOME/big_test_file.img" ]; then
    rm -f "$HOME/big_test_file.img"
    echo -e "[✓] 检测到残留压测镜像，已强制释放磁盘空间"
fi

# 3. 清理监控临时数据缓存 (关键：清空后，采集器就不会读到旧的 95% 了)
rm -f ./data/*.tmp
echo -e "[✓] 已清理监控临时数据缓存"

# 4. 最终完成
echo -e "[DONE] 磁盘清理完成，系统已释放冗余存储空间。"
log_to_file "磁盘清理任务完成，告警锁已解除"
