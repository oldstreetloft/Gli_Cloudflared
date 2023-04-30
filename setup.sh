#!/bin/bash

# Query user for info and GH API for latest version number.
init_vars() {
    read -p "Enter IP address: " ip_address
    read -p "Enter CFD Token: " token
    local api_url='https://api.github.com/repos/cloudflare/cloudflared/releases/latest'
    latest=$(curl -sL $api_url | grep tag_name | awk -F \" '{print $4}')
}

# Check to see if both device and 1.1.1.1 are reachable.
conn_test() {
    if ping -c 1 $ip_address &> /dev/null
        then
            printf "\nDevice is reachable."
            printf "\nProvided IP Address: "
            echo $ip_address
        else
            echo "No route to device!"
            echo "Please ensure connectivity to device and try again."
            exit 0
    fi
    if ping -c 1 1.1.1.1 &> /dev/null
        then
            echo "You are connected to the internet."
            printf '\nGH Download URL: \n'
            echo $down_url
        else
            echo "You are not connected to the internet."
            echo "Please ensure internet connectivity and try again."
            exit 0
    fi
}

# Initialization.
init_vars
conn_test

# Begin SSH connection.
ssh root@$ip_address << ENDSSH

# Check for connection to the internet.
if ping -c 1 1.1.1.1 &> /dev/null
    then
        echo "Device is connected to the internet."
    else
        echo "Device is not connected to the internet."
        exit 0
fi

# Download client binary.
curl -O -L https://github.com/cloudflare/cloudflared/releases/download/$latest/cloudflared-linux-arm
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
chmod +x /etc/init.d/cloudflared

# Start and enable cloudflared service.
/etc/init.d/cloudflared enable
/etc/init.d/cloudflared start

# Check if cloudflared is running and indicate status to user.
printf '\nCloudflared is '
/etc/init.d/cloudflared status

# Verifying that cloudflare is generating log data.
sleep 5
if logread | grep cloudflared &> /dev/null
    then
        printf '\nSUCCESS: INSTALL COMPLETED.\n'
        printf '\nSet split tunnel in Cloudflare Zero Trust portal under Settings -> Warp App.\n\n'
    else
        printf '\nERROR: INSTALL FAILED!\n\n'
fi
ENDSSH