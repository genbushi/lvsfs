#!/bin/sh

url='http://your.domain.com/'
download='wget'

apt-get -y install conntrack dstat ethtool minicom ntp rsync minicom ethtool vlan snmpd ntpdate nmap tcpdump fping tcptraceroute keepalived
wait

mkdir /etc/keepalived/backup
mkdir /etc/keepalived/conf.d

$download $url/lvs/keepalived.conf -O /etc/keepalived/keepalived.conf
$download $url/lvs/vipXX -O /etc/keepalived/conf.d/vipXX
$download $url/lvs/iptables -O /etc/network/iptables
$download $url/lvs/ip6tables -O /etc/network/ip6tables 
$download $url/lvs/99-lvsfs.conf -O /etc/sysctl.d/99-lvsfs.conf
touch /etc/keepalived/backup/iptables.save.12hr
touch /etc/keepalived/backup/iptables.save.24hr
chmod +x /etc/network/iptables 

mv /etc/motd /etc/motd.orig

echo "post-up /sbin/ethtool -K eth0 rx off tx off sg off gso off" >> /etc/network/interfaces
echo "post-up /sbin/ethtool -K eth1 rx off tx off sg off gso off" >> /etc/network/interfaces
echo "post-up /etc/network/iptables" >> /etc/network/interfaces
echo "post-up ip6tables-restore < /etc/network/ip6tables" >> /etc/network/interfaces

cat << EOF >> /var/spool/cron/crontabs/root
#Time synchronization
45 2 * * * /usr/sbin/ntpdate -s time.google.com 
# Run Updates Daily. Disable if you do not want automatic updates.
35 1 * * * /usr/bin/apt-get -y update && /usr/bin/apt-get -y dist-upgrade >/dev/null 2>&1
# Saving off of ipTables Files.
0 12 * * * /sbin/iptables-save > /etc/keepalived/backup/iptables.save.12hr
59 23 * * * /sbin/iptables-save > /etc/keepalived/backup/iptables.save.24hr
EOF

cat << EOF >> /etc/motd
#######################################################################

Files to edit: 

/etc/network/iptables			    (IPtables Shell Script)
/etc/keepalived/keepalived.conf		(Main keepalived Setup)
/etc/keepalived/conf.d/vipXX		(Individual VIP Pools)

Reload Firewall:
sh /etc/network/iptables

Reload keepalived:
/etc/init.d/keepalived reload

NOTE: ipTables Rules:
- Be sure changes are kept in 'iptables' for reboot persistence.
- Backups from iptables-save happen once or twice a day to '/etc/keepalived/backup'.
- Not a bad idea to do an 'iptables-save > iptables.save.date' before changes.

NOTE: If this is a redundant MASTER/SLAVE setup, to sync:
- Setup cron to sync 'iptables' & 'conf.d/' once per day to SLAVE (setup on deploy).
- Manually make changes to main 'keepalived.conf' file on each LVS server if VIPs were modified/added, etc.

Commands to show Firewall Rules, NAT Tables, IPs bound, LB Pools, etc:
iptables -nvL
iptables -t nat -nvL
ip addr show
ipvsadm -l

#######################################################################
EOF

/sbin/sysctl -p
service procps start

wait

echo "Base genric files are now in place."
echo "Modify '/etc/network/iptables' and '/etc/keepalived/keepalived.conf' as needed."
echo "NOTE: If this is a 'Parallel LVS Topology behind a Cisco for example, put 10.0.0.1 on LVS and use 10.0.0.2 as Cisco LAN"
echo "Check '/etc/sysctl.d/99-lvsfs.conf' for proper settings."
echo "Good idea to reboot."
unlink $0
