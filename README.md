# DNS Ping测试自动更换服务

一个智能的DNS服务器监控和自动切换工具，通过ping测试自动选择最佳的DNS服务器，并自动更新XrayR配置。

## 功能特性

- ✅ **智能DNS选择**: 通过ping测试自动选择延迟最低、最稳定的DNS服务器
- ✅ **自动配置更新**: 自动更新XrayR的DNS配置文件
- ✅ **服务管理**: 支持systemd服务管理，开机自启动
- ✅ **智能检测**: 避免不必要的配置更新和服务重启
- ✅ **详细日志**: 提供详细的测试日志和运行状态
- ✅ **跨平台支持**: 支持Linux和macOS系统
- ✅ **一键安装**: 提供简单的一键安装脚本

## 支持的DNS服务器

默认支持以下DNS服务器：
- 1.1.1.1 (Cloudflare)
- 8.8.8.8 (Google)
- 9.9.9.9 (Quad9)
- 208.67.222.222 (OpenDNS)


### 手动安装

```bash
# 1. 克隆仓库
git clone https://github.com/ClaraCora/dnstest.git
cd ping-dns-monitor

# 2. 运行安装脚本
sudo bash install.sh

# 3. 启动服务
sudo systemctl start ping-dns-monitor

# 4. 设置开机自启
sudo systemctl enable ping-dns-monitor
```

## 使用方法

### 基本命令

```bash
# 运行一次测试
sudo ping_dns_monitor.sh --test

# 启动守护进程模式
sudo ping_dns_monitor.sh --daemon

# 查看服务状态
sudo systemctl status ping-dns-monitor

# 启动服务
sudo systemctl start ping-dns-monitor

# 停止服务
sudo systemctl stop ping-dns-monitor

# 查看帮助
sudo ping_dns_monitor.sh --help
```

### 配置文件

配置文件位置：`/etc/XrayR/ping_monitor_config.json`

```json
{
  "dns_servers": "1.1.1.1,8.8.8.8,9.9.9.9,208.67.222.222",
  "check_interval": 300,
  "ping_count": 5,
  "fluctuation_threshold": 0.5,
  "timeout_seconds": 3
}
```

配置说明：
- `dns_servers`: DNS服务器列表，用逗号分隔
- `check_interval`: 检测间隔（秒）
- `ping_count`: 每次ping测试的次数
- `fluctuation_threshold`: 波动阈值，超过此值认为不稳定
- `timeout_seconds`: ping超时时间（秒）

### DNS配置文件

DNS配置文件位置：`/etc/XrayR/dns.json`

```json
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
```

## 工作原理

1. **DNS测试**: 对配置的DNS服务器进行ping测试
2. **评分计算**: 根据延迟、波动率等指标计算综合评分
3. **选择最佳**: 选择评分最高的DNS服务器
4. **配置更新**: 如果选择的DNS与当前配置不同，则更新配置文件
5. **服务重启**: 重启XrayR服务以应用新配置
6. **定期检测**: 按设定的间隔重复以上过程

## 日志文件

- 运行日志：`/var/log/ping-dns-monitor.log`
- 测试日志：`/tmp/ping-dns-test.log`（每次测试后清空）

## 系统要求

- Linux 或 macOS
- root权限
- 网络连接
- 已安装的XrayR服务（可选）

## 故障排除

### 常见问题

1. **权限错误**
   ```bash
   sudo chmod +x /usr/local/bin/ping_dns_monitor.sh
   ```

2. **配置文件不存在**
   ```bash
   sudo mkdir -p /etc/XrayR
   sudo cp dns.json.example /etc/XrayR/dns.json
   ```

3. **XrayR服务未运行**
   - 确保XrayR已正确安装
   - 检查XrayR配置文件路径

4. **网络连接问题**
   - 检查网络连接
   - 确认防火墙设置

### 查看日志

```bash
# 查看运行日志
sudo tail -f /var/log/ping-dns-monitor.log

# 查看系统服务日志
sudo journalctl -u ping-dns-monitor -f
```

## 卸载

```bash
# 停止服务
sudo systemctl stop ping-dns-monitor

# 禁用服务
sudo systemctl disable ping-dns-monitor

# 删除服务文件
sudo rm -f /etc/systemd/system/ping-dns-monitor.service

# 重新加载systemd
sudo systemctl daemon-reload

# 删除脚本文件
sudo rm -f /usr/local/bin/ping_dns_monitor.sh
```

## 贡献

欢迎提交Issue和Pull Request！

## 许可证

MIT License

## 更新日志

### v1.1
- 修复ping测试解析问题
- 添加智能配置检测，避免不必要的更新
- 改进日志输出，只保留本次测试结果
- 移除备份文件创建功能
- 增强跨平台兼容性

### v1.0
- 初始版本发布
- 基本DNS测试和切换功能
- systemd服务支持 
