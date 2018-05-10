#!/bin/bash
echo "Update system"
sudo apt-get update
sudo apt-get upgrade -y

sleep 1
echo "Install dependencies"
sudo apt-get install gcc zlib1g-dev libncurses5-dev build-essential libncurses-dev libreadline-dev libreadline6 libreadline6-dev libssl-dev dnsmasq iptables-persistent -y

sleep 1
echo "Fetch SoftEtherVPN RTM Linux (Ubuntu or Debian) x64 latest source from www.softether-download.com"
wget http://www.softether-download.com/files/softether/v4.25-9656-rtm-2018.01.15-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.25-9656-rtm-2018.01.15-linux-x64-64bit.tar.gz

sleep 1
tar xvzf softether-vpnserver-v4.25-9656-rtm-2018.01.15-linux-x64-64bit.tar.gz

sleep 1
cd vpnserver
echo "Compile SoftEtherVPN"
make

sleep 1
cd
# Move files to /usr/local/
sudo mv vpnserver /usr/local/
cd /usr/local/vpnserver

sleep 1
# Change file permissions/properties
sudo chmod 600 *
sudo chmod 700 vpnserver
sudo chmod 700 vpncmd

sleep 1
# init script which will config tap interface for us when Softether start up.
echo '#!/bin/bash
### BEGIN INIT INFO
# Provides:          vpnserver
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable Softether by daemon.
### END INIT INFO

#/etc/init.d/vpnserver 

DAEMON=/usr/local/vpnserver/vpnserver
LOCK=/var/lock/subsys/vpnserver
TAP_ADDR=192.168.30.1

test -x $DAEMON || exit 0
case "$1" in
	start)
		$DAEMON start
		touch $LOCK
		sleep 1
		/sbin/ifconfig tap_soft $TAP_ADDR
		;;
	stop)
		$DAEMON stop
		rm $LOCK
		;;
	restart)
		$DAEMON stop
		sleep 3
		$DAEMON start
		sleep 1
		/sbin/ifconfig tap_soft $TAP_ADDR
		;;
	*)
	echo "Usage: $0 {start|stop|restart}"
	exit 1
esac
exit 0' > /etc/init.d/vpnserver

sleep 1
echo "System daemon created. Registering changes..."
sudo chmod 755 /etc/init.d/vpnserver
sudo update-rc.d vpnserver defaults
sudo mkdir /var/lock/subsys

sleep 1
# Enable IP routing
echo net.ipv4.ip_forward = 1 | sudo tee -a /etc/sysctl.conf

sleep 1
echo 1 > /proc/sys/net/ipv4/ip_forward
sudo sysctl --system

# SoftEther with Bridge with Tap device
# Take note that we need to create first a tap device named "soft" using SoftEther SE-VPN Server Manager (Tools) so our virtual network adaptor is "tap_soft"
sleep 1
echo "interface=tap_soft
dhcp-range=tap_soft,192.168.30.50,192.168.30.60,12h
dhcp-option=tap_soft,3,192.168.30.1" >> /etc/dnsmasq.conf

sleep 1
# Clean ip tables of -t nat
sudo iptables -F -t nat

sleep 1
# Add a POSTROUTING rule to iptables
sudo iptables -t nat -A POSTROUTING -s 192.168.30.0/24 -o eth0 -j MASQUERADE

sleep 1
# Make our iptables rule survive after reboot
sudo systemctl enable netfilter-persistent
sudo netfilter-persistent save

sleep 1
echo "SoftEther VPN Server should now start as a system service from now on. Starting SoftEther VPN service..."
sudo /etc/init.d/vpnserver start
sudo /etc/init.d/dnsmasq restart

# Init config vpnserver
# > cd /usr/local/vpnserver
# > ./vpncmd
# > ServerPasswordSet yourPassword
# Then use SoftEther VPN Server Manager to manage your server
#
#Some of the most use command
#Create a virtual network adaptor
#	NicCreate vpn
#
#Upgrade driver for virtual network adaptor if available
#	NicUpgrade vpn
#
#Create account in single command
#	AccountCreate Server1 /SERVER:127.0.0.1:5555 /HUB:hobbit /USERNAME:username /NICNAME:vpn
#
#I usually get an anonymous account so i usually use this command
#	AccountAnonymousSet Server1
#
#Set Password
#	AccountPasswordSet Server1 /PASSWORD:password /TYPE:standard
#	
#	AccountEncryptEnable Server1
#
#	AccountDetailSet Server1 /MAXTCP:32 /INTERVAL:1 [/TTL:disconnect_span] /HALF:yes /BRIDGE:no /MONITOR:no /NOTRACK:yes /NOQOS:yes
#
#	AccountConnect Server1
#	AccountDisconnect Server1
#
#	AccountStatusGet Server1
#
#	AccountStatusHide Server1
#
#	AccountStartupSet Server1
#	AccountStartupRemove Server1
#
#	RemoteDisable
#	KeepEnable
#	KeepSet /HOST:google.com:80 /PROTOCOL:tcp /INTERVAL:5
#
#	VpnOverIcmpDnsEnable /ICMP:yes /DNS:yes
#
#More here
#https://www.softether.org/4-docs/1-manual/6._Command_Line_Management_Utility_Manual/6.5_VPN_Client_Management_Command_Reference#6.5.14_.22NicUpgrade.22:_Upgrade_Virtual_Network_Adapter_Device_Driver

exit 0