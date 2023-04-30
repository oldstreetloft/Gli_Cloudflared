#!/bin/bash

# Define variables.
init_vars() {
    author='cloudflare'
    repo='cloudflared'
}

# Define command-line arguments or prompt user for ip and token
parse_args() {
    if [[ $1 ]] ; then
        ip_addr=$1
    else
        echo ; read -p "Enter IP address: " ip_addr
    fi
    if [[ $2 ]] ; then
        token=$2
    else
        echo ; read -p "Enter CFD Token: " token
    fi
}

# Query GH API for latest version number and download URL.
parse_github() {
    local api_url="https://api.github.com/repos/$author/$repo/releases/latest"
    latest=$(curl -sL $api_url | grep tag_name | awk -F \" '{print $4}')
    down_url="https://github.com/$author/$repo/releases/download/$latest/cloudflared-linux-arm"
}

# Check to see if both device and GH are reachable.
test_conn() {
    if ping -c 1 $ip_addr &> /dev/null ; then
        printf "\nProvided IP Address: $ip_addr\n\nDevice is reachable.\n\n"
    else
        printf "\nERROR:\nNo route to device!\n"
        printf "Please ensure connectivity to device and try again.\n\n" ; exit 0
    fi
    if [[ $latest ]]; then
        printf "You are connected to the internet.\n\n"
        printf "Latest cloudflared version: $latest\n\n"
        printf "Latest GH download URL: \n$down_url\n\n"
    else
        printf "\nERROR:\nYou are not connected to the internet.\n"
        printf "Please ensure internet connectivity and try again.\n\n" ; exit 0
    fi
}

#####################
# Begin SSH session #
#####################
# Commands sent over SSH stdin as a heredoc.
ssh_install() {
ssh root@$ip_addr << ENDSSH

# Download and install client binary.
printf "Downloading cloudflared package"
if curl -L $down_url -o cloudflared ; then
    chmod +x cloudflared ; mv cloudflared /usr/bin/cloudflared
else
    printf "\nERROR:\nDevice is NOT connected to the internet.\n"
    printf "Please ensure connectivity and try again.\n\n" ; exit 0
fi

#####################
# Begin init config #
#####################
cat > /etc/init.d/cloudflared << EOF
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=95
STOP=01

cfd_init="/etc/init.d/cloudflared"
cfd_token="$token"

boot() {
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
EOF ; chmod +x /etc/init.d/cloudflared
###################
# END init config #
###################

# Enable, start, and report status of service.
/etc/init.d/cloudflared enable ; /etc/init.d/cloudflared start
printf '\nCloudflared is ' ; /etc/init.d/cloudflared status

# Verifying that cloudflare is generating log data.
sleep 5
if logread | grep cloudflared &> /dev/null; then
    printf '\nSUCCESS: INSTALL COMPLETED.\n\n'
    printf 'Set split tunnel in Cloudflare Zero Trust portal under Settings -> Warp App.\n\n'
else
    printf '\nERROR: INSTALL FAILED!\n\n' ; exit 0
fi
ENDSSH
}
###################
# End SSH session #
###################

# Main.
init_vars
parse_args $1 $2
parse_github
test_conn
ssh_install