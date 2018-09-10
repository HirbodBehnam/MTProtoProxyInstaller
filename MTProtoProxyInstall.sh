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
clear
#Check if user already installed Proxy
if [ -d "/opt/mtprotoproxy" ]; then
	echo "You have already installed MTProtoProxy! What do you want to do?"
	echo "  1) Uninstall Proxy"
	echo "  2) Upgrade Proxy Software"
	echo "  3) Change AD_TAG"
	echo "  4) Revoke Secret"
	echo "  5) Add Secret"
	echo "  6) Generate Firewalld rules"
	echo "  *) Exit"
	read -p "Please enter a number: " OPTION
	case $OPTION in
		1)
		#Uninstall proxy
		read -p "I still keep some packages like python. Do want to uninstall MTProto-Proxy?(y/n)" OPTION
		case $OPTION in
			"y")
			cd /opt/mtprotoproxy/
			PORT=$(python3.6 -c 'import config;print(getattr(config, "PORT",-1))')
			systemctl stop mtprotoproxy
			systemctl disable mtprotoproxy
			rm -rf /opt/mtprotoproxy
			rm -f /etc/systemd/system/mtprotoproxy.service
			firewall-cmd --permanent --remove-port=$PORT/tcp
			firewall-cmd --reload
			echo "Ok it's done."
			;;
		esac
		;;
		2)
		#Update
		cd /opt/mtprotoproxy/
		systemctl stop mtprotoproxy
		mv /opt/mtprotoproxy/config.py /tmp/config.py
		BRANCH=$(git rev-parse --abbrev-ref HEAD)
		git pull origin $BRANCH
		mv /tmp/config.py /opt/mtprotoproxy/config.py
		#Update cryptography and uvloop
		pip3.6 install --upgrade cryptography uvloop
		systemctl start mtprotoproxy
		echo "Proxy updated."
		;;
		3)
		#Change AD TAG
		cd /opt/mtprotoproxy
		PORT=$(python3.6 -c 'import config;print(getattr(config, "PORT",-1))')
		SECRET=$(python3.6 -c 'import config;print(getattr(config, "USERS",""))')
		SECRET=$(echo "$SECRET" | tr "'" '"')
		TAG=$(python3.6 -c 'import config;print(getattr(config, "AD_TAG",""))')
		if [ -z "$TAG" ]; then
			echo "It looks like your AD TAG is empty. Get the AD TAG at https://t.me/mtproxybot and enter it here:"
		else
			echo "Current tag is $TAG. If you want to remove it, just press enter. Otherwise type the new TAG:"
		fi
		read TAG
		systemctl stop mtprotoproxy
		rm -f config.py
		echo "PORT = $PORT
USERS = $SECRET
" >> config.py
		if ! [ -z "$TAG" ]; then
			TAGTEMP="AD_TAG = "
			TAGTEMP+='"'
			TAGTEMP+="$TAG"
			TAGTEMP+='"'
			echo "$TAGTEMP" >> config.py
		fi
		systemctl start mtprotoproxy
		echo "Done"
		;;
		4)
		echo "$(tput setaf 3)Just a second...$(tput sgr 0)"
		if ! yum -q list installed jq &>/dev/null; then
			read -p "In order to revoke a user I must install jq package. Continue?(y/n) " -e -i "y" OPTION
			case $OPTION in
				"y")
				yum -y install jq
				;;
				*)
				exit 2
			esac
		fi 
		clear
		cd /opt/mtprotoproxy
		rm -f tempSecrets.json
		PORT=$(python3.6 -c 'import config;print(getattr(config, "PORT",-1))')
		SECRET=$(python3.6 -c 'import config;print(getattr(config, "USERS",""))')
		SECRET=$(echo "$SECRET" | tr "'" '"')
		echo "$SECRET" >> tempSecrets.json
		TAG=$(python3.6 -c 'import config;print(getattr(config, "AD_TAG",""))')
		SECRET_ARY=()
		mapfile -t SECRET_ARY < <(jq -r 'keys[]' tempSecrets.json)
		echo "Here are list of current users:"
		COUNTER=1
		for i in "${SECRET_ARY[@]}"
		do
   			echo "	$COUNTER) $i"
			COUNTER=$((COUNTER+1))
		done
		read -p "Please select a user by it's index to revoke: " USER_TO_REVOKE
		USER_TO_REVOKE=$((USER_TO_REVOKE-1))
		#I should add a script to check the input but not for now (I'm so lazy)
		SECRET=$(jq "del(.${SECRET_ARY[$USER_TO_REVOKE]})" tempSecrets.json)
		systemctl stop mtprotoproxy
		rm -f config.py
		echo "PORT = $PORT
