#!/bin/bash
target=www.yahoo.com
count=$( ping -c 1 $target | grep icmp* | wc -l )
if [ $count -eq 0 ]
	then
		sudo /etc/init.d/vpnclient restart
fi
exit 0
