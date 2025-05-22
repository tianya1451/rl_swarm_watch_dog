#!/bin/bash

# 设置日志文件
LOG_FILE="/Users/lin/workspace/rl-swarm/monitor.log"
WORKSPACE="/Users/lin/workspace/rl-swarm"
cd "$WORKSPACE"
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
python3 -m venv .venv
source .venv/bin/activate
unset HTTP_PROXY
unset HTTPS_PROXY
unset ALL_PROXY

# 复制用户API密钥和数据到工作目录
cp -f /Users/lin/Desktop/userApiKey.json /Users/lin/workspace/rl-swarm/modal-login/temp-data/userApiKey.json
cp -f /Users/lin/Desktop/userData.json /Users/lin/workspace/rl-swarm/modal-login/temp-data/userData.json

# 清除程序日志的函数
clear_program_logs() {
    log "清空主程序日志文件"
    : > "$WORKSPACE/rl_swarm_output.log"
}

# 记录日志的函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 显示最新的3条日志
show_recent_logs() {
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    local log_message="[$current_time] 最新3条程序日志："
    echo "$log_message" | tee -a "$LOG_FILE"
    local recent_logs=$(tail -n 3 "$WORKSPACE/rl_swarm_output.log" 2>/dev/null || echo "暂无日志")
    echo "$recent_logs" | tee -a "$LOG_FILE"
    local end_message="[$current_time] ------------------------"
    echo "$end_message" | tee -a "$LOG_FILE"
}

# 检查网络连接
check_network() {
    if curl -s --connect-timeout 5 https://www.google.com > /dev/null; then
        log "网络连接正常"
        return 0
    else
        log "网络连接失败"
        return 1
    fi
}

# 检查进程是否在运行
check_processes() {

    # 检查日志最后一行是否包含进度条信息，如果有，表示程序正常运行
    if tail -n 1 "$WORKSPACE/rl_swarm_output.log" 2>/dev/null | grep -E -q "^(\d+)%\|(█+)\|\s*(\d+)/(\d+)\s\[(\d{2}:\d{2})<(\d{2}:\d{2}),\s*([\d.]+s/it)\]$"; then
        log "检测到进度条信息，程序运行正常"
        return 0
    fi
    
    # 检查hivemind进程
    if pgrep -f "hivemind" > /dev/null; then
        return 0
    else
        log "Hivemind进程未运行"
        return 1
    fi
}

# 停止进程
stop_processes() {
    log "正在停止进程..."
    
    # 停止next进程
    pkill -f "next dev" || true
    
    # 停止hivemind进程
    pkill -f "hivemind" || true
    
    # 确保所有相关进程都已终止
    sleep 5
    
    if pgrep -f "next dev" > /dev/null || pgrep -f "hivemind" > /dev/null; then
        log "某些进程未能正常终止，尝试强制终止"
        pkill -9 -f "next dev" || true
        pkill -9 -f "hivemind" || true
        sleep 2
    fi
    
    log "所有进程已停止"
}

# 启动程序
start_program() {
    log "正在启动RL-Swarm程序..."
    cd "$WORKSPACE"
    
    # 清空主程序日志文件
    clear_program_logs
    
    # 通过echo和管道提供输入参数（全部使用默认值）
    # 分别是: Y(连接测试网), A(数学swarm), 0.5(参数数量), N(不推送到HF)
    log "自动提供输入参数..."
    nohup bash -c "echo -e '\n\n\n\n' | bash run_rl_swarm.sh" > "$WORKSPACE/rl_swarm_output.log" 2>&1 &
    
    # 等待进程启动
    sleep 150
    
    # 检查进程是否成功启动
    if check_processes; then
        log "RL-Swarm程序已成功启动"
        return 0
    else
        log "RL-Swarm程序启动失败"
        return 1
    fi
}

# 重启程序
restart_program() {
    log "准备重启程序..."
    
    # 检查网络连接
    if ! check_network; then
        log "网络连接失败，等待下一次检查"
        return 1
    fi
    
    # 停止现有进程
    stop_processes
    
    # 启动程序
    start_program
    
    log "重启完成"
}

# 检查特定错误
check_for_errors() {
    # 检查日志文件中是否有P2PDaemonError错误
    if grep -q "hivemind.p2p.p2p_daemon_bindings.utils.P2PDaemonError" "$WORKSPACE/rl_swarm_output.log" 2>/dev/null; then
        log "检测到P2PDaemonError错误，需要立即重启"
        return 1
    fi
    
    # 默认情况下，继续进行其他检查
    return 0
}

# 主循环
log "守护程序已启动，开始监控RL-Swarm进程"

# 在程序开始时清除日志
clear_program_logs

# 启动后台任务实时监控日志文件中的错误
(
    # 持续检查错误
    while true; do
        # 检查特定错误
        if grep -q "hivemind.p2p.p2p_daemon_bindings.utils.P2PDaemonError" "$WORKSPACE/rl_swarm_output.log" 2>/dev/null; then
            log "后台监控检测到P2PDaemonError错误，触发立即重启"
            # 清空程序日志文件，防止重复检测到错误
            clear_program_logs
            # 触发重启
            kill -USR1 $$
            # 等待主进程处理信号
            sleep 10
        fi
        sleep 5  # 每5秒检查一次错误
    done
) &

MONITORING_PID=$!

# 启动后台任务定期打印最新日志
(
    # 持续打印最新日志
    while true; do
        show_recent_logs
        sleep 15  # 每15秒打印一次
    done
) &

LOGS_DISPLAY_PID=$!

# 处理USR1信号，用于触发重启
restart_on_signal() {
    log "收到重启信号"
    # 确保程序日志文件已被清空
    clear_program_logs
    restart_program
}

# 设置信号处理
trap restart_on_signal USR1

# 确保在脚本退出时清理后台监控进程
cleanup_monitoring() {
    log "清理监控进程"
    kill $MONITORING_PID 2>/dev/null || true
    kill $LOGS_DISPLAY_PID 2>/dev/null || true
    exit 0
}

trap cleanup_monitoring EXIT


# 主检查循环
while true; do

    # 检查进程是否正在运行
    if ! check_processes; then
        log "检测到进程异常，准备重启"
        restart_program
    else
        # 即使进程正在运行，也检查日志中是否有错误
        if ! check_for_errors; then
            log "进程运行中，但检测到错误，准备重启"
            restart_program
        else
            log "进程运行正常"
        fi
    fi
    
    # 等待一段时间再次检查
    sleep 180  # 每3分钟检查一次
done 
