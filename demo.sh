#!/bin/bash

# DNS Ping测试自动更换服务 - 演示脚本
# 作者: AI Assistant
# 版本: 1.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 显示演示信息
show_demo() {
    print_status $BLUE "=== DNS Ping测试自动更换服务演示 ==="
    echo
    
    print_status $GREEN "功能演示:"
    echo "1. 自动测试DNS服务器延迟和稳定性"
    echo "2. 选择最佳的DNS服务器"
    echo "3. 自动更新XrayR配置"
    echo "4. 智能避免不必要的更新"
    echo "5. 提供详细的测试日志"
    echo
    
    print_status $YELLOW "支持的DNS服务器:"
    echo "• 1.1.1.1 (Cloudflare)"
    echo "• 8.8.8.8 (Google)"
    echo "• 9.9.9.9 (Quad9)"
    echo "• 208.67.222.222 (OpenDNS)"
    echo
    
    print_status $BLUE "安装方法:"
    echo "curl -fsSL https://raw.githubusercontent.com/ClaraCora/dnstest/main/install.sh | sudo bash"
    echo
    
    print_status $BLUE "使用方法:"
    echo "• 运行测试: sudo ping_dns_monitor.sh --test"
    echo "• 启动服务: sudo systemctl start ping-dns-monitor"
    echo "• 查看状态: sudo systemctl status ping-dns-monitor"
    echo "• 查看日志: sudo tail -f /var/log/ping-dns-monitor.log"
    echo
    
    print_status $GREEN "演示完成！"
}

# 主函数
main() {
    show_demo
}

# 运行主函数
main "$@" 