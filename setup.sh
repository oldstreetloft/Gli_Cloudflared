#!/bin/bash
prompt_user() {
    read -p "Enter the IP address: " ip_address
    read -p "Enter the password: " password
    read -p "Enter CFD Token: " token
}

prompt_user
echo $ip_address
echo $password
echo $token