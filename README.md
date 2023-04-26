# Cloudflare Warp ARM Client Setup <img src="https://user-images.githubusercontent.com/95660759/234452549-53925c8f-bc2f-4eaf-b2e1-8cf13d2adbe7.png" width="50" height="50">

## Description:
This Bash script installs and configures the Cloudflare Warp client on an OpenWRT router. The script prompts the user for an IP address and a Cloudflare Access token, then it uses SSH to connect and perform the installation.

## Installation:
Download the setup.sh file, make it executable, run it, then provide your information:

```
curl -O https://raw.githubusercontent.com/oldstreetloft/Gli_Cloudflared/main/setup.sh
chmod +x setup.sh
./setup.sh
```
```
Enter the IP address: <ip_address>
Enter CFD Token: <your-access-token>

...

Set split tunnel in Cloudflare Zero Trust portal under Settings -> Warp App
```

## License:
This script is licensed under the GPLv3 License. See the LICENSE file for more information.
