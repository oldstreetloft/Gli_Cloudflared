#!/bin/bash

#==================== Main function ====================
main() {
    parse_args $1 $2        # Get data from user.
    test_conn               # Exit if no connection.
    parse_github            # Query GH for latest download URL.
    detect_os               # Install dependencies.
    ssh_install             # Install script.
}

#==================== Define functions ====================
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

# Check to see if device and 1.1.1.1 are responding.
test_conn() {
    if ping -c 1 $ip_addr &> /dev/null ; then
        printf "\nProvided IP Address: $ip_addr\n\nDevice is responding.\n\n"
    else
        printf "\nERROR: No route to device!\n"
        printf "Please ensure connectivity to device and try again.\n\n" ; exit 0
    fi
    if ping -c 1 1.1.1.1 &> /dev/null ; then
        printf "You are connected to the internet.\n\n"
    else
        printf "\nERROR: You are not connected to the internet.\n"
        printf "Please ensure internet connectivity and try again.\n\n" ; exit 0
    fi
}

# Query GH API for latest version number and download URL.
parse_github() {
    local auth_repo='cloudflare/cloudflared'
    local api_url="https://api.github.com/repos/$auth_repo/releases/latest"
    local latest=$(curl -sL $api_url | grep tag_name | awk -F \" '{print $4}') &> /dev/null
    down_url="https://github.com/$auth_repo/releases/download/$latest/cloudflared-linux-arm"
    printf "Latest cloudflared version: $latest\n\nLatest GH download URL: \n$down_url\n\n"
}

# Detect the OS of the host, install dependencies.
detect_os() {
    local target=$(uname -o)
    if [ "$target" = "Android" ] ; then
        printf "Host OS: $target\n\nInstalling: openssh\n\n" ; 
        pkg update ; pkg install openssh ; echo
    else
        printf "Host OS: $target\n\n"
    fi
}

#==================== Start SSH connection ====================
# Commands sent over SSH stdin as a heredoc.
ssh_install() {
ssh root@$ip_addr << ENDSSH

# Download and install client binary.
printf "\nDownloading cloudflared package.\n"
if curl -L $down_url -o cloudflared ; then
    chmod +x cloudflared ; mv cloudflared /usr/bin/cloudflared ; printf "\nPackage installed.\n"
else
    printf "\nERROR: Device is NOT connected to the internet.\n"
    printf "Please ensure internet connectivity and try again.\n\n" ; exit 0
fi

#==================== Start init config ====================
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
EOF
chmod +x /etc/init.d/cloudflared
#==================== End init config ====================

# Enable, start, and report status of service.
/etc/init.d/cloudflared enable ; /etc/init.d/cloudflared start
printf '\nCloudflared is ' ; /etc/init.d/cloudflared status

# Verify that cloudflare is generating log data.
sleep 5
if logread | grep cloudflared &> /dev/null; then
    printf '\nSUCCESS: INSTALL COMPLETED.\n\n'
    printf 'Set split tunnel in Cloudflare Zero Trust portal under Settings -> Warp App.\n\n'
else
    printf '\nERROR: INSTALL FAILED!\n\n' ; exit 0
fi
ENDSSH
}

#==================== Start execution ====================
main $1 $2