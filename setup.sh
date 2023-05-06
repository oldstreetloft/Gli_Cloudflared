#!/bin/bash

#==================== Main function ====================
main() {
    parse_args $1 $2        # Get data from user.
    test_conn               # Exit if no connection.
    parse_github            # Query GH for download URL.
    detect_os               # Install dependencies.
    ssh_install             # Install script.
}

#==================== Define functions ====================
# Define command-line arguments, prompt user for ip and token, validate inputs.
parse_args() {
    # IP address
    if [[ $1 ]] ; then ip_addr=$1 ; fi
    get_ip
    # CFD token
    if [[ $2 ]] ; then token=$2 ; fi
    get_token
}

# Read and validate IP Address.
get_ip() {
    local valid_ip="^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
    while true; do
        if [[ ! $ip_addr =~ $valid_ip ]] ; then
            printf "\nPlease enter a valid IP address.\n\n"
            read -p "Enter IP address: " ip_addr
        else
            break
        fi
    done
}

# Read and validate CFD token.
get_token() {
    local valid_token="^[a-zA-Z0-9]+$"
    while true; do
        if [[ ! $token =~ $valid_token ]] ; then
            printf "\nPlease enter a valid CFD token.\n\n"
            read -p "Enter CFD Token: " token
        else
            break
        fi
    done
}


# Check to see if device and Github are responding.
test_conn() {
    # Check for response with ping.
    if ! ping -c 1 $ip_addr &> /dev/null ; then
        printf "\nERROR: No route to device!\nAre you behind a VPN or connected to the wrong network?\n"
        printf "Please ensure connectivity to device and try again.\n\n" ; exit 1
    fi
    # Check for internet connectivity with ping.
    if ! ping -c 1 github.com &> /dev/null ; then
        printf "\nERROR: You are NOT connected to the internet.\n"
        printf "Please ensure internet connectivity and try again.\n\n" ; exit 1
    fi
}

# Query GH API for latest version number and download URL.
parse_github() {
    local auth='cloudflare'
    local repo='cloudflared'
    local api_url="https://api.github.com/repos/$auth/$repo/releases/latest"
    local latest=$(curl -sL $api_url | grep tag_name | awk -F \" '{print $4}') &> /dev/null
    down_url="https://github.com/$auth/$repo/releases/download/$latest/cloudflared-linux-arm"
    if [ -z "$latest" ] ; then
        # Using fallback URL.
        printf "\nERROR: Unable to retrieve latest download URL from GitHub API.\n\n"
        printf "Using default download URL.\n\n"
        down_url="https://github.com/cloudflare/cloudflared/releases/download/2023.5.0/cloudflared-linux-arm"
    fi
}

# Detect the OS of the host, install dependencies.
detect_os() {
    local host=$(uname -o)
    # Android dependencies.
    if [ "$host" = "Android" ] ; then
        if ! command -v pkg &> /dev/null ; then
            printf "\nERROR: This script must be run in Termux.\n\n" ; exit 1 ; fi
        if ! command -v ssh &> /dev/null ; then
            pkg update &> /dev/null
            pkg install openssh &> /dev/null
        fi
    fi
}

# Commands sent over SSH STDIN as a heredoc.
ssh_install() {
#==================== Start SSH connection ====================
ssh root@$ip_addr -oStrictHostKeyChecking=no -oHostKeyAlgorithms=+ssh-rsa 2> /dev/null <<- ENDSSH

printf "\nDownloading cloudflared.\n\n"
if ! curl -L $down_url -o cloudflared ; then
    printf "ERROR: Download failed.\n"
    printf "Please ensure internet connectivity and try again.\n\n" ; exit 1
fi

printf "Installing cloudflared.\n\n"
chmod +x cloudflared ; mv cloudflared /usr/bin/cloudflared
printf "Package installed.\n\n"

printf "Writing init config.\n\n"
#==================== Start init config ====================
cat > /etc/init.d/cloudflared <<- EOF
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
#==================== End init config ====================
chmod +x /etc/init.d/cloudflared

printf "Starting and enabling service.\n\n"
/etc/init.d/cloudflared enable
/etc/init.d/cloudflared start

printf "Verifying that service is running.\n\n"
sleep 5
if ! logread | grep cloudflared 1> /dev/null; then
    printf "ERROR: INSTALL FAILED!\n\n" ; exit 1
fi
printf "SUCCESS: INSTALL COMPLETED.\n\n"
printf "Set split tunnel in Cloudflare Zero Trust portal under Settings -> Warp App.\n\n"
ENDSSH
#==================== End SSH connection ====================
}

#==================== Start execution ====================
main $1 $2