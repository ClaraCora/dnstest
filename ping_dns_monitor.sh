#!/bin/bash

# DNS Ping测试自动更换脚本 - 本地测试版本
# 作者: AI Assistant
# 版本: 1.1 (修复版本)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置文件路径
CONFIG_FILE="/etc/XrayR/ping_monitor_config.json"

# 配置文件路径
DNS_CONFIG="/etc/XrayR/dns.json"
SERVICE_NAME="ping-dns-monitor"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# 日志文件
LOG_FILE="/var/log/ping-dns-monitor.log"

# 测试日志文件（只保留本次结果）
TEST_LOG_FILE="/tmp/ping-dns-test.log"

# 默认配置
DEFAULT_IPS="1.1.1.1,8.8.8.8,9.9.9.9,208.67.222.222"
DEFAULT_INTERVAL=300

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 测试日志函数（只保留本次结果）
test_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" > "$TEST_LOG_FILE"
}

# 打印带颜色的消息
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_status $RED "错误: 此脚本需要root权限运行"
        exit 1
    fi
}

# 检查必要工具
check_dependencies() {
    local missing_tools=()
    
    for tool in ping jq; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_status $RED "错误: 缺少必要工具: ${missing_tools[*]}"
        exit 1
    fi
}

# 检查XrayR服务状态（兼容macOS和Linux）
check_xrayr_service() {
    # 检查是否为macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS系统
        if pgrep -f "xrayr" > /dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        # Linux系统
        if command -v systemctl > /dev/null 2>&1 && systemctl is-active --quiet xrayr 2>/dev/null; then
            return 0
        else
            return 1
        fi
    fi
}

# 重启XrayR服务（兼容macOS和Linux）
restart_xrayr_service() {
    log "重启XrayR服务..."
    
    if check_xrayr_service; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS系统
            pkill -f "xrayr" 2>/dev/null || true
            sleep 2
            # 尝试启动XrayR（需要根据实际安装路径调整）
            if [[ -f "/usr/local/bin/xrayr" ]]; then
                /usr/local/bin/xrayr &
            elif [[ -f "/opt/xrayr/xrayr" ]]; then
                /opt/xrayr/xrayr &
            else
                log "未找到XrayR可执行文件"
                print_status $YELLOW "请手动启动XrayR服务"
            fi
        else
            # Linux系统
            systemctl restart xrayr
        fi
        
        sleep 3
        
        if check_xrayr_service; then
            log "XrayR服务重启成功"
            print_status $GREEN "XrayR服务已重启"
        else
            log "XrayR服务重启失败"
            print_status $RED "XrayR服务重启失败"
        fi
    else
        log "XrayR服务未运行"
        print_status $YELLOW "XrayR服务未运行"
        
        # 尝试启动服务
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if [[ -f "/usr/local/bin/xrayr" ]]; then
                /usr/local/bin/xrayr &
                log "尝试启动XrayR服务"
            elif [[ -f "/opt/xrayr/xrayr" ]]; then
                /opt/xrayr/xrayr &
                log "尝试启动XrayR服务"
            else
                log "未找到XrayR可执行文件"
                print_status $YELLOW "请手动启动XrayR服务"
            fi
        else
            systemctl start xrayr 2>/dev/null || log "无法启动XrayR服务"
        fi
    fi
}

# 创建默认配置文件
create_default_config() {
    if [[ ! -f "$DNS_CONFIG" ]]; then
        cat > "$DNS_CONFIG" << 'EOF'
{
  "servers": [
    "1.1.1.1",
    "8.8.8.8",
    {
      "address": "1.1.1.1",
      "port": 53,
      "domains": ["geosite:netflix","geosite:disney","geosite:google","geosite:disney","youtube.com"],
      "ips": ["geoip:netflix"]
    }
  ],
  "tag": "dns_inbound"
}
EOF
        log "创建默认DNS配置文件"
    fi
}

# 读取配置文件
read_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        IPS=$(jq -r '.dns_servers' "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_IPS")
        INTERVAL=$(jq -r '.check_interval' "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_INTERVAL")
        PING_COUNT=$(jq -r '.ping_count' "$CONFIG_FILE" 2>/dev/null || echo "5")
        FLUCTUATION_THRESHOLD=$(jq -r '.fluctuation_threshold' "$CONFIG_FILE" 2>/dev/null || echo "0.5")
        TIMEOUT_SECONDS=$(jq -r '.timeout_seconds' "$CONFIG_FILE" 2>/dev/null || echo "3")
        
        print_status $GREEN "从配置文件读取设置:"
        print_status $GREEN "DNS服务器: $IPS"
        print_status $GREEN "检测间隔: ${INTERVAL}秒"
        print_status $GREEN "Ping次数: ${PING_COUNT}次"
        print_status $GREEN "波动阈值: ${FLUCTUATION_THRESHOLD}"
        print_status $GREEN "超时时间: ${TIMEOUT_SECONDS}秒"
        echo
    else
        # 创建默认配置文件
        create_default_config_file
        read_config
    fi
}

