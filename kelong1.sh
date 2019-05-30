#!/bin/bash
echo "
[dvd]
name=dvd
baseurl=ftp://192.168.4.254/rhel7
enabled=1
gpgcheck=0" > /root/dvd.repo
echo "
[dvd]
name=dvd
baseurl=ftp://192.168.2.254/rhel7
enabled=1
gpgcheck=0" > /root/dvd1.repo
read -p "你要克隆多少台虚拟机(1-9): " t
for p in `seq $t`
do
read -p "hostname: " h
read -p "ip4: " ip4
read -p "ip2: "	ip2
rm -rf /root/r$p.txt
rm -rf /root/a$p.txt
rm -rf /root/b$p.txt
echo $h   >>    /root/r$p.txt
echo $ip4 >>  /root/a$p.txt
echo $ip2 >>  /root/b$p.txt
done
for b in `seq $t`
do
h=`cat  /root/r$b.txt`
ip4=`cat /root/a$b.txt`
ip2=`cat /root/b$b.txt`
cat /root/a$b.txt
virsh destroy $h	&>/dev/null
virsh undefine $h       &>/dev/null
rm -rf rh7_template.img /var/lib/libvirt/images/$h.img
qemu-img create -f qcow2 -b /var/lib/libvirt/images/.rh7_template.img /var/lib/libvirt/images/$h.img	&>/dev/null
cat /var/lib/libvirt/images/.rhel7.xml > /tmp/myvm.xml
sed -i "/<name>rh7_template/s/rh7_template/$h/" /tmp/myvm.xml
sed -i "/rh7_template\.img/s/rh7_template/$h/" /tmp/myvm.xml
virsh define /tmp/myvm.xml  &>/dev/null
sleep 7
virsh start $h
echo "#######################################################"
if [ ! -z $ip4 ] &&  [ -z $ip2 ];then
expect <<EOF
spawn  virsh console $h
expect "^]"	{send	"\r"}
expect "login:"	{send	"root\r"}
expect "密码："	{send	"123456\r"}
expect "#"	{send	"hostnamectl set-hostname $h\r"}
expect "#"      {send   "nmcli connection modify eth0 ipv4.method manual ipv4.addresses $ip4/24 connection.autoconnect yes\r"}
expect "#"      {send   "nmcli connection up eth0\r"}
expect "#"	{send 	"\035"}
expect eof
EOF
fi

if [ ! -z $ip4 ] && [ -z $ip2 ];then
expect <<eo
spawn ssh-copy-id $ip4
expect "(yes/no)? "	{send	"yes\r"}
expect "password:"	{send	"123456\r"} 
expect eof
eo
scp -r /root/dvd.repo $ip4:/etc/yum.repos.d/
scp -r /root/lnmp_soft.tar.gz $ip4:/root
scp -r /root/mysql.tar.gz $ip4:/root
expect <<eo
set timeout -1
spawn ssh $ip4
expect "#"		{send	"cd /root\r"}
expect "#"		{send 	"tar -xf mysql.tar.gz\r"}
expect "#"		{send 	"cd mysql/08.dba1\r"}
expect "#"		{send 	"yum -y install expect\r"}
expect "08.dba1]#"	{send	"tar -xf mysql-5.7.17.tar\r"}
expect "08.dba1]#"	{send	"yum -y install   *.rpm\r"}
expect "08.dba1]#"	{send 	"systemctl restart mysqld\r"}
expect "08.dba1]#"	{send	"cp -p /root/mysql/automysql /usr/bin/\r"}
expect "08.dba1]#"	{send 	"automysql\r"}
expect "08.dba1]#"	{send 	"exit\r"}
expect eof
eo

