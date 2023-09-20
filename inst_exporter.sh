#!/bin/bash

# 检查是否具有root权限
if [ "$(id -u)" != "0" ]; then
  echo "请以root权限运行此脚本。"
  exit 1
fi

# 设置Node Exporter版本
NODE_EXPORTER_VERSION="1.0.0"

# 设置Node Exporter的安装目录
NODE_EXPORTER_DIR="/opt/node_exporter"

# 检查是否存在wget或curl命令，如果都不存在则退出
if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
  echo "请安装wget或curl命令。"
  exit 1
fi

# 检查操作系统类型
if [ -f /etc/os-release ]; then
  # 使用source命令加载os-release文件以获取操作系统信息
  source /etc/os-release

  if [[ $ID == "centos" || $ID == "rhel" ]]; then
    # 如果是CentOS或Red Hat Enterprise Linux
    pkg_manager="yum"
    # 开放防火墙端口
    firewall-cmd --zone=public --add-port=9100/tcp --permanent
    firewall-cmd --reload
  elif [[ $ID == "debian" || $ID == "ubuntu" ]]; then
    # 如果是Debian或Ubuntu
    pkg_manager="apt"
    # 开放防火墙端口
    ufw allow 9100/tcp
  else
    echo "不支持的操作系统。"
    exit 1
  fi
else
  echo "无法确定操作系统类型。"
  exit 1
fi

# 使用wget或curl下载Node Exporter
if command -v wget &> /dev/null; then
  wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" -O node_exporter.tar.gz
elif command -v curl &> /dev/null; then
  curl -o node_exporter.tar.gz -L "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
fi

# 检查下载是否成功
if [ ! -e node_exporter.tar.gz ]; then
  echo "无法下载Node Exporter，请手动下载并解压。"
  exit 1
fi

# 解压Node Exporter
tar -xzvf node_exporter.tar.gz
rm node_exporter.tar.gz
mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64" "$NODE_EXPORTER_DIR"

# 创建Node Exporter用户
useradd -rs /bin/false node_exporter

# 创建Systemd服务单元文件
cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
ExecStart=$NODE_EXPORTER_DIR/node_exporter
User=node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 安装Node Exporter依赖（例如wget或curl）
if [ -n "$pkg_manager" ]; then
  $pkg_manager install -y wget curl
fi

# 启用并启动Node Exporter服务
systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

echo -e "\e[32mNode Exporter已安装并正在运行。\e[0m"

