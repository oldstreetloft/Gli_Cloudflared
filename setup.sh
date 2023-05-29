#!/bin/bash

#======================================== Main function ========================================
# Main function executed from EOF.
main() {
    auth="cloudflare"
    repo="cloudflared"
    alt_url="https://github.com/$auth/$repo/releases/download/2023.5.0/cloudflared-linux-arm"
    ssh_arg="-oStrictHostKeyChecking=no -oHostKeyAlgorithms=+ssh-rsa"

    parse_arg "$@"                      # Get data from user.
    test_conn                           # Exit if no connection.
    parse_github                        # Query GH for download URL.
    detect_os                           # Install dependencies.
    ssh_install                         # Install script.
}

#======================================== Define functions ========================================
# If no/invalid argument, prompt user.
parse_arg() {
    is_valid_ip $1 && ip_addr=$1 || ip_addr=""
    while ! is_valid_ip $ip_addr ; do
        read -p "Enter IP address: " ip_addr ; done

    is_valid_token $2 && token=$2 || token=""
    while ! is_valid_token $token ; do
        read -p "Enter CFD Token: " token ; done
}

# Validate IP address
is_valid_ip() {
    valid_ip="^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
    echo "$1" | grep -Eq "$valid_ip" && return 0 || return 1
}

# Validate token
is_valid_token() {
    valid_token="^[a-zA-Z0-9]+$"
    echo "$1" | grep -Eq "$valid_token" && return 0 || return 1
}

# Check if device and GH respond.
test_conn() {
    ! ping -c 1 "$ip_addr" 1> /dev/null && printf "\nERROR: No route to device!\n\n" && exit 1
    ! ping -c 1 github.com 1> /dev/null && printf "\nERROR: No internet connection.\n\n" && exit 1
}

# Query GH API for latest version and URL.
parse_github() {
    api_url="https://api.github.com/repos/$auth/$repo/releases/latest"
    latest=$(curl -sL $api_url | grep tag_name | awk -F \" '{print $4}')
    down_url="https://github.com/$auth/$repo/releases/download/$latest/cloudflared-linux-arm"
    [ -z "$latest" ] && down_url=$alt_url && printf "\nUsing fallback URL.\n\n"
}

# Detect host OS. Install dependencies.
detect_os() {
    host=$(uname -o)
    case "$host" in
        "Android")
            ! command -v pkg 1> /dev/null && printf "\nERROR: Termux required.\n\n" && exit 1
            ! command -v ssh 1> /dev/null && pkg update && pkg install openssh ;; esac
}

# Commands sent over SSH STDIN via heredoc.
ssh_install() {
#======================================== Start SSH connection ========================================
ssh root@$ip_addr $ssh_arg 2> /dev/null <<- ENDSSH

printf "\nDownloading cloudflared.\n\n"
! curl -sL $down_url -o cloudflared && printf "ERROR: Download failed.\n\n" && exit 1

printf "Installing cloudflared.\n\n"
chmod +x cloudflared && mv cloudflared /usr/bin/cloudflared

printf "Writing init config.\n\n"
#======================================== Start init config ========================================
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
#======================================== End init config ========================================
chmod +x /etc/init.d/cloudflared

printf "Starting and enabling service.\n\n"
/etc/init.d/cloudflared enable && /etc/init.d/cloudflared start

printf "Verifying that service is running.\n\n" ; sleep 5
! logread | grep cloudflared 1> /dev/null && printf "ERROR: INSTALL FAILED!\n\n" && exit 1

printf "SUCCESS: INSTALL COMPLETED.\n\n"
printf "Set split tunnel in Cloudflare Zero Trust portal under Settings -> Warp App.\n\n"
ENDSSH
#======================================== End SSH connection ========================================
}

#======================================== Start execution ========================================
main "$@"