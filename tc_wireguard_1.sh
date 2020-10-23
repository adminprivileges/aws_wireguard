#/bin/bash
#enable ipv4 forwarding
sysctl -w  "net.ipv4.ip_forward=1"
sed -i 's/\#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
#Making a Wireguard directory 
mkdir -vp /wg/keys
cd /wg/keys
umask 077
#Creating public and private keys
SERVER_PRIVKEY=`wg genkey`
SERVER_PUBKEY=`echo $SERVER_PRIVKEY | wg pubkey`
echo $SERVER_PUBKEY > ./server_public.key
echo $SERVER_PRIVKEY > ./server_private.key
#Making an endpoint IP/Port pair
read -p "Enter a number (1024-65535) this will be your VPN port (default 51820): " USER_PORT 
if [ -z $USER_PORT]
    then
        ENDPOINT=`curl -q ifconfig.me`:"51820"
else
    ENDPOINT=`curl -q ifconfig.me`:$USER_PORT
fi
echo "Your Endpoint IP/Port pair will be: $ENDPOINT"
echo $ENDPOINT > ./endpoint.var
#Determining the internal VPN subnet
read -p "Enter yopur perfered internal server IP, (default: 10.11.12.1): " SERVER_IP
if [ -z $SERVER_IP ]
    then SERVER_IP="10.11.12.1"
fi
echo "Your server IP will be: $SERVER_IP" 
VPN_SUBNET=`echo $SERVER_IP | grep -o -E '([0-9]+\.){3}'`
echo "your vpn subnet is $VPN_SUBNET"
echo $VPN_SUBNET > ./vpn_subnet.var
echo $SERVER_IP > ./server_ip.var

read -p "Enter the ip address of the server DNS (CIDR format), [ENTER] set to default: 1.1.1.1): " DNS
if [ -z $DNS ]
then DNS="1.1.1.1"
fi
echo $DNS > ./dns.var

echo 1 > ./last_used_ip.var
#Taking out rhe Interface name
read -p "Enter the name of the WAN network interface (default script will attempt to grab it): " WAN_INTERFACE_NAME
if [ -z $WAN_INTERFACE_NAME ]
then
  WAN_INTERFACE_NAME=`ip -o link show | awk -F ': ' '{print $2}' | grep -v lo | head -1`
fi
cat ./endpoint.var | sed -e "s/:/ /" | while read SERVER_EXTERNAL_IP SERVER_EXTERNAL_PORT
do
cat > ./wg0.conf.bak << EOF
[Interface]
Address = $SERVER_IP
SaveConfig = false
PrivateKey = $SERVER_PRIVKEY
ListenPort = $SERVER_EXTERNAL_PORT
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $WAN_INTERFACE_NAME -j MASQUERADE;
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $WAN_INTERFACE_NAME -j MASQUERADE;
EOF
done
cp -f ./wg0.conf.bak /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0
