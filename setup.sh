#!/bin/bash

prompt_user() {
    read -p "Enter IP address: " ip_address
    read -p "Enter CFD Token: " token
}

# Initiate SSH Connection

prompt_user
ssh root@$ip_address << ENDSSH

# Download client binary.

curl -O -L https://github.com/cloudflare/cloudflared/releases/download/2023.4.2/cloudflared-linux-arm
chmod +x cloudflared-linux-arm
mv cloudflared-linux-arm /usr/bin/cloudflared

# Generate init config.

cat > /etc/init.d/cloudflared << EOF
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=95
STOP=01

cfd_init="/etc/init.d/cloudflared"
cfd_token="$token"

boot()
{
    ubus -t 30 wait_for network.interface network.loopback 2>/dev/null
    rc_procd start_service
}

start_service() {
    if [ \\\$("\\\${cfd_init}" enabled; printf "%u" \\\${?}) -eq 0 ]
    then
        procd_open_instance
        procd_set_param command /usr/bin/cloudflared --no-autoupdate tunnel run --token \\\${cfd_token}
        procd_set_param stdout 1
        procd_set_param stderr 1
        procd_set_param respawn \\\${respawn_threshold:-3600} \\\${respawn_timeout:-5} \\\${respawn_retry:-5}
        procd_close_instance
    fi
}

stop_service() {
    pidof cloudflared && kill -SIGINT \\\`pidof cloudflared\\\`
}
EOF

# Start cloudflared.

chmod +x /etc/init.d/cloudflared
/etc/init.d/cloudflared enable
/etc/init.d/cloudflared start

# Check if cloudflared is running and indicate status to user.

printf '\ncloudflared is '
/etc/init.d/cloudflared status
sleep 5
if logread | grep cloudflared > /dev/null
then
    printf '\nSUCCESS: INSTALL COMPLETED.\n'
    printf '\nSet split tunnel in Cloudflare Zero Trust portal under Settings -> Warp App.\n\n'
else
    printf '\nERROR: INSTALL FAILED!\n\n'
fi
ENDSSH