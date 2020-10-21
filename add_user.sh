#!/bin/bash

# We read from the input parameter the name of the client
read -p "Enter VPN user name: " USERNAME

cd /wq/keys/

read DNS < 127.0.0.1
read ENDPOINT < ./endpoint.var
read VPN_SUBNET < ./vpn_subnet.var
PRESHARED_KEY="_preshared.key"
PRIV_KEY="_private.key"
PUB_KEY="_public.key"
ALLOWED_IP="0.0.0.0/0, ::/0"

# Go to the wireguard directory and create a directory structure in which we will store client configuration files
mkdir -p ./clients
cd ./clients
mkdir ./$USERNAME
cd ./$USERNAME
umask 077

CLIENT_PRESHARED_KEY=`wg genpsk`
CLIENT_PRIVKEY=`wg genkey`
CLIENT_PUBLIC_KEY=`echo $CLIENT_PRIVKEY | wg pubkey`
read SERVER_PUBLIC_KEY < /wg/keys/server_public.key

# We get the following client IP address
read OCTET_IP < /wg/keys/last_used_ip.var
OCTET_IP=$(($OCTET_IP+1))
echo $OCTET_IP > /wg/keys/last_used_ip.var

CLIENT_IP="$VPN_SUBNET$OCTET_IP/32"

# Create a blank configuration file client 
cat > /wg/keys/clients/$USERNAME/$USERNAME.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address = $CLIENT_IP
DNS = 127.0.0.1


[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $ALLOWED_IP
Endpoint = $ENDPOINT
PersistentKeepalive=25
EOF

# Add new client data to the Wireguard configuration file
cat >> /wg/keys/wg0.conf << EOF

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $CLIENT_IP
EOF

# Restart Wireguard
systemctl stop wg-quick@wg0
systemctl start wg-quick@wg0

# Show QR config to display
qrencode -t ansiutf8 < ./$USERNAME.conf

# Show config file
echo "# Display $USERNAME.conf"
cat ./$USERNAME.conf

# Save QR config to png file
#qrencode -t png -o ./$USERNAME.png < ./$USERNAME.conf