USERS = $SECRET
" >> config.py
		if ! [ -z "$TAG" ]; then
			TAGTEMP="AD_TAG = "
			TAGTEMP+='"'
			TAGTEMP+="$TAG"
			TAGTEMP+='"'
			echo "$TAGTEMP" >> config.py
		fi
		systemctl start mtprotoproxy
		rm -f tempSecrets.json
		echo "Done"
		;;
		5)
		#New secret
		cd /opt/mtprotoproxy
		PORT=$(python3.6 -c 'import config;print(getattr(config, "PORT",-1))')
		SECRETS=$(python3.6 -c 'import config;print(getattr(config, "USERS",""))')
		SECRETS=$(echo "$SECRETS" | tr "'" '"')
		SECRETS="${SECRETS: : -1}"
		TAG=$(python3.6 -c 'import config;print(getattr(config, "AD_TAG",""))')
		read -p "Ok now please enter the username: " -e -i "NewUser" NEW_USR
		echo "Do you want to set secret manualy or shall I create a random secret?"
		echo "   1) Manualy enter a secret"
		echo "   2) Create a random secret"
		read -p "Please select one [1-2]: " -e -i 2 OPTION
			case $OPTION in
			1)
			echo "Enter a 32 character string filled by 0-9 and a-f: "
			read SECRET
			#Validate length
			SECRET="$(echo $SECRET | tr '[A-Z]' '[a-z]')"
			if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]] ; then
 	  			echo "$(tput setaf 1)Error:$(tput sgr 0) Enter hexadecimal characters and secret must be 32 characters."
				exit 1
			fi
			;;
			2)
			SECRET="$(hexdump -vn "16" -e ' /1 "%02x"'  /dev/urandom)"
			echo "OK I created one: $SECRET"
			;;
			*)
			echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
			exit 1
			esac
		SECRETS+=', "'
		SECRETS+="$NEW_USR"
		SECRETS+='": "'
		SECRETS+="$SECRET"
		SECRETS+='"}'
		systemctl stop mtprotoproxy
		rm -f config.py
		echo "PORT = $PORT
USERS = $SECRETS
" >> config.py
		if ! [ -z "$TAG" ]; then
			TAGTEMP="AD_TAG = "
			TAGTEMP+='"'
			TAGTEMP+="$TAG"
			TAGTEMP+='"'
			echo "$TAGTEMP" >> config.py
		fi
		systemctl start mtprotoproxy
		echo "Done"
		;;
		6)
		#Firewall rules
		cd /opt/mtprotoproxy/
		PORT=$(python3.6 -c 'import config;print(getattr(config, "PORT",-1))')
		echo "firewall-cmd --zone=public --permanent --add-port=$PORT/tcp"
		echo "firewall-cmd --reload"
		;;
	esac
	exit
fi
#Variables
regex='^[0-9]+$'
SECRETS=""
SECRET=""
SECRET_END_ARY=()
USERNAME_END_ARY=()
TAG=""
COUNTER=1
echo "Welcome to MTProto-Proxy auto installer!"
echo "Created by Hirbod Behnam"
echo "I will install mtprotoproxy python script by alexbers"
echo "Source at https://github.com/alexbers/mtprotoproxy"
echo "Now I will gather some info from you."
echo ""
echo ""
read -p "Ok select a port to proxy listen on it: " -e -i 443 PORT
#Lets check if the PORT is valid
if ! [[ $PORT =~ $regex ]] ; then
   echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
   exit 1
fi
if [ $PORT -gt 65535 ] ; then
	echo "$(tput setaf 1)Error:$(tput sgr 0): Number must be less than 65536"
	exit 1
