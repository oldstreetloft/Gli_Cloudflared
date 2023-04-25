# Cloudflare Warp Client ARM Setup
## Description
This Bash script installs and configures the Cloudflare Warp client on an arm based router. The script prompts the user for an IP address and a Cloudflare Access token, then uses SSH to connect to the server and perform the installation.

## Installation:
Download the setup.sh file, make it executable, run it, and provide your information:

`curl -O https://raw.githubusercontent.com/oldstreetloft/Gli_Cloudflared/main/setup.sh`

`chmod +x setup.sh`

`$ ./setup.sh`

`Enter the IP address: 192.168.1.1`

`Enter CFD Token: <your-access-token>`

`...`

`Set split tunnel in Cloudflare zero trust portal under settings -> warp app`

## License:
This script is licensed under the GPLv3 License. See the LICENSE file for more information.