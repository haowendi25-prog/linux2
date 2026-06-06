#!/usr/bin/env bash
# 日志分析特征提取模块 - 工业级健壮版

# 1. 内存溢出事件提取 (增加权限预检查)
if [ -r /var/log/kern.log ] || command -v dmesg >/dev/null 2>&1; then
    # 优先查 kern.log，如果不行再退化到 dmesg
    if [ -r /var/log/kern.log ]; then
        grep -c -i "out of memory" /var/log/kern.log 2>/dev/null > ./data/oom_count.tmp || echo "0" > ./data/oom_count.tmp
    else
        dmesg 2>/dev/null | grep -c -i "out of memory" > ./data/oom_count.tmp || echo "0" > ./data/oom_count.tmp
    fi
else
    echo "0" > ./data/oom_count.tmp
fi

# 2. 安全日志审计 (增加 SSH 爆破检测逻辑)
if [ -f /var/log/auth.log ]; then
    # 统计 Failed password 的次数
    grep -c "Failed password" /var/log/auth.log 2>/dev/null > ./data/ssh_fail.tmp || echo "0" > ./data/ssh_fail.tmp
else
    # 如果没有 auth.log (WSL常态)，则返回 0
    echo "0" > ./data/ssh_fail.tmp
fi

# 3. 最终状态同步 (确保文件一定存在，防止后续读取报 unbound variable)
[ -f ./data/oom_count.tmp ] || echo "0" > ./data/oom_count.tmp
[ -f ./data/ssh_fail.tmp ] || echo "0" > ./data/ssh_fail.tmp
