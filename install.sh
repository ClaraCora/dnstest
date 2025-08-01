#!/bin/bash

# DNS Ping测试自动更换服务 - 一键安装脚本
# 作者: AI Assistant
# 版本: 1.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GitHub仓库信息
GITHUB_REPO="ClaraCora/dnstest"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

# 安装目录
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="ping_dns_monitor.sh"
SERVICE_NAME="ping-dns-monitor"

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
        print_status $YELLOW "请使用: sudo bash install.sh"
        exit 1
    fi
}

# 检查网络连接
check_network() {
    if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        print_status $RED "错误: 无法连接到网络"
        exit 1
    fi
}

# 检查必要工具
check_dependencies() {
    local missing_tools=()
    
    for tool in curl; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_status $RED "错误: 缺少必要工具: ${missing_tools[*]}"
        print_status $YELLOW "请安装缺少的工具后重试"
        exit 1
    fi
    
    # 检查系统类型
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_status $YELLOW "无法检测操作系统类型"
        OS="Unknown"
    fi
    
    print_status $GREEN "检测到操作系统: $OS"
}

# 下载脚本
download_script() {
    print_status $BLUE "正在下载DNS监控脚本..."
    
    local download_url="${GITHUB_RAW_URL}/${SCRIPT_NAME}"
    local temp_script="/tmp/${SCRIPT_NAME}"
    
    # 检查下载URL是否可访问
    if ! curl -fsSL --head "$download_url" > /dev/null 2>&1; then
        print_status $RED "错误: 无法访问下载地址"
        print_status $YELLOW "请检查网络连接或仓库地址是否正确"
        exit 1
    fi
    
    if curl -fsSL "$download_url" -o "$temp_script"; then
        # 验证下载的文件
        if [[ -f "$temp_script" ]] && [[ -s "$temp_script" ]]; then
            chmod +x "$temp_script"
            mv "$temp_script" "${INSTALL_DIR}/${SCRIPT_NAME}"
            print_status $GREEN "脚本下载成功"
        else
            print_status $RED "错误: 下载的文件无效"
            rm -f "$temp_script"
            exit 1
        fi
    else
        print_status $RED "错误: 无法下载脚本"
        print_status $YELLOW "请检查网络连接"
        exit 1
    fi
}

# 创建配置文件目录
create_config_dirs() {
    mkdir -p /etc/XrayR
    print_status $GREEN "配置文件目录已创建"
}

# 生成默认配置文件
generate_default_config() {
    local config_file="/etc/XrayR/ping_monitor_config.json"
    
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
{
  "dns_servers": "1.1.1.1,8.8.8.8,9.9.9.9,208.67.222.222",
  "check_interval": 300,
  "ping_count": 5,
  "fluctuation_threshold": 0.5,
  "timeout_seconds": 3
}
EOF
        print_status $GREEN "默认配置文件已生成: $config_file"
    else
        print_status $YELLOW "配置文件已存在: $config_file"
    fi
}

# 生成DNS配置文件
generate_dns_config() {
    local dns_config="/etc/XrayR/dns.json"
    
    if [[ ! -f "$dns_config" ]]; then
        cat > "$dns_config" << 'EOF'
{
  "servers": [
    "1.1.1.1",
    "8.8.8.8",
    {
      "address": "1.1.1.1",
      "port": 53,
      "domains": [
        "geosite:netflix",
        "geosite:disney",
        "geosite:google",
        "geosite:disney",
        "youtube.com"
      ],
      "ips": [
        "geoip:netflix"
      ]
    }
  ],
  "tag": "dns_inbound"
}
EOF
        print_status $GREEN "DNS配置文件已生成: $dns_config"
    else
        print_status $YELLOW "DNS配置文件已存在: $dns_config"
    fi
}

# 创建系统服务
create_systemd_service() {
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=Ping DNS Monitor Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=${INSTALL_DIR}/${SCRIPT_NAME} --daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    print_status $GREEN "系统服务已创建: $SERVICE_NAME"
}