fi
#Now the username
while true; do
	echo "Now tell me a user name. Usernames are used to name secrets: "
	read -e -i "MTSecret$COUNTER" USERNAME
	echo "Do you want to set secret manualy or shall I create a random secret?"
	echo "   1) Manualy enter a secret"
	echo "   2) Create a random secret"
	read -p "Please select one [1-2]: " -e -i 2 OPTION
	case $OPTION in
		1)
		echo "Enter a 32 character string filled by 0-9 and a-f: "
		read SECRET
		#Validate length
		SECRET="$(echo $SECRET | tr '[A-Z]' '[a-z]')"
		if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]] ; then
 	  		echo "$(tput setaf 1)Error:$(tput sgr 0) Enter hexadecimal characters and secret must be 32 characters."
			exit 1
		fi
		;;
		2)
		SECRET="$(hexdump -vn "16" -e ' /1 "%02x"'  /dev/urandom)"
		SECRET_END_ARY+=($SECRET)
		USERNAME_END_ARY+=($USERNAME)
		echo "OK I created one: $SECRET"
		;;
		*)
		echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
		exit 1
	esac
	#Now add them to secrets
	SECRETTEMP='"'
	SECRETTEMP+="$USERNAME"
	SECRETTEMP+='":"'
	SECRETTEMP+="$SECRET"
	SECRETTEMP+='"'
	SECRETS+="$SECRETTEMP , "
	read -p "Do you want to add another secret?(y/n) " -e -i "n" OPTION
	case $OPTION in
		'y')
		;;
		'n')
		break
		;;
		*)
		echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
		exit 1
	esac
	COUNTER=$((COUNTER+1))
done
SECRETS=${SECRETS::${#SECRETS}-2}
#Set secure mode
read -p "Enable \"Secure Mode\"?(y/n) " -e -i "n" OPTION
case $OPTION in
	'y')
	SECURE_MODE=true
	;;
	'n')
	;;
	*)
	echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
	exit 1
esac
#Now setup the tag
read -p "Do you want to setup the advertising tag?(y/n) " -e -i "n" OPTION
case $OPTION in
	'y')
	echo "$(tput setaf 1)Note:$(tput sgr 0) Channel admins can't see thier own sponsored channels."
	echo "On telegram go to @MTProxybot Bot and enter this server IP and $PORT as port. Then as secret enter $SECRET"
	echo "Bot will give you a string named as TAG. Enter it here:"
	read TAG
	;;
	'n')
	;;
	*)
	echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
	exit 1
esac
read -n 1 -s -r -p "Press any key to install..."
#Now lets install
clear
yum -y install epel-release yum-utils ca-certificates
yum -y install https://centos7.iuscommunity.org/ius-release.rpm
yum -y update
yum -y install git2u python36u python36u-devel python36u-pip wget
#This libs make proxy faster
pip3.6 install cryptography uvloop
cd /opt
if [ "$1" == "-m" ]; then
	git clone https://github.com/alexbers/mtprotoproxy.git
else
	git clone -b stable https://github.com/alexbers/mtprotoproxy.git
fi

cd mtprotoproxy
#Now edit the config file
rm -f config.py
touch config.py
chmod 0777 config.py
echo "PORT = $PORT
USERS = {
$SECRETS
}
" >> config.py
if ! [ -z "$TAG" ]; then
	TAGTEMP="AD_TAG = "
	TAGTEMP+='"'
	TAGTEMP+="$TAG"
	TAGTEMP+='"'
	echo "$TAGTEMP" >> config.py
fi
if [ $SECURE_MODE = true ]; then
	echo "SECURE_ONLY = True" >> config.py
fi
#Setup firewall
echo "Setting firewalld rules"
firewall-cmd --zone=public --permanent --add-port=$PORT/tcp
firewall-cmd --reload
#Now lets create the service
cd /etc/systemd/system
touch mtprotoproxy.service
echo "[Unit]
Description = MTProto Proxy Service

[Service]
Type = simple
ExecStart = /usr/bin/python3.6 /opt/mtprotoproxy/mtprotoproxy.py

[Install]
WantedBy = multi-user.target" >> mtprotoproxy.service
systemctl enable mtprotoproxy
systemctl start mtprotoproxy
echo "Ok it must be done. I created a service to run or stop the proxy."
echo 'Use "systemctl start mtprotoproxy" or "systemctl stop mtprotoproxy" to start or stop it'
echo
echo "Use these links to connect to your proxy:"
PUBLIC_IP="$(wget https://api.ipify.org -q -O -)"
if [ $? -ne 0 ]; then
	PUBLIC_IP="YOUR_IP"
fi
COUNTER=0
for i in "${SECRET_END_ARY[@]}"
do
   echo "${USERNAME_END_ARY[$COUNTER]}: tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$i"
   COUNTER=$COUNTER+1
done
