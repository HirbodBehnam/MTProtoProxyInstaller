#!/bin/bash
#User must run the script as root
if [[ "$EUID" -ne 0 ]]; then
	echo "Please run this script as root"
	exit
fi
if readlink /proc/$$/exe | grep -q "dash"; then
	echo "This script needs to be run with bash, not sh"
	exit
fi
#Variables
regex='^[0-9]+$'
SECRETS=""
SECRET=""
TAG=""
COUNTER=1
clear
echo "Welcome to MTProto-Proxy auto installer!"
echo "Created by Hirbod Behnam"
echo "I will install mtprotoproxy python script by alexbers"
echo "Source at https://github.com/alexbers/mtprotoproxy"
echo "Now I will gather some info from you."
echo ""
echo ""
echo "Ok select a port to proxy listen on it: "
read -e -i 443 PORT
#Lets check if the PORT is valid
if ! [[ $PORT =~ $regex ]] ; then
   echo "error: The input is not a valid number"
   exit 1
fi
if [[ $PORT -gt 65535 ]] ; then
	echo "error: Number must be less than 65536"
	exit 1
fi
#Now the username
while true; do
	echo "Now tell me a user name. Usernames are used to name secrets: "
	read -e -i "MTSecret$COUNTER" USERNAME
	echo "Do you want to set secret manualy or shall i create a random secret?"
	echo "   1) Manualy enter a secret"
	echo "   2) Create a random secret"
	read -p "Please select one [1-2]: " OPTION
	case $OPTION in
		1)
		echo "Enter a 32 character string filled by 0-9 and a-f: "
		read SECRET
		#Validate length
		SECRET="$(echo $SECRET | tr '[A-Z]' '[a-z]')"
		if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]] ; then
 	  		echo "error: Enter hexadecimal character and secret must be 32 characters."
			exit 1
		fi
		;;
		2)
		SECRET="$(hexdump -vn "16" -e ' /1 "%02x"'  /dev/urandom)"
		echo "OK we created one: $SECRET"
		;;
		*)
		echo "Invalid option"
		exit 1
	esac
	#Now add them to secrets
	SECRETTEMP='"'
	SECRETTEMP+="$USERNAME"
	SECRETTEMP+='":"'
	SECRETTEMP+="$SECRET"
	SECRETTEMP+='"'
	SECRETS+="$SECRETTEMP , "
	read -p "Do you want to add another secret?(y/n)" OPTION
	case $OPTION in
		'y')
		;;
		'n')
		break
		;;
		*)
		echo "Invalid option"
		exit 1
	esac
	COUNTER=$((COUNTER+1))
done
SECRETS=${SECRETS::${#SECRETS}-2}
#Now setup the tag
read -p "Do you want to setup the advertising tag?(y/n)" OPTION
case $OPTION in
	'y')
	echo "On telegram go to @MTProxybot Bot and enter this server IP and $PORT as port. Then as secret enter $SECRET"
	echo "Bot now must give you a string named as TAG. Enter it here:"
	read TAG
	;;
	'n')
	;;
	*)
	echo "Invalid option"
	exit 1
esac
read -n 1 -s -r -p "Press any key to install..."
#Now lets install
clear
yum -y install epel-release yum-utils groupinstall development
yum -y update
yum -y install https://centos7.iuscommunity.org/ius-release.rpm
yum -y install git python36u python36u-devel python36u-pip
#This lib make proxy faster
pip3.6 install pycryptodome
cd /opt
git clone https://github.com/alexbers/mtprotoproxy.git
cd mtprotoproxy
#Now edit the config file
rm -f config.py
touch config.py
chmod 0777 config.py
echo "PORT = $PORT
USERS = {
$SECRETS
}" >> config.py
if ! [ -z "$TAG" ]; then
	TAGTEMP="AD_TAG = "
	TAGTEMP+='"'
	TAGTEMP+="$TAG"
	TAGTEMP+='"'
	echo "$TAGTEMP" >> config.py
fi
#Now lets create the service
cd /etc/systemd/system
touch mtprotoproxypython.service
echo "[Unit]
Description = MTProto Proxy Service

[Service]
Type = simple
ExecStart = /usr/bin/python3.6 /opt/mtprotoproxy/mtprotoproxy.py

[Install]
WantedBy = multi-user.target" >> mtprotoproxypython.service
systemctl enable mtprotoproxypython
systemctl start mtprotoproxypython
clear
echo "Ok it must be done. I created a service to run or stop the proxy."
echo 'Use "systemctl start mtprotoproxypython" or "systemctl stop mtprotoproxypython" to stop it'
echo 'Also use "systemctl status mtprotoproxypython -l" to get the proxy link'