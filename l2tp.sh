#!/bin/bash
#centos7
read -p "分配客户端地址池： " a
read -p "给自己分配的ip: " b
#这里的ip请输入内网ip不要输入弹性ip
read -p "服务器ip: " c
read -p "用户名: " d
read -p "密码: " e
read -p " 设置PSK预共享密钥: " f
read -p "分配客户端的网段如:192.168.1.0: " g

yum install  xl2tpd libreswan ppp
cat > xl2tpd.conf <<e
;
; This is a minimal sample xl2tpd configuration file for use
; with L2TP over IPsec.
;
; The idea is to provide an L2TP daemon to which remote Windows L2TP/IPsec
; clients connect. In this example, the internal (protected) network 
; is 192.168.1.0/24.  A special IP range within this network is reserved
; for the remote clients: 192.168.1.128/25
; (i.e. 192.168.1.128 ... 192.168.1.254)
;
; The listen-addr parameter can be used if you want to bind the L2TP daemon
; to a specific IP address instead of to all interfaces. For instance,
; you could bind it to the interface of the internal LAN (e.g. 192.168.1.98
; in the example below). Yet another IP address (local ip, e.g. 192.168.1.99)
; will be used by xl2tpd as its address on pppX interfaces.

[global]
; listen-addr = 192.168.1.98
;
; requires openswan-2.5.18 or higher - Also does not yet work in combination
; with kernel mode l2tp as present in linux 2.6.23+
; ipsec saref = yes
; Use refinfo of 22 if using an SAref kernel patch based on openswan 2.6.35 or
;  when using any of the SAref kernel patches for kernels up to 2.6.35.
; saref refinfo = 30
;
; force userspace = yes
;
; debug tunnel = yes

[lns default]
ip range = ${a}
local ip = ${b}
require chap = yes
refuse pap = yes
require authentication = yes
name = LinuxVPNserver
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
e

cat > options.xl2tpd <<e
ipcp-accept-local
ipcp-accept-remote
ms-dns  8.8.8.8
ms-dns  8.8.4.4
#ms-wins 192.168.1.2
#ms-wins 192.168.1.4
name xl2tpd
#noccp
auth
#crtscts
idle 1800
mtu 1410
mru 1410
nodefaultroute
debug
#lock 
proxyarp
connect-delay 5000
refuse-pap
refuse-mschap
require-mschap-v2
persist 
logfile /var/log/xl2tpd.log
e
cat > ipsec.conf << e
include /etc/ipsec.d/*.conf
config setup
        protostack=netkey
        dumpdir=/var/run/pluto/
        virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:25.0.0.0/8,%v4:100.64.0.0/10,%v6:fd00::/8,%v6:fe80::/10

include /etc/ipsec.d/*.conf
e

cat > l2tp-ipsec.conf << e
conn L2TP-PSK-NAT
        rightsubnet=0.0.0.0/0
        dpddelay=10
        dpdtimeout=20
        dpdaction=clear
        forceencaps=yes
        also=L2TP-PSK-noNAT
conn L2TP-PSK-noNAT
        authby=secret
        pfs=no
        auto=add
        keyingtries=3
        rekey=no
        ikelifetime=8h
        keylife=1h
        type=transport
        left=${c}
        leftprotoport=17/1701
        right=%any
        rightprotoport=17/%any

e

cat > chap-secrets << E
# Secrets for authentication using CHAP
# client        server  secret                  IP addresses
${d} * ${e} *
E

cat > ipsec.secrets << E
include /etc/ipsec.d/*.secrets

${c} %any: PSK "${f}"
E

cat >>  /etc/sysctl.conf << E
net.ipv4.ip_forward = 1

net.ipv4.conf.default.rp_filter = 0

net.ipv4.conf.all.send_redirects = 0

net.ipv4.conf.default.send_redirects = 0

net.ipv4.conf.all.log_martians = 0

net.ipv4.conf.default.log_martians = 0

net.ipv4.conf.default.accept_source_route = 0

net.ipv4.conf.all.accept_redirects = 0

net.ipv4.conf.default.accept_redirects = 0

net.ipv4.icmp_ignore_bogus_error_responses = 1
E
sysctl –p
ipsec verify
cp xl2tpd.conf  /etc/xl2tpd/xl2tpd.conf
cp options.xl2tpd  /etc/ppp/options.xl2tpd
cp ipsec.conf  /etc/ipsec.conf
cp l2tp-ipsec.conf  /etc/ipsec.d/l2tp-ipsec.conf
cp chap-secrets  /etc/ppp/chap-secrets
cp ipsec.secrets  /etc/ipsec.secrets
systemctl restart xl2tpd ipsec

#--------------------------------------------------------------------------------------------
#日志设置
#记录对方IP地址：

#这里可以利用syslog来配置，在/etc/rsyslog.d/ 下新建20-xl2tpd.conf文件，内容如下：

#vi /etc/rsyslog.d/20-xl2tpd.conf

#if $programname == 'xl2tpd' then /var/log/l2tp-***.log

#&~

 

#这里可以利用syslog来配置，在/etc/rsyslog.d/ 下新建20-pptpd.conf文件，内容如下：

#vi /etc/rsyslog.d/20-pptpd.conf

#if $programname == 'pppd' then /var/log/l2tp-***.log

#&~

#systemctl restart rsyslog

#记录用户名和登录时间：
#
#在/etc/ppp/ip-up 脚本中加入
#
#echo >> /var/log/l2tp-***.log
#
#echo "Start_Time: `date -d today +%F_%T`" >> /var/log/l2tp-***.log  ##登录时间戳
#
#echo "username: $PEERNAME" >> /var/log/l2tp-***.log  ##用户名
#
#echo >> /var/log/l2tp-***.log
#
# 
#
#在/etc/ppp/ip-down 脚本中加入
#
#echo "Stop_Time: `date -d today +%F_%T`" >> /var/log/l2tp-***.log  ##断开时间戳
#
#echo "username: $PEERNAME" >> /var/log/l2tp-***.log  ##用户名
#
#echo >> /var/log/l2tp-***.log

#--------------------------------------------------------------------------------------------------

iptables -t nat -A POSTROUTING -o eth1 -s ${g}/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -s ${g}/24 -o eth0 -j MASQUERADE








