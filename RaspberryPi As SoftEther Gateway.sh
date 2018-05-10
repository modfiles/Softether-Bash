#!/bin/bash


########### PART 1 SYSTEM UPDATE AND DEPENDENCIES ###########

echo "Update system"
sudo apt-get update
sudo apt-get upgrade -y

sleep 1
echo "Install dependencies"
sudo apt-get install iptables-persistent ethtool lshw -y

sleep 1



########### Part 2 will be installing SoftEther Client ###########

# SoftEther raspberry client download
wget http://www.softether-download.com/files/softether/v4.25-9656-rtm-2018.01.15-tree/Linux/SoftEther_VPN_Client/32bit_-_ARM_EABI/softether-vpnclient-v4.25-9656-rtm-2018.01.15-linux-arm_eabi-32bit.tar.gz

sleep 1
tar xvzf softether-vpnclient-v4.25-9656-rtm-2018.01.15-linux-arm_eabi-32bit.tar.gz

sleep 1
cd vpnclient
make

sleep 1
cd
sudo mv vpnclient /usr/local/
cd /usr/local/vpnclient

sleep 1
sudo chmod 600 *
sudo chmod 700 vpnclient
sudo chmod 700 vpncmd
#sudo /etc/init.d/vpnclient start

sleep 1
# SoftEther to start as a service on startup
echo '#! /bin/bash
### BEGIN INIT INFO
# Provides: vpnclient
# Required-Start: $all
# Required-Stop: $network $local_fs $remote_fs $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Start VPN Client at boot time
# chkconfig: 345 44 56
# description: Start VPN Client at boot time.
# processname: vpnclient
### END INIT INFO

# /etc/init.d/vpnclient
# IMPORTANT!!! SET YOUR VARIABLES HERE!
ROUTER_IP=xx.xx.xx.xx
SERVER_IP=xx.xx.xx.xx
SERVER_DHCP=xx.xx.xx.xx

case "$1" in

	start)
		/usr/local/vpnclient/vpnclient start
		sleep 8
		route add -host $SERVER_IP gw $ROUTER_IP
		route del default
		route add default gw $SERVER_DHCP dev vpn_vpn
		dhclient -r -v vpn_vpn
		sleep 1
		rm /var/lib/dhcp/dhclient.*
		sleep 1
		dhclient -v vpn_vpn
		sleep 1
		;;

	stop)
		/usr/local/vpnclient/vpnclient stop
		sleep  2
		route del -host $SERVER_IP
		route del default
		route add default gw $ROUTER_IP dev eth0
		sleep 1
		;;

	restart)
		/usr/local/vpnclient/vpnclient stop
		sleep 2
		route del -host $SERVER_IP
		route del default
		route add default gw $ROUTER_IP dev eth0
		sleep 4
		/usr/local/vpnclient/vpnclient start
		sleep 8
		route add -host $SERVER_IP gw $ROUTER_IP
		route del default
		route add default gw $SERVER_DHCP dev vpn_vpn
		dhclient -r -v vpn_vpn
		sleep 1
		rm /var/lib/dhcp/dhclient.*
		sleep 1
		dhclient -v vpn_vpn
		sleep 1
		;;

	*)
		echo "Usage: /etc/init.d/vpnclient {start|stop|restart}"
		exit 1
		;;
esac
exit 0' > /etc/init.d/vpnclient

sleep 1
sudo chmod 755 /etc/init.d/vpnclient
sudo update-rc.d vpnclient defaults


########### PART 3 IPTABLES AND ROUTING ###########

sleep 1
# Enable IP routing
echo net.ipv4.ip_forward = 1 | sudo tee -a /etc/sysctl.conf

# iptables base on http://www.instructables.com/id/Raspberry-Pi-VPN-Gateway/

sleep 1
# Clean ip tables of -t nat
sudo iptables -F -t nat



# IMPORTANT!!! SET YOUR TUN INTERFACE HERE!
# NOTE: Change "vpn_vpn" to what the Softether network interface you set
TUN_INTERFACE=vpn_vpn



sleep 1
# Setup Firewall and NAT
sudo iptables -t nat -A POSTROUTING -o $TUN_INTERFACE -j MASQUERADE

sleep 1
# Enable NAT
sudo iptables -A FORWARD -i eth0 -o $TUN_INTERFACE -j ACCEPT

sleep 1
# Allowing any traffic from eth0 (internal) to go over $TUN_INTERFACE (tunnel)
sudo iptables -A FORWARD -i $TUN_INTERFACE -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

sleep 1
# Allowing traffic from $TUN_INTERFACE (tunnel) to go back over eth0 (internal)
sudo iptables -A INPUT -i lo -j ACCEPT

sleep 1
# Allowing the Raspberry Pi's own loopback traffic
sudo iptables -A INPUT -i eth0 -p icmp -j ACCEPT

sleep 1
# Allowing computers on the local network to ping the Raspberry Pi.
sudo iptables -A INPUT -i eth0 -p tcp -m tcp --dport 22 -j ACCEPT

sleep 1
# Allowing SSH from the internal network.
sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

sleep 1
# Allowing all traffic initiated by the Raspberry Pi to return
sudo iptables -P FORWARD DROP
sudo iptables -P INPUT DROP

sleep 1
# If traffic doesn't match any of the the rules specified it will be dropped.
sudo systemctl enable netfilter-persistent
sudo netfilter-persistent save
#sudo dpkg-reconfigure --default-priority iptables-persistent

sleep 1
# Fix clients logon delay
echo 'UseDNS no' >> /etc/ssh/sshd_config
sudo reboot

# Now you can use this tunnel from any device or computer on the same network.
# Just change the default gateway to whatever IP-address your Raspberry Pi has

# Init config vpnclient
# > sudo /usr/local/vpnclient/vpncmd
#
#Some of the most use command
#Create a virtual network adaptor
#	NicCreate vpn
#
#Upgrade driver for virtual network adaptor if available
#	NicUpgrade vpn
#
#Create account in single command
#	AccountCreate Server1 /SERVER:127.0.0.1:443 /HUB:hobbit /USERNAME:username /NICNAME:vpn
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
#More here
#https://www.softether.org/4-docs/1-manual/6._Command_Line_Management_Utility_Manual/6.5_VPN_Client_Management_Command_Reference#6.5.14_.22NicUpgrade.22:_Upgrade_Virtual_Network_Adapter_Device_Driver

# Clear or reset iptable
# sudo iptables -P INPUT ACCEPT
# sudo iptables -P FORWARD ACCEPT
# sudo iptables -P OUTPUT ACCEPT
# sudo iptables -t nat -F
# sudo iptables -t mangle -F
# sudo iptables -F
# sudo iptables -X
# sudo ip6tables -P INPUT ACCEPT
# sudo ip6tables -P FORWARD ACCEPT
# sudo ip6tables -P OUTPUT ACCEPT
# sudo ip6tables -t nat -F
# sudo ip6tables -t mangle -F
# sudo ip6tables -F
# sudo ip6tables -X
# sudo netfilter-persistent save
# sudo reboot

exit 0
