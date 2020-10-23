#/bin/bash
#Installing required packages
apt update -y
apt upgrade -y
apt install wireguard qrencode unbound unbound-host curl -y
echo "Pulling the files from github"
curl https://raw.githubusercontent.com/adminprivileges/aws_wireguard/main/tc_wireguard.sh -o /etc/wireguard/tc_wireguard.sh
curl https://raw.githubusercontent.com/adminprivileges/aws_wireguard/main/add_user.sh -o /etc/wireguard/tc_add_user.sh
echo "Making files executable"
chmod +x /etc/wireguard/tc_wireguard.sh
chmod +x /etc/wireguard/tc_add_user.sh
echo "Installing Wireguard"
/etc/wireguard/tc_wireguard.sh
echo "Adding a user"
/etc/wireguard/tc_add_user.sh
