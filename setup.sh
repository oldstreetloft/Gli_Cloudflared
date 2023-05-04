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
    if [[ $1 ]] ; then ip_addr=$1 ; fi
    get_ip
    if [[ $2 ]] ; then token=$2 ; fi
    get_token
}

# Read and validate IP address.
get_ip() {
    local ip_format="^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
    if [[ ! $ip_addr =~ $ip_format ]] ; then
        while true; do
            echo ; read -p "Enter IP address: " ip_addr
            if [[ $ip_addr =~ $ip_format ]] ; then
                break
            else
                printf "\nERROR: Invalid IP address format.\nPlease enter a valid IP address.\n"
            fi
        done
    fi
}

# Read and validate CFD token.
get_token() {
    local token_format="^[a-zA-Z0-9]+$"
    if [[ ! $token =~ $token_format ]] ; then
        while true; do
            echo ; read -p "Enter CFD Token: " token
            if [[ $token =~ $token_format ]] ; then
                break
            else
                printf "\nERROR: Invalid CFD token format.\nPlease enter a valid CFD token.\n"
            fi
        done
    fi
}


# Check to see if device and Github are responding.
test_conn() {
    if nc -z -w1 $ip_addr 22 &> /dev/null ; then
        printf "\nProvided IP Address: $ip_addr\n\nDevice is responding.\n\n"
    else
        printf "\nERROR: No route to device!\n"
        printf "Please ensure connectivity to device and try again.\n\n" ; exit 1
    fi
    if ping -c 1 github.com &> /dev/null ; then
        printf "You are connected to the internet.\n\n"
    else
        printf "\nERROR: You are not connected to the internet.\n"
        printf "Please ensure internet connectivity and try again.\n\n" ; exit 1
    fi
}

# Query GH API for latest version number and download URL.
parse_github() {
    local auth_repo='cloudflare/cloudflared'
    local api_url="https://api.github.com/repos/$auth_repo/releases/latest"
    local latest=$(curl -sL $api_url | grep tag_name | awk -F \" '{print $4}') &> /dev/null
    down_url="https://github.com/$auth_repo/releases/download/$latest/cloudflared-linux-arm"
    if [ -z "$latest" ]; then
        printf "ERROR: Unable to retrieve latest download URL from GitHub API.\n"
        printf "\nUsing default download URL.\n"
        down_url="https://github.com/cloudflare/cloudflared/releases/download/2023.5.0/cloudflared-linux-arm"
    else
    printf "Latest cloudflared version: $latest\n\nLatest GH download URL: \n$down_url\n\n"
    fi
}

# Detect the OS of the host, install dependencies.
detect_os() {
    local target=$(uname -o)
    if [ "$target" = "Android" ] ; then
        printf "Host OS: $target\n\nInstalling: openssh\n\n"
        pkg update ; pkg install openssh ; echo
    else
        printf "Host OS: $target\n\n"
    fi
}

# Commands sent over SSH stdin as a heredoc.
ssh_install() {
#==================== Start SSH connection ====================
ssh root@$ip_addr << ENDSSH

# Download and install client binary.
printf "\nDownloading cloudflared package.\n"
if curl -L $down_url -o cloudflared ; then
    chmod +x cloudflared ; mv cloudflared /usr/bin/cloudflared ; printf "\nPackage installed.\n"
else
    printf "\nERROR: Device is NOT connected to the internet.\n"
    printf "Please ensure internet connectivity and try again.\n\n" ; exit 1
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
#==================== End init config ====================
chmod +x /etc/init.d/cloudflared

# Enable, start, and report status of service.
/etc/init.d/cloudflared enable ; /etc/init.d/cloudflared start
printf '\nCloudflared is ' ; /etc/init.d/cloudflared status

# Verify that cloudflare is generating log data.
sleep 5
if logread | grep cloudflared &> /dev/null; then
    printf '\nSUCCESS: INSTALL COMPLETED.\n\n'
    printf 'Set split tunnel in Cloudflare Zero Trust portal under Settings -> Warp App.\n\n'
else
    printf '\nERROR: INSTALL FAILED!\n\n' ; exit 1
fi
ENDSSH
#==================== End SSH connection ====================
}

#==================== Start execution ====================
main $1 $2