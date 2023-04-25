#!/bin/bash

echo
echo 'Warning: Please ensure that you are running the latest firmware'
echo
read -p "Enter the IP address: " ip_address
ssh root@$ip_address << ENDSSH
cd /tmp
wget https://github.com/srlabs/blue-merle/releases/download/v1.0/blue-merle_1.0.0-1_mips_24kc.ipk -O blue-merle.ipk
opkg update
opkg install blue-merle.ipk
reboot
ENDSSH
echo 'Device will now reboot, please ensure that the switch is in the down position (away from recessed dot)'