# 创建默认配置文件
create_default_config_file() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << EOF
{
  "dns_servers": "$DEFAULT_IPS",
  "check_interval": $DEFAULT_INTERVAL,
  "ping_count": 5,
  "fluctuation_threshold": 0.5,
  "timeout_seconds": 3
}
EOF
    print_status $GREEN "已创建默认配置文件: $CONFIG_FILE"
    print_status $YELLOW "请编辑配置文件设置DNS服务器IP地址"
}

# 获取用户输入
get_user_input() {
    print_status $BLUE "=== DNS Ping测试自动更换服务 ==="
    echo
    
    # 读取配置文件
    read_config
    
    # 验证配置
    if [[ ! "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -lt 60 ]]; then
        print_status $RED "错误: 检测间隔必须为大于60的整数"
        exit 1
    fi
    
    print_status $GREEN "配置信息:"
    print_status $GREEN "DNS服务器: $IPS"
    print_status $GREEN "检测间隔: ${INTERVAL}秒"
    echo
}

# 计算ping统计信息
calculate_ping_stats() {
    local ip=$1
    local ping_results=()
    local total_time=0
    local min_time=999999
    local max_time=0
    local success_count=0
    
    # 执行ping测试
    for i in $(seq 1 $PING_COUNT); do
        # 兼容Linux和macOS的ping输出格式
        local ping_output=$(ping -c 1 -W $TIMEOUT_SECONDS "$ip" 2>/dev/null)
        local time_result=""
        
        # 尝试从ping输出中提取时间
        if echo "$ping_output" | grep -q "time="; then
            # Linux格式: time=123.456 ms
            time_result=$(echo "$ping_output" | grep "time=" | awk '{print $7}' | sed 's/time=//' | sed 's/ms//')
        elif echo "$ping_output" | grep -q "round-trip"; then
            # macOS格式: round-trip min/avg/max/stddev = 163.163/227.766/356.071/90.726 ms
            time_result=$(echo "$ping_output" | grep "round-trip" | awk '{print $4}' | cut -d'/' -f2)
        fi
        
        if [[ -n "$time_result" ]] && [[ "$time_result" != "0.000" ]] && [[ "$time_result" != "timeout" ]] && [[ "$time_result" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            local time="$time_result"
            ping_results+=("$time")
            total_time=$(echo "$total_time + $time" | bc -l 2>/dev/null || echo "$((total_time + time))")
            min_time=$(echo "if ($time < $min_time) $time else $min_time" | bc -l 2>/dev/null || echo "$((time < min_time ? time : min_time))")
            max_time=$(echo "if ($time > $max_time) $time else $max_time" | bc -l 2>/dev/null || echo "$((time > max_time ? time : max_time))")
            ((success_count++))
        else
            ping_results+=("timeout")
        fi
        
        sleep 1
    done
    
    # 计算平均值和波动
    local avg_time=0
    local variance=0
    
    if [[ $success_count -gt 0 ]]; then
        avg_time=$(echo "scale=2; $total_time / $success_count" | bc -l 2>/dev/null || echo "$((total_time / success_count))")
        
        # 计算方差
        for time in "${ping_results[@]}"; do
            if [[ "$time" != "timeout" ]]; then
                local diff=$(echo "$time - $avg_time" | bc -l 2>/dev/null || echo "$((time - avg_time))")
                local diff_squared=$(echo "$diff * $diff" | bc -l 2>/dev/null || echo "$((diff * diff))")
                variance=$(echo "$variance + $diff_squared" | bc -l 2>/dev/null || echo "$((variance + diff_squared))")
            fi
        done
        
        if [[ $success_count -gt 1 ]]; then
            variance=$(echo "scale=2; $variance / ($success_count - 1)" | bc -l 2>/dev/null || echo "$((variance / (success_count - 1)))")
        fi
    fi
    
    # 返回结果
    echo "$success_count:$avg_time:$min_time:$max_time:$variance"
}

# 测试DNS服务器
test_dns_servers() {
    local ips=($(echo "$IPS" | tr ',' ' '))
    local best_ip=""
    local best_score=999999
    local results=()
    
    test_log "开始测试DNS服务器..."
    print_status $BLUE "开始测试DNS服务器..."
    
    for ip in "${ips[@]}"; do
        ip=$(echo "$ip" | xargs) # 去除空格
        if [[ -z "$ip" ]]; then
            continue
        fi
        
        test_log "测试 $ip..."
        print_status $YELLOW "测试 $ip..."
        local stats=$(calculate_ping_stats "$ip")
        local success_count=$(echo "$stats" | cut -d: -f1)
        local avg_time=$(echo "$stats" | cut -d: -f2)
        local min_time=$(echo "$stats" | cut -d: -f3)
        local max_time=$(echo "$stats" | cut -d: -f4)
        local variance=$(echo "$stats" | cut -d: -f5)
        
        # 计算波动率
        local fluctuation=0
        if [[ $(echo "$avg_time > 0" | bc -l 2>/dev/null || echo "$((avg_time > 0))") -eq 1 ]]; then
            fluctuation=$(echo "scale=2; $variance / $avg_time" | bc -l 2>/dev/null || echo "$((variance / avg_time))")
        fi
        
        # 判断是否通过测试
        local passed=false
        local reason=""
        
        if [[ $success_count -eq $PING_COUNT ]]; then
            if [[ $(echo "$fluctuation < $FLUCTUATION_THRESHOLD" | bc -l 2>/dev/null || echo "$((fluctuation < FLUCTUATION_THRESHOLD))") -eq 1 ]]; then
                passed=true
                reason="通过"
            else
                reason="波动过大 (${fluctuation})"
            fi
        else
            reason="连接失败 ($success_count/$PING_COUNT)"
        fi
        
        # 计算综合评分 (越低越好)
        local score=999999
        if [[ $success_count -gt 0 ]]; then
            score=$(echo "$avg_time + $fluctuation * 100" | bc -l 2>/dev/null || echo "$((avg_time + fluctuation * 100))")
        fi
        
        results+=("$ip:$success_count:$avg_time:$fluctuation:$passed:$score:$reason")
        
        if [[ "$passed" == "true" ]]; then
            test_log "✓ $ip - 平均延迟: ${avg_time}ms, 波动: ${fluctuation}"
            print_status $GREEN "✓ $ip - 平均延迟: ${avg_time}ms, 波动: ${fluctuation}"
            best_ip="$ip"
            break
        else
            test_log "✗ $ip - $reason"
            print_status $RED "✗ $ip - $reason"
            
            # 更新最佳IP
            if [[ $(echo "$score < $best_score" | bc -l 2>/dev/null || echo "$((score < best_score))") -eq 1 ]]; then
                best_score="$score"
                best_ip="$ip"
            fi
        fi
    done
    
    # 如果没有通过的，使用最佳的
    if [[ -z "$best_ip" ]]; then
        test_log "所有DNS服务器测试失败，使用最佳备选方案"
        print_status $YELLOW "所有DNS服务器测试失败，使用最佳备选方案"
        for result in "${results[@]}"; do
            local ip=$(echo "$result" | cut -d: -f1)
            local score=$(echo "$result" | cut -d: -f6)
            if [[ $(echo "$score < $best_score" | bc -l 2>/dev/null || echo "$((score < best_score))") -eq 1 ]]; then
                best_score="$score"
                best_ip="$ip"
            fi
        done
    fi
    
    test_log "选择最佳DNS服务器: $best_ip"
    
    # 返回最佳IP地址
    echo "$best_ip"
}

# 获取当前DNS配置中的IP地址
get_current_dns_ip() {
    if [[ ! -f "$DNS_CONFIG" ]]; then
        return 1
    fi
    
    # 查找配置文件中第一个有address字段的对象
    local current_ip=$(jq -r '.servers[] | select(type == "object" and has("address")) | .address' "$DNS_CONFIG" 2>/dev/null | head -n 1)
    
    # 验证IP地址格式
    if [[ -n "$current_ip" ]] && [[ "$current_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$current_ip"
        return 0
    else
        return 1
    fi
}

# 更新DNS配置文件（不创建备份）
update_dns_config() {
    local new_ip=$1
    
    if [[ -z "$new_ip" ]]; then
        log "错误: 没有可用的DNS服务器"
        return 1
    fi
    
    # 检查当前配置
    local current_ip=$(get_current_dns_ip)
    
    if [[ -n "$current_ip" ]] && [[ "$current_ip" == "$new_ip" ]]; then
        log "当前DNS配置已经是 $new_ip，无需更新"
        test_log "当前DNS配置已经是 $new_ip，无需更新"
        print_status $GREEN "当前DNS配置已经是 $new_ip，无需更新"
        return 1
    fi
    
    log "更新DNS配置为: $new_ip"
    test_log "更新DNS配置为: $new_ip"
    
    # 读取当前配置
    if [[ ! -f "$DNS_CONFIG" ]]; then
        create_default_config
    fi
    
    # 更新配置文件（不创建备份）
    local temp_config=$(mktemp)
    
    # 提取当前的domains和ips
    local domains=$(jq -r '.servers[] | select(type == "object" and has("domains")) | .domains | map("\"" + . + "\"") | join(",")' "$DNS_CONFIG" 2>/dev/null || echo '"geosite:netflix","geosite:disney","geosite:google","geosite:disney","youtube.com"')
    local ips=$(jq -r '.servers[] | select(type == "object" and has("ips")) | .ips | map("\"" + . + "\"") | join(",")' "$DNS_CONFIG" 2>/dev/null || echo '"geoip:netflix"')
    
    # 构建新的JSON，保持数组在一行
    cat > "$temp_config" << EOF
{
  "servers": [
    "1.1.1.1",
    "8.8.8.8",
    {
      "address": "$new_ip",
      "port": 53,
      "domains": [$domains],
      "ips": [$ips]
    }
  ],
  "tag": "dns_inbound"
}
EOF
    
    mv "$temp_config" "$DNS_CONFIG"
    
    log "DNS配置文件已更新"
    test_log "DNS配置文件已更新"
    print_status $GREEN "DNS配置已更新为: $new_ip"
    print_status $GREEN "配置文件位置: $DNS_CONFIG"
}

# 重启XrayR服务
restart_xrayr() {
    log "重启XrayR服务..."
    test_log "重启XrayR服务..."
    
    restart_xrayr_service
}

# 主测试函数
run_test() {
    # 清空测试日志文件
    > "$TEST_LOG_FILE"
    
    # 读取配置文件
    read_config
    log "开始DNS测试..."
    test_log "开始DNS测试..."
    
    # 重定向输出以避免干扰，只获取最后一行（IP地址）
    local best_ip=$(test_dns_servers 2>&1 | tail -n 1 | tr -d '\r')
    
    # 验证IP地址格式
    if [[ -n "$best_ip" ]] && [[ "$best_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # 尝试更新DNS配置
        if update_dns_config "$best_ip"; then
            # 配置已更新，重启服务
            restart_xrayr
        else
            # 配置没有更新，不需要重启服务
            log "DNS配置未更改，跳过服务重启"
            test_log "DNS配置未更改，跳过服务重启"
            print_status $GREEN "DNS配置未更改，跳过服务重启"
        fi
        test_log "测试完成，最佳DNS服务器: $best_ip"
    else
        log "没有找到可用的DNS服务器"
        test_log "没有找到可用的DNS服务器"
        print_status $RED "错误: 没有找到可用的DNS服务器"
    fi
    
    # 显示测试日志
    echo
    print_status $BLUE "=== 本次测试日志 ==="
    cat "$TEST_LOG_FILE"
    echo
}

# 守护进程模式
daemon_mode() {
    # 读取配置文件
    read_config
    log "启动守护进程模式，检测间隔: ${INTERVAL}秒"
    print_status $YELLOW "按 Ctrl+C 停止守护进程"
    
    while true; do
        run_test
        print_status $BLUE "等待 ${INTERVAL} 秒后进行下一次检测..."
        sleep "$INTERVAL"
    done
}

# 显示帮助信息
show_help() {
    cat << 'EOF'
DNS Ping测试自动更换服务

用法:
    $0 [选项]

选项:
    --install     安装并启动服务
    --uninstall   卸载服务
    --start       启动服务
    --stop        停止服务
    --status      查看服务状态
    --test        运行一次测试
    --daemon      守护进程模式
    --help        显示此帮助信息

示例:
    $0 --install    # 安装服务
    $0 --test       # 运行一次测试
    $0 --status     # 查看服务状态
EOF
}

# 创建系统服务
create_service() {
    local script_path=$(readlink -f "$0")
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Ping DNS Monitor Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=$script_path --daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    log "系统服务已创建: $SERVICE_NAME"
    print_status $GREEN "系统服务已创建并启用"
}

# 主函数
main() {
    check_root
    check_dependencies
    
    case "${1:-}" in
        --install)
            get_user_input
            create_service
            systemctl start "$SERVICE_NAME"
            print_status $GREEN "服务安装完成并已启动"
            ;;
        --uninstall)
            systemctl stop "$SERVICE_NAME" 2>/dev/null || true
            systemctl disable "$SERVICE_NAME" 2>/dev/null || true
            rm -f "$SERVICE_FILE"
            systemctl daemon-reload
            print_status $GREEN "服务已卸载"
            ;;
        --start)
            systemctl start "$SERVICE_NAME"
            print_status $GREEN "服务已启动"
            ;;
        --stop)
            systemctl stop "$SERVICE_NAME"
            print_status $GREEN "服务已停止"
            ;;
        --status)
            systemctl status "$SERVICE_NAME" --no-pager
            ;;
        --test)
            get_user_input
            run_test
            ;;
        --daemon)
            get_user_input
            daemon_mode
            ;;
        --help)
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@" 