fi
if [ ! -z $ip2 ] && [ ! -z $ip4 ];then
expect <<EOF
spawn  virsh console $h
expect "^]"     {send   "\r"}
expect "login:"  {send   "root\r"}
expect "密码：" {send   "123456\r"}
expect "#"      {send   "hostnamectl set-hostname $h\r"}
expect "#"	{send	"nmcli connection add ifname eth1 con-name eth1 type ethernet\r"}
expect "#"      {send   "nmcli connection modify eth0 ipv4.method manual ipv4.addresses $ip4/24 connection.autoconnect yes\r"}
expect "#"      {send   "nmcli connection modify eth1 ipv4.method manual ipv4.addresses $ip2/24 connection.autoconnect yes\r"}
expect "#"      {send   "nmcli connection up eth0\r"}
expect "#"      {send   "nmcli connection up eth1\r"}
expect "#"	{send	"\035"}
expect eof
EOF
fi
if [ ! -z $ip4 ] && [ ! -z $ip2 ];then
expect <<EOF
spawn ssh-copy-id $ip4
expect "(yes/no)? "     {send   "yes\r"}
expect "password:"      {send   "123456\r"} 
expect eof
EOF
scp -r /root/dvd.repo $ip4:/etc/yum.repos.d/
scp -r /root/lnmp_soft.tar.gz $ip4:/root
scp -r /root/mysql.tar.gz $ip4:/root
expect <<eo
set timeout -1
spawn ssh $ip4
expect "#"		{send	"cd /root\r"}
expect "#"		{send 	"tar -xf mysql.tar.gz\r"}
expect "#"		{send 	"cd mysql/08.dba1\r"}
expect "#"		{send 	"yum -y install expect\r"}
expect "08.dba1]#"	{send	"tar -xf mysql-5.7.17.tar\r"}
expect "08.dba1]#"	{send	"yum -y install   *.rpm\r"}
expect "08.dba1]#"	{send 	"systemctl restart mysqld\r"}
expect "08.dba1]#"	{send	"cp -p /root/mysql/automysql /usr/bin/\r"}
expect "08.dba1]#"	{send 	"automysql\r"}
expect "08.dba1]#"	{send 	"exit\r"}
expect eof
eo

fi
if [  -z $ip4 ] &&  [ ! -z $ip2 ];then
expect <<EOF
spawn  virsh console $h
expect "^]"     {send   "\r"}
expect "login:"  {send   "root\r"}
expect "密码：" {send   "123456\r"}
expect "#"      {send   "hostnamectl set-hostname $h\r"}
expect "#"      {send   "nmcli connection add ifname eth1 con-name eth1 type ethernet\r"}
expect "#"      {send   "nmcli connection modify eth1 ipv4.method manual ipv4.addresses $ip2/24 connection.autoconnect yes\r"}
expect "#"      {send   "nmcli connection up eth1\r"}
expect "#"      {send   "\035"}
expect eof
EOF
fi
if [   -z $ip4 ] &&  [ ! -z $ip2 ];then
expect <<EOF
spawn ssh-copy-id $ip2
expect "(yes/no)? "     {send   "yes\r"}
expect "password:"      {send   "123456\r"} 
expect eof
EOF
scp -r /root/dvd1.repo $ip2:/etc/yum.repos.d/
scp -r /root/lnmp_soft.tar.gz $ip2:/root
scp -r /root/mysql.tar.gz $ip2:/root
expect <<eo
set timeout -1
spawn ssh $ip2
expect "#"		{send	"cd /root\r"}
expect "#"		{send 	"tar -xf mysql.tar.gz\r"}
expect "#"		{send 	"cd mysql/08.dba1\r"}
expect "#"		{send 	"yum -y install expect\r"}
expect "08.dba1]#"	{send	"tar -xf mysql-5.7.17.tar\r"}
expect "08.dba1]#"	{send	"yum -y install   *.rpm\r"}
expect "08.dba1]#"	{send 	"systemctl restart mysqld\r"}
expect "08.dba1]#"	{send	"cp -p /root/mysql/automysql /usr/bin/\r"}
expect "08.dba1]#"	{send 	"automysql\r"}
expect "08.dba1]#"	{send 	"exit\r"}
expect eof
eo
fi
done
echo "#################################################"
rm  /root/r`seq $t`.txt
rm  /root/a`seq $t`.txt
rm  /root/b`seq $t`.txt
