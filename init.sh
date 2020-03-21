#!/bin/bash
set -e

echo "关闭防火墙"
systemctl stop firewalld.service
systemctl disable firewalld.service
iptables -F
echo "NetworkManager"
systemctl stop NetworkManager.service
systemctl disable NetworkManager.service

yum install ntpdate crontabs -y
cat >>/etc/crontab<<EOF
*/5 * * * * /usr/sbin/ntpdate ntp1.aliyun.com > /dev/null 2>&1
*/5 * * * * /usr/sbin/ntpdate ntp2.aliyun.com > /dev/null 2>&1
EOF

systemctl restart crond
systemctl enable crond
systemctl reload crond
timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp yes
timedatectl set-local-rtc 1
hwclock --systohc --utc

yum install -y wget
mkdir -p /etc/yum.repos.d/bak
cd /etc/yum.repos.d
mv *.repo bak
cd /root
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum install epel-release
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux 
yum clean all
yum makecache

yum install python-devel gcc zlib zlib-devel openssl-devel tcpdump net-tools lsof telnet ntp -y
yum install epel-release -y
yum install python-pip -y
pip install --upgrade pip

cat >>/etc/rc.local<<EOF
#open files
ulimit -SHn 65535
#stack size
ulimit -s 65535
EOF

swapoff -a
sed -i 's/.*swap.*/#&/' /etc/fstab
cat >/etc/sysctl.conf<<EOF
# 关闭 ipv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# 避免放大攻击 
net.ipv4.icmp_echo_ignore_broadcasts = 1

# 开启恶意 icmp 错误消息保护 
net.ipv4.icmp_ignore_bogus_error_responses = 1

# 关闭路由转发 
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# 开启反向路径过滤 
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# 处理无源路由的包 
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# 关闭 sysrq 功能 
kernel.sysrq = 0

# core 文件名中添加 pid 作为扩展名 
kernel.core_uses_pid = 1

# 开启 SYN 洪水攻击保护 
net.ipv4.tcp_syncookies = 1

# 修改消息队列长度 
kernel.msgmnb = 65536
kernel.msgmax = 65536

# 设置最大内存共享段大小 bytes
kernel.shmmax = 68719476736
kernel.shmall = 4294967296

# timewait 的数量，默认 180000
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 16384 4194304
net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# 每个网络接口接收数据包的速率比内核处理这些包的速率快时，允许送到队列的数据包的最大数目 
net.core.netdev_max_backlog = 262144

# 限制仅仅是为了防止简单的 DDoS 攻击 
net.ipv4.tcp_max_orphans = 3276800

# 未收到客户端确认信息的连接请求的最大值 
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_timestamps = 0

# 内核放弃建立连接之前发送 SYNACK 包的数量 
net.ipv4.tcp_synack_retries = 1

# 内核放弃建立连接之前发送 SYN 包的数量 
net.ipv4.tcp_syn_retries = 1

# 启用 timewait 快速回收 
net.ipv4.tcp_tw_recycle = 1

# 开启重用，允许将 TIME-WAIT sockets 重新用于新的 TCP 连接 
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_fin_timeout = 1

# 当 keepalive 起用的时候，TCP 发送 keepalive 消息的频度。缺省是 2 小时 
net.ipv4.tcp_keepalive_time = 30

# 允许系统打开的端口范围 
net.ipv4.ip_local_port_range = 1024    65000

# 修改防火墙表大小，默认 65536
#net.netfilter.nf_conntrack_max=655350
#net.netfilter.nf_conntrack_tcp_timeout_established=1200

# 确保无人能修改路由表 
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
EOF

cp /etc/ssh/sshd_config{,.bak}
cat >/etc/ssh/sshd_config<<EOF
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
SyslogFacility AUTHPRIV
AuthorizedKeysFile	.ssh/authorized_keys
PasswordAuthentication yes
ChallengeResponseAuthentication no
GSSAPIAuthentication no
GSSAPICleanupCredentials no
UsePAM yes
X11Forwarding yes
AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES
AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT
AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE
AcceptEnv XMODIFIERS
Subsystem	sftp	/usr/libexec/openssh/sftp-server
UseDNS=no
UseDNS=no
IgnoreRhosts yes
EOF

sed -i 's/hosts:      files dns myhostname/hosts:      files dns/g' /etc/nsswitch.conf

yum install vim-* -y
cat >>/etc/vimrc<<EOF
set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4
autocmd FileType html setlocal shiftwidth=4 tabstop=4 softtabstop=4
autocmd FileType golang setlocal shiftwidth=4 tabstop=4 softtabstop=4
autocmd FileType go setlocal shiftwidth=4 tabstop=4 softtabstop=4
autocmd FileType yml setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType yaml setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType htmldjango setlocal shiftwidth=4 tabstop=4 softtabstop=4
autocmd FileType javascript setlocal shiftwidth=4 tabstop=4 softtabstop=4
set ls=2
set incsearch
set hlsearch
syntax on
set ruler
set autoindent
EOF
