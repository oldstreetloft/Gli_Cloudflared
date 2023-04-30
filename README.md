# Cloudflared ARM Client Installer  <img src="https://user-images.githubusercontent.com/95660759/234452549-53925c8f-bc2f-4eaf-b2e1-8cf13d2adbe7.png" width="50" height="50">

## Description:
This Bash script installs and configures the Cloudflare Tunnel client on an OpenWRT router over a network. The script prompts the user for the device's IP address and Cloudflare Access token, checks for internet connectivity and device prescesnce, starts a SSH connection to the device, downloads the latest version from GitHub, generates an init config file, starts and enables the cloudflared service, and verifies that the installation was successful. The key functionality of the script is to automate the installation and configuration process, making it easier for users to set up Cloudflare tunnels on their devices.
## Installation:
Copy the following commands, paste them into a terminal window on the local machine, then tap Enter key:
```
curl -O https://raw.githubusercontent.com/oldstreetloft/install-cloudflared/main/setup.sh
chmod +x setup.sh
./setup.sh
```
## Example
Script will run with or without command line arguments:
```
./setup.sh <ip_address> <access_token>
```
```
Enter IP address: <ip_address>
Enter CFD Token: <access_token>
Enter password: <password>
...
Set split tunnel in Cloudflare Zero Trust portal under Settings -> Warp App.
```
## About Cloudflare Tunnels
Cloudflare Tunnel provides you with a secure way to connect your resources to Cloudflare without a publicly routable IP address. With Tunnel, you do not send traffic to an external IP — instead, a lightweight daemon in your infrastructure [(cloudflared)](https://github.com/cloudflare/cloudflared) creates outbound-only connections to Cloudflare’s global network. Cloudflare Tunnel can connect HTTP web servers, SSH servers, remote desktops, and other protocols safely to Cloudflare. This way, your origins can serve traffic through Cloudflare without being vulnerable to attacks that bypass Cloudflare.
## License:
This script is licensed under the GPLv3 License. See the LICENSE file for more information.