# 创建日志目录
create_log_dir() {
    mkdir -p /var/log
    touch /var/log/ping-dns-monitor.log
    chmod 644 /var/log/ping-dns-monitor.log
    print_status $GREEN "日志文件已创建"
}

# 显示安装信息
show_install_info() {
    echo
    print_status $GREEN "=== 安装完成 ==="
    echo
    print_status $BLUE "服务信息:"
    print_status $BLUE "  脚本位置: ${INSTALL_DIR}/${SCRIPT_NAME}"
    print_status $BLUE "  配置文件: /etc/XrayR/ping_monitor_config.json"
    print_status $BLUE "  DNS配置: /etc/XrayR/dns.json"
    print_status $BLUE "  日志文件: /var/log/ping-dns-monitor.log"
    echo
    print_status $BLUE "使用方法:"
    print_status $BLUE "  启动服务: systemctl start $SERVICE_NAME"
    print_status $BLUE "  停止服务: systemctl stop $SERVICE_NAME"
    print_status $BLUE "  查看状态: systemctl status $SERVICE_NAME"
    print_status $BLUE "  运行测试: ${INSTALL_DIR}/${SCRIPT_NAME} --test"
    echo
    print_status $BLUE "下一步操作:"
    print_status $BLUE "1. 编辑配置文件: nano /etc/XrayR/ping_monitor_config.json"
    print_status $BLUE "2. 启动服务: systemctl start $SERVICE_NAME"
    print_status $BLUE "3. 设置开机自启: systemctl enable $SERVICE_NAME"
    print_status $BLUE "4. 运行测试: ${INSTALL_DIR}/${SCRIPT_NAME} --test"
    echo
    print_status $YELLOW "注意: 请确保XrayR服务已正确安装并配置"
    print_status $YELLOW "配置文件位置: /etc/XrayR/ping_monitor_config.json"
    echo
}

# 卸载服务
uninstall_service() {
    print_status $BLUE "正在卸载DNS监控服务..."
    
    # 停止服务
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # 删除服务文件
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload
    
    # 删除脚本文件
    rm -f "${INSTALL_DIR}/${SCRIPT_NAME}"
    
    print_status $GREEN "服务已卸载"
    print_status $YELLOW "注意: 配置文件未删除，如需完全清理请手动删除:"
    print_status $YELLOW "  /etc/XrayR/ping_monitor_config.json"
    print_status $YELLOW "  /etc/XrayR/dns.json"
    print_status $YELLOW "  /var/log/ping-dns-monitor.log"
}

# 显示帮助信息
show_help() {
    cat << 'EOF'
DNS Ping测试自动更换服务安装程序

用法:
    $0 [选项]

选项:
    --install     安装服务 (默认)
    --uninstall   卸载服务
    --help        显示此帮助信息

示例:
    $0              # 安装服务
    $0 --install    # 安装服务
    $0 --uninstall  # 卸载服务
EOF
}

# 主安装函数
main() {
    print_status $BLUE "=== DNS Ping测试自动更换服务安装程序 ==="
    echo
    
    # 检查环境
    check_root
    check_network
    check_dependencies
    
    # 安装步骤
    download_script
    create_config_dirs
    generate_default_config
    generate_dns_config
    create_systemd_service
    create_log_dir
    
    # 显示安装信息
    show_install_info
    
    print_status $GREEN "安装完成！"
}

# 主函数
main() {
    case "${1:-}" in
        --install|"")
            print_status $BLUE "=== DNS Ping测试自动更换服务安装程序 ==="
            echo
            
            # 检查环境
            check_root
            check_network
            check_dependencies
            
            # 安装步骤
            download_script
            create_config_dirs
            generate_default_config
            generate_dns_config
            create_systemd_service
            create_log_dir
            
            # 显示安装信息
            show_install_info
            
            print_status $GREEN "安装完成！"
            ;;
        --uninstall)
            check_root
            uninstall_service
            ;;
        --help)
            show_help
            ;;
        *)
            print_status $RED "错误: 未知参数 '$1'"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@" 