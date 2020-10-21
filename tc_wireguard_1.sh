#/bin/bash
#Installing required packages
apt update -y
apt upgrade -y
apt install wireguard qrencode unbound unbound-host curl -y
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
#Determining the internal VPN subnet
read -p "Enter yopur perfered internal server IP, (default: 10.11.12.1): " SERVER_IP
if [ -z $SERVER_IP ]
    then SERVER_IP="10.11.12.1"
fi
echo "Your server IP will be: $SERVER_IP" 
VPN_SUBNET=`echo $SERVER_IP | grep -o -E '([0-9]+\.){3}'`
echo "your vpn subnet is $VPN_SUBNET"
# download list of DNS root servers
sudo curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
# create Unbound config file
echo "
server:
    num-threads: 4
    # enable logs
    verbosity: 1
    # list of root DNS servers
    root-hints: \"/var/lib/unbound/root.hints\"
    # use the root server's key for DNSSEC
    auto-trust-anchor-file: \"/var/lib/unbound/root.key\"
    # respond to DNS requests on all interfaces
    interface: 0.0.0.0
    max-udp-size: 3072
    # IPs authorised to access the DNS Server
    access-control: 0.0.0.0/0                 refuse
    access-control: 127.0.0.1                 allow
    access-control: $VPN_SUBNET0/24             allow
    # not allowed to be returned for public Internet  names
    private-address: $VPN_SUBNET0/24
    #hide DNS Server info
    hide-identity: yes
    hide-version: yes
    # limit DNS fraud and use DNSSEC
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes
    # add an unwanted reply threshold to clean the cache and avoid, when possible, DNS poisoning
    unwanted-reply-threshold: 10000000
    # have the validator print validation failures to the log
    val-log-level: 1
    # minimum lifetime of cache entries in seconds
    cache-min-ttl: 1800
    # maximum lifetime of cached entries in seconds
    cache-max-ttl: 14400
    prefetch: yes
    prefetch-key: yes

" | sudo tee /etc/unbound/unbound.conf 
# give root ownership of the Unbound config
sudo chown -R unbound:unbound /var/lib/unbound
#Verifying hosts file
echo "127.0.0.1 localhost `hostname`" > /etc/hosts
echo 1 > ./last_used_ip.var
#Taking out the Interface name
read -p "Enter the name of the WAN network interface (default script will attempt to grab it): " WAN_INTERFACE_NAME
if [ -z $WAN_INTERFACE_NAME ]
then
  WAN_INTERFACE_NAME=`ip -o link show | awk -F ': ' '{print $2}' | grep -v lo | head -1`
fi
cat $ENDPOINT | sed -e "s/:/ /" | while read SERVER_EXTERNAL_IP SERVER_EXTERNAL_PORT
do
echo "Building your config file"
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
cp -f ./wg0.conf.def ./wg0.conf
#making the .1 a variable to be changed later
last_used_ip=(1)
echo "Now time to set up a client"
read -p "Enter VPN user name: " USERNAME
ALLOWED_IP="0.0.0.0/0, ::/0"
#
mkdir -p ./clients
cd ./clients
mkdir ./$USERNAME
cd ./$USERNAME
umask 077
#Generating needed variables
CLIENT_PRESHARED_KEY=`wg genpsk`
CLIENT_PRIVKEY=`wg genkey`
CLIENT_PUBLIC_KEY=`echo $CLIENT_PRIVKEY | wg pubkey`
#Makign Client IP
read SERVER_PUBLIC_KEY < /wg/keys/server_public.key
read OCTET_IP < /etc/wireguard/last_used_ip.var
OCTET_IP=$(($OCTET_IP+1))
echo $OCTET_IP > /etc/wireguard/last_used_ip.var
CLIENT_IP="$VPN_SUBNET$OCTET_IP/32"
# Create a blank configuration file client 
cat > /etc/wireguard/clients/$USERNAME/$USERNAME.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address = $CLIENT_IP
DNS = $DNS


[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $ALLOWED_IP
Endpoint = $ENDPOINT
PersistentKeepalive=25
EOF
# Add new client data to the Wireguard configuration file
cat >> /etc/wireguard/wg0.conf << EOF

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
