#/bin/bash
#Installing required packages
echo "Updating and installing required packages" 
apt update -y
apt upgrade -y
apt install wireguard qrencode curl -y
echo "Installing Wireguard"
./tc_wireguard_1.sh
echo "Adding a user"
./tc_add_user.sh
