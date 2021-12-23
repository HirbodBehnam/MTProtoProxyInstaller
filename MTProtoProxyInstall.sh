#!/bin/bash
regex='^[0-9]+$'
function RemoveMultiLineUser() {
	local SECRET_T
	SECRET_T=$(python3.8 -c 'import config;print(getattr(config, "USERS",""))')
	SECRET_T=$(echo "$SECRET_T" | tr "'" '"')
	python3.8 -c "import re;f = open('config.py', 'r');s = f.read();p = re.compile('USERS\\s*=\\s*\\{.*?\\}', re.DOTALL);nonBracketedString = p.sub('', s);f = open('config.py', 'w');f.write(nonBracketedString)"
	echo "" >>config.py
	echo "USERS = $SECRET_T" >>config.py
}
function GetRandomPort() {
	if ! [ "$INSTALLED_LSOF" == true ]; then
		echo "Installing lsof package. Please wait."
		if [[ $distro =~ "CentOS" ]]; then
			yum -y -q install lsof
		elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
			apt-get -y install lsof >/dev/null
		fi
		local RETURN_CODE
		RETURN_CODE=$?
		if [ $RETURN_CODE -ne 0 ]; then
			echo "$(tput setaf 3)Warning!$(tput sgr 0) lsof package did not installed successfully. The randomized port may be in use."
		else
			INSTALLED_LSOF=true
		fi
	fi
	PORT=$((RANDOM % 16383 + 49152))
	if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null; then
		GetRandomPort
	fi
}
function ListUsersAndSelect() {
	clear
	SECRET=$(python3.8 -c 'import config;print(getattr(config, "USERS",""))')
	SECRET_COUNT=$(python3.8 -c 'import config;print(len(getattr(config, "USERS","")))')
	if [ "$SECRET_COUNT" == "0" ]; then
		echo "$(tput setaf 1)Error:$(tput sgr 0) You have no secrets."
		exit 4
	fi
	RemoveMultiLineUser #Regenerate USERS only in one line
	SECRET=$(echo "$SECRET" | tr "'" '"')
	echo "$SECRET" >tempSecrets.json
	SECRET_ARY=()
	mapfile -t SECRET_ARY < <(jq -r 'keys[]' tempSecrets.json)
	echo "Here are list of current users:"
	COUNTER=1
	NUMBER_OF_SECRETS=${#SECRET_ARY[@]}
	for i in "${SECRET_ARY[@]}"; do
		echo "	$COUNTER) $i"
		COUNTER=$((COUNTER + 1))
	done
	read -r -p "Please select a user by it's index: " USER_TO_LIMIT
	if ! [[ $USER_TO_LIMIT =~ $regex ]]; then
		echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
		exit 1
	fi
	if [ "$USER_TO_LIMIT" -lt 1 ] || [ "$USER_TO_LIMIT" -gt "$NUMBER_OF_SECRETS" ]; then
		echo "$(tput setaf 1)Error:$(tput sgr 0) Invalid number"
		exit 1
	fi
	USER_TO_LIMIT=$((USER_TO_LIMIT - 1))
	KEY=${SECRET_ARY[$USER_TO_LIMIT]}
}
function GenerateConnectionLimiterConfig() {
	LIMITER_CONFIG=""
	LIMITER_FILE=""
	for user in "${!limits[@]}"; do
		LIMITER_CONFIG+='"'
		LIMITER_CONFIG+=$user
		LIMITER_CONFIG+='": '
		LIMITER_CONFIG+=${limits[$user]}
		LIMITER_CONFIG+=" , "
		LIMITER_FILE+="$user;${limits[$user]}\n"
	done
	if ! [[ ${#limits[@]} == 0 ]]; then
		LIMITER_CONFIG=${LIMITER_CONFIG::${#LIMITER_CONFIG}-2}
	fi
}
function RestartService() {
	pid=$(systemctl show --property MainPID mtprotoproxy)
	arrPID=(${pid//=/ })
	pid=${arrPID[1]}
	kill -USR2 "$pid"
}
function PrintErrorJson() {
	echo "{\"ok\":false,\"msg\":\"$1\"}"
	exit 1
}
function PrintOkJson() {
	echo "{\"ok\":true,\"msg\":\"$1\"}"
}
function GetSecretFromUsername() {
	rm -f tempSecrets.json
	KEY="$1"
	SECRET=$(python3.8 -c 'import config;print(getattr(config, "USERS",""))')
	SECRET_COUNT=$(python3.8 -c 'import config;print(len(getattr(config, "USERS","")))')
	if [ "$SECRET_COUNT" == "0" ]; then
		PrintErrorJson "You have no secrets"
	fi
	RemoveMultiLineUser #Regenerate USERS only in one line
	SECRET=$(echo "$SECRET" | tr "'" '"')
	echo "$SECRET" >>tempSecrets.json
	SECRET=$(jq -r --arg k "$KEY" '.[$k]' tempSecrets.json)
	if [ "$SECRET" == "null" ]; then
		PrintErrorJson "This secret does not exist."
	fi
}
function CompilePython() {
	if ! command -v "python3.8" >/dev/null; then
		if [[ $distro =~ "CentOS" ]]; then
			yum -y groupinstall "Development Tools"
			yum -y install openssl-devel bzip2-devel libffi-devel
		else
			apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev
		fi
		#Download and install python 3.8
		cd /opt || exit 2
		curl -o Python-3.8.12.tar.xz https://www.python.org/ftp/python/3.8.12/Python-3.8.12.tar.xz
		tar xf Python-3.8.12.tar.xz
		cd Python-3.8.12 || exit 2
		./configure --enable-optimizations
		make altinstall
		ln -s /usr/local/bin/python3.8 /usr/bin/python3.8
	fi
	if ! [ -f "/usr/local/bin/python3.8" ]; then #in case user had python3.8
		ln -s /usr/local/bin/python3.8 /usr/bin/python3.8
	fi
}
#User must run the script as root
if [[ $EUID -ne 0 ]]; then
	echo "Please run this script as root"
	exit 1
fi
distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
clear
#Check if user already installed Proxy
if [ -d "/opt/mtprotoproxy" ]; then
	SCRIPT_LOCATION=$(realpath "$0")
	cd /opt/mtprotoproxy/ || exit 2
	if [ "$#" -ge 1 ]; then
		OPTION=$1
		if [ "$OPTION" == "list" ]; then
			if [ "$#" == 1 ]; then #list all of the secret and usernames
				SECRET=$(python3.8 -c 'import config;print(getattr(config, "USERS",""))')
				SECRET_COUNT=$(python3.8 -c 'import config;print(len(getattr(config, "USERS","")))')
				if [ "$SECRET_COUNT" == "0" ]; then
					PrintErrorJson "You have no secrets"
				fi
				SECRET=$(echo "$SECRET" | tr "'" '"')
				echo "{\"ok\":true,\"msg\":$SECRET}"
			else #Send the secret of the user
				GetSecretFromUsername "$2"
				PrintOkJson "$SECRET"
			fi
		fi
	else
		echo "You have already installed MTProtoProxy! What do you want to do?"
		echo "  1 ) View all connection links"
		echo "  2 ) Upgrade proxy software"
		echo "  3 ) Change AD TAG"
		echo "  4 ) Add a secret"
		echo "  5 ) Revoke a secret"
		echo "  6 ) Change user connection limits"
		echo "  7 ) Change user expiry date"
		echo "  8 ) Change user quota options"
		echo "  9 ) Generate firewall rules"
		echo "  10) Uninstall Proxy"
		echo "  11) About"
		echo "  * ) Exit"
		read -r -p "Please enter a number: " OPTION
	fi
	case $OPTION in
	#View connection links
	1)
		clear
		echo "$(tput setaf 3)Getting your IP address.$(tput sgr 0)"
		PUBLIC_IP="$(curl https://api.ipify.org -sS)"
		CURL_EXIT_STATUS=$?
		if [ $CURL_EXIT_STATUS -ne 0 ]; then
			PUBLIC_IP="YOUR_IP"
		fi
		PORT=$(python3.8 -c 'import config;print(getattr(config, "PORT",-1))')
		SECRET=$(python3.8 -c 'import config;print(getattr(config, "USERS",""))')
		SECRET_COUNT=$(python3.8 -c 'import config;print(len(getattr(config, "USERS","")))')
		TLS_DOMAIN=$(python3.8 -c 'import config;print(getattr(config, "TLS_DOMAIN", "www.google.com"))')
		if [ "$SECRET_COUNT" == "0" ]; then
			echo "$(tput setaf 1)Error:$(tput sgr 0) You have no secrets. Cannot show nothing!"
			exit 4
		fi
		RemoveMultiLineUser #Regenerate USERS only in one line
		SECRET=$(echo "$SECRET" | tr "'" '"')
		echo "$SECRET" >tempSecrets.json
		SECRET_ARY=()
		mapfile -t SECRET_ARY < <(jq -r 'keys[]' tempSecrets.json)
		#Print
		for user in "${SECRET_ARY[@]}"; do
			SECRET=$(jq --arg u "$user" -r '.[$u]' tempSecrets.json)
			s=$(python3.8 -c "print(\"ee\" + \"$SECRET\" + \"$TLS_DOMAIN\".encode().hex())")
			echo "$user: tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$s"
			echo
		done
		sed -i '/^$/d' config.py #Remove empty lines
		rm -f tempSecrets.json
		;;
	#Update
	2)
		read -r -p "If you have set quota limits, they will be reseted. Continue?(y/n) " OPTION
		OPTION="$(echo $OPTION | tr '[A-Z]' '[a-z]')"
		if [[ "$OPTION" == "y" ]]; then
			systemctl stop mtprotoproxy
			mv /opt/mtprotoproxy/config.py /tmp/config.py
			git pull
			mv /tmp/config.py /opt/mtprotoproxy/config.py
			#Update cryptography and uvloop
			pip3.8 install --upgrade cryptography uvloop
			systemctl start mtprotoproxy
			echo "Proxy updated."
		fi
		;;
	#Change AD_TAG
	3)
		TAG=$(python3.8 -c 'import config;print(getattr(config, "AD_TAG",""))')
		OldEmptyTag=false
		if [ -z "$TAG" ]; then
			OldEmptyTag=true
			echo "It looks like your AD TAG is empty. Get the AD TAG at https://t.me/mtproxybot and enter it here:"
		else
			echo "Current tag is $TAG. If you want to remove it, just press enter. Otherwise type the new TAG:"
		fi
		read -r TAG
		if [ -n "$TAG" ] && [ "$OldEmptyTag" = true ]; then
			#This adds the AD_TAG to end of file
			echo "" >>config.py #Adds a new line
			TAGTEMP="AD_TAG = "
			TAGTEMP+='"'
			TAGTEMP+="$TAG"
			TAGTEMP+='"'
			echo "$TAGTEMP" >>config.py
		elif [ -n "$TAG" ] && [ "$OldEmptyTag" = false ]; then
			# This replaces the AD_TAG
			TAGTEMP='"'
			TAGTEMP+="$TAG"
			TAGTEMP+='"'
			sed -i "s/^AD_TAG =.*/AD_TAG = $TAGTEMP/" config.py
		elif [ -z "$TAG" ] && [ "$OldEmptyTag" = false ]; then
			# This part removes the last AD_TAG
			sed -i '/^AD_TAG/ d' config.py
		fi
		sed -i '/^$/d' config.py #Remove empty lines
		RestartService
		echo "Done"
		;;
	#New secret
	4)
		#API Usage: bash MTProtoProxyInstall.sh 4 <USERNAME> <SECRET> -> Do not define secret to generate a random secret
		SECRETS=$(python3.8 -c 'import config;print(getattr(config, "USERS","{}"))')
		SECRET_COUNT=$(python3.8 -c 'import config;print(len(getattr(config, "USERS","")))')
		SECRETS=$(echo "$SECRETS" | tr "'" '"')
		SECRETS="${SECRETS::-1}" #Remove last char "}" here
		if [ "$#" -ge 2 ]; then #Get username
			NEW_USR="$2"
			if [ "$#" -ge 3 ]; then #This means secret should not be created randomly
				SECRET="$3"
				#Validate secret
				SECRET="$(echo $SECRET | tr '[A-Z]' '[a-z]')"
				if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]]; then
					PrintErrorJson "The secret is not valid. It must be hexadecimal, and 32 characters."
				fi
			else #Create a random secret
				SECRET="$(hexdump -vn "16" -e ' /1 "%02x"' /dev/urandom)"
			fi
		else #User mode
			echo "$(tput setaf 3)Warning!$(tput sgr 0) Do not use special characters like \" , ' , $ or... for username"
			read -r -p "Ok now please enter the username: " -e -i "NewUser" NEW_USR
			echo "Do you want to set secret manually or shall I create a random secret?"
			echo "   1) Manually enter a secret"
			echo "   2) Create a random secret"
			read -r -p "Please select one [1-2]: " -e -i 2 OPTION
			case $OPTION in
			1)
				echo "Enter a 32 character string filled by 0-9 and a-f: "
				read -r SECRET
				#Validate secret
				SECRET="$(echo $SECRET | tr '[A-Z]' '[a-z]')"
				if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]]; then
					echo "$(tput setaf 1)Error:$(tput sgr 0) Enter hexadecimal characters and secret must be 32 characters."
					exit 1
				fi
				;;
			2)
				SECRET="$(hexdump -vn "16" -e ' /1 "%02x"' /dev/urandom)"
				echo "OK I created one: $SECRET"
				;;
			*)
				echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
				exit 1
				;;
			esac
		fi
		RemoveMultiLineUser #Regenerate USERS only in one line
		if [ "$SECRET_COUNT" -ne 0 ]; then
			SECRETS+=','
		fi
		SECRETS+='"'
		SECRETS+="$NEW_USR"
		SECRETS+='": "'
		SECRETS+="$SECRET"
		SECRETS+='"}'
		sed -i '/^USERS\s*=.*/ d' config.py #Remove USERS
		echo "" >>config.py
		echo "USERS = $SECRETS" >>config.py
		sed -i '/^$/d' config.py #Remove empty lines
		RestartService
		PUBLIC_IP="$(curl https://api.ipify.org -sS)"
		CURL_EXIT_STATUS=$?
		if [ $CURL_EXIT_STATUS -ne 0 ]; then
			PUBLIC_IP="YOUR_IP"
		fi
		PORT=$(python3.8 -c 'import config;print(getattr(config, "PORT",-1))')
		TLS_DOMAIN=$(python3.8 -c 'import config;print(getattr(config, "TLS_DOMAIN", "www.google.com"))')
		s=$(python3.8 -c "print(\"ee\" + \"$SECRET\" + \"$TLS_DOMAIN\".encode().hex())")
		if [ "$#" -ge 2 ]; then
			echo "{\"ok\":true,\"msg\":{\"link\":\"tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$s\",\"secret\":\"$SECRET\"}}"
		else
			echo
			echo "You can now connect to your server with this secret with this link:"
			echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$s"
		fi
		;;
	#Revoke secret
	5)
		#API usage: bash MTProtoProxyInstall.sh 5 <USERNAME>
		if [ "$#" -ge 2 ]; then #Get username
			GetSecretFromUsername "$2" #However the SECRET variable is not used; This is just used to verify that the user exist
		else
			ListUsersAndSelect
		fi
		#remove expiry date and connection limits
		bash "$SCRIPT_LOCATION" 6 "$KEY" 0 &>/dev/null
		bash "$SCRIPT_LOCATION" 7 "$KEY" &>/dev/null
		#remove the secret
		SECRET=$(jq -c --arg u "$KEY" 'del(.[$u])' tempSecrets.json)
		sed -i '/^USERS\s*=.*/ d' config.py #Remove USERS
		echo "" >>config.py
		echo "USERS = $SECRET" >>config.py
		sed -i '/^$/d' config.py #Remove empty lines
		RestartService
		rm -f tempSecrets.json
		if [ "$#" -ge 2 ]; then
			PrintOkJson ""
		else
			echo "Done"
		fi
		;;
	#Connection limits
	6)
		#API Usage: bash MTProtoProxyInstall.sh 6 <USERNAME> <LIMIT> -> Pass zero for unlimited
		if [ "$#" -ge 3 ]; then
			GetSecretFromUsername "$2"
		else
			ListUsersAndSelect
		fi
		declare -A limits
		while IFS= read -r line; do
			if [ "$line" != "" ]; then
				arrIN=(${line//;/ })
				limits+=(["${arrIN[0]}"]="${arrIN[1]}")
			fi
		done <"limits_bash.txt"
		if [ "$#" -ge 3 ]; then
			MAX_USER=$3
			if ! [[ $MAX_USER =~ $regex ]]; then
				PrintErrorJson "The limit is not a valid number."
			fi
		else
			if [ ${limits[$KEY]+abc} ]; then
				MAX_USER=$((limits[$KEY] / 8))
				echo "Current limit is $MAX_USER concurrent users. (${limits[$KEY]} connections)"
			else
				echo "This user have no restrictions."
			fi
			read -r -p "Please enter the max users that you want to connect to this user; Enter 0 for unlimited: " MAX_USER
			if ! [[ $MAX_USER =~ $regex ]]; then
				echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
				exit 1
			fi
		fi
		MAX_USER=$((MAX_USER * 8))
		if [ "$MAX_USER" = "0" ]; then
			unset limits["$KEY"]
		else
			limits[$KEY]=$MAX_USER
		fi
		GenerateConnectionLimiterConfig
		echo -e "$LIMITER_FILE" >"limits_bash.txt"
		sed -i '/^USER_MAX_TCP_CONNS\s*=.*/ d' config.py #Remove settings
		echo "" >>config.py
		echo "USER_MAX_TCP_CONNS = { $LIMITER_CONFIG }" >>config.py
		sed -i '/^$/d' config.py #Remove empty lines
		RestartService
		if [ "$#" -ge 3 ]; then
			PrintOkJson ""
		else
			echo "Done"
		fi
		;;
	#Expiry date
	7)
		#API Usage: bash MTProtoProxyInstall.sh 7 <USERNAME> <DATE> -> Pass nothing as <DATE> to remove; Date format is dd/mm/yyyy
		if [ "$#" -ge 2 ]; then
			GetSecretFromUsername "$2"
			DATE="$3"
		else
			ListUsersAndSelect
			read -r -p "Enter the expiry date in format of day/month/year(Example 11/09/2019). Enter nothing for removal: " DATE
		fi
		if [[ $DATE == "" ]]; then
			j=$(jq -c --arg k "$KEY" 'del(.[$k])' limits_date.json)
		else
			if ! [[ $DATE =~ ^[0-9]{2}/[0-9]{2}/[0-9]{4}$ ]]; then 
				if [ "$#" -ge 2 ]; then
					PrintErrorJson "Invalid date format"
				else
					echo "Invalid format (DD/MM/YYYY)"
					exit 1
				fi
			fi
			j=$(jq -c --arg k "$KEY" --arg v "$DATE" '.[$k] = $v' limits_date.json)
		fi
		echo -e "$j" >limits_date.json
		#Save it to the config.py
		sed -i '/^USER_EXPIRATIONS\s*=.*/ d' config.py #Remove settings
		echo "" >>config.py
		echo "USER_EXPIRATIONS = $j" >>config.py
		sed -i '/^$/d' config.py #Remove empty lines
		RestartService
		if [ "$#" -ge 2 ]; then
			PrintOkJson ""
		else
			echo "Done"
		fi
		;;
	#Quota limit stuff
	8)
		#API Usage: bash MTProtoProxyInstall.sh 8 <USERNAME> <LIMIT> -> Pass nothing as <LIMIT> to remove; The number is in bytes
		if [ "$#" -ge 2 ]; then
			GetSecretFromUsername "$2"
			LIMIT="$3"
		else
			ListUsersAndSelect
			read -r -p "Enter the limit of the user in bytes. You can use kb, mb and gb suffixes. Enter nothing for removal: " LIMIT
		fi
		if [[ $LIMIT == "" ]]; then
			j=$(jq -c --arg k "$KEY" 'del(.[$k])' limits_quota.json)
		else
			LIMIT="$(echo $LIMIT | tr '[A-Z]' '[a-z]')"
			MULTIPLIER=1
			case "$LIMIT" in
			*kb)
				MULTIPLIER=1024
				LIMIT=${LIMIT::-2}
				;;
			*mb)
				MULTIPLIER=$((1024*1024))
				LIMIT=${LIMIT::-2}
				;;
			*gb)
				MULTIPLIER=$((1024*1024*1024))
				LIMIT=${LIMIT::-2}
				;;
			esac
			if ! [[ $LIMIT =~ $regex ]]; then
				if [ "$#" -ge 2 ]; then
					PrintErrorJson "Invalid number format"
				else
					echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
					exit 1
				fi
			fi
			LIMIT=$((MULTIPLIER*LIMIT))
			j=$(jq -c --arg k "$KEY" --argjson v "$LIMIT" '.[$k] = $v' limits_quota.json)
		fi
		echo -e "$j" >limits_quota.json
		#Save it to the config.py
		sed -i '/^USER_DATA_QUOTA\s*=.*/ d' config.py #Remove settings
		echo "" >>config.py
		echo "USER_DATA_QUOTA = $j" >>config.py
		sed -i '/^$/d' config.py #Remove empty lines
		RestartService
		if [ "$#" -ge 2 ]; then
			PrintOkJson ""
		else
			echo "Done"
		fi
		;;
	#Firewall rules
	9)
		PORT=$(python3.8 -c 'import config;print(getattr(config, "PORT",-1))')
		if [[ $distro =~ "CentOS" ]]; then
			echo "firewall-cmd --zone=public --add-port=$PORT/tcp"
			echo "firewall-cmd --runtime-to-permanent"
		elif [[ $distro =~ "Ubuntu" ]]; then
			echo "ufw allow $PORT/tcp"
		elif [[ $distro =~ "Debian" ]]; then
			echo "iptables -A INPUT -p tcp --dport $PORT --jump ACCEPT"
			echo "iptables-save > /etc/iptables/rules.v4"
		fi
		read -r -p "Do you want to apply these rules?[y/n] " -e -i "y" OPTION
		if [ "$OPTION" == "y" ] || [ "$OPTION" == "Y" ]; then
			if [[ $distro =~ "CentOS" ]]; then
				firewall-cmd --zone=public --add-port="$PORT"/tcp
				firewall-cmd --runtime-to-permanent
			elif [[ $distro =~ "Ubuntu" ]]; then
				ufw allow "$PORT"/tcp
			elif [[ $distro =~ "Debian" ]]; then
				iptables -A INPUT -p tcp --dport "$PORT" --jump ACCEPT
				iptables-save >/etc/iptables/rules.v4
			fi
		fi
		;;
	#Uninstall proxy
	10)
		read -r -p "I still keep some packages like python. Do want to uninstall MTProto-Proxy?(y/n) " OPTION
		OPTION="$(echo $OPTION | tr '[A-Z]' '[a-z]')"
		case $OPTION in
		"y")
			PORT=$(python3.8 -c 'import config;print(getattr(config, "PORT",-1))')
			systemctl stop mtprotoproxy
			systemctl disable mtprotoproxy
			rm -rf /opt/mtprotoproxy /etc/systemd/system/mtprotoproxy.service
			systemctl daemon-reload
			if [[ $distro =~ "CentOS" ]]; then
				firewall-cmd --remove-port="$PORT"/tcp
				firewall-cmd --runtime-to-permanent
			elif [[ $distro =~ "Ubuntu" ]]; then
				ufw delete allow "$PORT"/tcp
			elif [[ $distro =~ "Debian" ]]; then
				iptables -D INPUT -p tcp --dport "$PORT" --jump ACCEPT
				iptables-save >/etc/iptables/rules.v4
			fi
			echo "Ok it's done."
			;;
		esac
		;;
	# About
	11)
		echo "MTProtoInstaller script by Hirbod Behnam"
		echo "Source at https://github.com/alexbers/mtprotoproxy"
		echo "Github repo of script: https://github.com/HirbodBehnam/MTProtoProxyInstaller"
		;;
	esac
	exit
fi
#Variables
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
echo "Github repo of script: https://github.com/HirbodBehnam/MTProtoProxyInstaller"
echo "Now I will gather some info from you."
echo ""
echo ""
read -r -p "Select a port to proxy listen on it (-1 to randomize): " -e -i "443" PORT
if [[ $PORT -eq -1 ]]; then
	GetRandomPort
	echo "I've selected $PORT as your port."
fi
#Lets check if the PORT is valid
if ! [[ $PORT =~ $regex ]]; then
	echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
	exit 1
fi
if [ "$PORT" -gt 65535 ]; then
	echo "$(tput setaf 1)Error:$(tput sgr 0): Number must be less than 65536"
	exit 1
fi
#Now the username and secrets
declare -A limits
echo "$(tput setaf 3)Warning!$(tput sgr 0) Do not use special characters like \" , ' , $ or... for username"
while true; do
	echo "Now tell me a user name. Usernames are used to name secrets: "
	read -r -e -i "MTSecret$COUNTER" USERNAME
	echo "Do you want to set secret manually or shall I create a random secret?"
	echo "   1) Manually enter a secret"
	echo "   2) Create a random secret"
	read -r -p "Please select one [1-2]: " -e -i 2 OPTION
	case $OPTION in
	1)
		echo "Enter a 32 character string filled by 0-9 and a-f(hexadecimal): "
		read -r SECRET
		#Validate length
		SECRET="$(echo $SECRET | tr '[A-Z]' '[a-z]')"
		if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]]; then
			echo "$(tput setaf 1)Error:$(tput sgr 0) Enter hexadecimal characters and secret must be 32 characters."
			exit 1
		fi
		;;
	2)
		SECRET="$(hexdump -vn "16" -e ' /1 "%02x"' /dev/urandom)"
		echo "OK I created one: $SECRET"
		;;
	*)
		echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
		exit 1
		;;
	esac
	SECRET_END_ARY+=("$SECRET")
	USERNAME_END_ARY+=("$USERNAME")
	#Now add them to secrets
	SECRETTEMP='"'
	SECRETTEMP+="$USERNAME"
	SECRETTEMP+='":"'
	SECRETTEMP+="$SECRET"
	SECRETTEMP+='"'
	SECRETS+="$SECRETTEMP , "
	#Setup limiter
	read -r -p "Do you want to limit users connected to this secret?(y/n) " -e -i "n" OPTION
	OPTION="$(echo $OPTION | tr '[A-Z]' '[a-z]')"
	case $OPTION in
	'y')
		read -r -p "How many users do you want to connect to this secret? " OPTION
		if ! [[ $OPTION =~ $regex ]]; then
			echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
			exit 1
		fi
		#Multiply number of connections by 8. You can manualy change this. Read more: https://github.com/alexbers/mtprotoproxy/blob/master/mtprotoproxy.py#L202
		OPTION=$((OPTION * 8))
		limits+=(["$USERNAME"]="$OPTION")
		;;
	'n') ;;

	*)
		echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
		exit 1
		;;
	esac
	read -r -p "Do you want to add another secret?(y/n) " -e -i "n" OPTION
	OPTION="$(echo $OPTION | tr '[A-Z]' '[a-z]')"
	case $OPTION in
	'y') ;;

	'n')
		break
		;;
	*)
		echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
		exit 1
		;;
	esac
	COUNTER=$((COUNTER + 1))
done
SECRETS=${SECRETS::${#SECRETS}-2}
if [ ${#limits[@]} -gt 0 ]; then
	GenerateConnectionLimiterConfig
fi
#Set secure mode
echo
echo "1) No Restrictions"
echo '2) "dd" secrets and TLS connections'
echo "3) TLS connection only"
read -r -p "Do want to restrict the connections? Select one: " -e -i "3" OPTION
case $OPTION in
'1') 
	SECURE_MODE="MODES = { \"classic\": True, \"secure\": True, \"tls\": True }"
	;;
'2')
	SECURE_MODE="MODES = { \"classic\": False, \"secure\": True, \"tls\": True }"
	;;
'3')
	SECURE_MODE="MODES = { \"classic\": False, \"secure\": False, \"tls\": True }"
	;;
*)
	echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
	exit 1
	;;
esac
#Now setup the tag
read -r -p "Do you want to setup the advertising tag?(y/n) " -e -i "n" OPTION
if [[ "$OPTION" == "y" || "$OPTION" == "Y" ]]; then
	echo "$(tput setaf 1)Note:$(tput sgr 0) Joined users and admins won't see the channel at very top."
	echo "On telegram, go to @MTProxybot Bot and enter this server's IP and $PORT as port. Then as secret enter $SECRET"
	echo "Bot will give you a string named TAG. Enter it here:"
	read -r TAG
fi
#Change host mask
read -r -p "Select a host that DPI thinks you are visiting (TLS_DOMAIN): " -e -i "www.cloudflare.com" TLS_DOMAIN
#Now lets install
read -n 1 -s -r -p "Press any key to install..."
clear
if [[ $distro =~ "CentOS" ]]; then
	yum -y install epel-release
	yum -y install sed git curl ca-certificates jq
	CompilePython
elif [[ $distro =~ "Ubuntu" ]]; then
	apt update
	if ! [[ $(lsb_release -r -s) =~ "20" ]]; then
		apt-get -y install software-properties-common
		add-apt-repository ppa:deadsnakes/ppa
	fi
	apt-get update
	apt-get -y install python3.8 python3.8-distutils sed git curl jq ca-certificates
elif [[ $distro =~ "Debian" ]]; then
	apt-get update
	apt-get install -y jq ca-certificates iptables-persistent iptables git sed curl wget
	CompilePython
	#Firewall
	iptables -A INPUT -p tcp --dport "$PORT" --jump ACCEPT
	iptables-save >/etc/iptables/rules.v4
else
	echo "Your OS is not supported"
	exit 2
fi
timedatectl set-ntp on #Make the time accurate by enabling ntp
#Install pip
curl https://bootstrap.pypa.io/get-pip.py | python3.8
#This libs make proxy faster
pip3.8 install cryptography uvloop
if ! [ -d "/opt" ]; then
	mkdir /opt
fi
cd /opt || exit 2
git clone https://github.com/alexbers/mtprotoproxy.git
cd mtprotoproxy || exit 2
#Now edit the config file
chmod 0777 config.py
echo "PORT = $PORT
USERS = { $SECRETS }
USER_MAX_TCP_CONNS = { $LIMITER_CONFIG }
TLS_DOMAIN = \"$TLS_DOMAIN\"
" >config.py
if [ -n "$TAG" ]; then
	TAGTEMP="AD_TAG = "
	TAGTEMP+='"'
	TAGTEMP+="$TAG"
	TAGTEMP+='"'
	echo "$TAGTEMP" >>config.py
fi
echo "$SECURE_MODE" >> config.py
echo -e "$LIMITER_FILE" >> "limits_bash.txt"
echo "{}" >> "limits_date.json"
echo "{}" >> "limits_quota.json"
#Setup firewall
echo "Setting firewalld rules"
if [[ $distro =~ "CentOS" ]]; then
	SETFIREWALL=true
	if ! yum -q list installed firewalld &>/dev/null; then
		echo ""
		read -r -p 'Looks like "firewalld" is not installed Do you want to install it?(y/n) ' -e -i "y" OPTION
		case $OPTION in
		"y")
			yum -y install firewalld
			systemctl enable firewalld
			;;
		*)
			SETFIREWALL=false
			;;
		esac
	fi
	if [ "$SETFIREWALL" = true ]; then
		systemctl start firewalld
		firewall-cmd --zone=public --add-port="$PORT"/tcp
		firewall-cmd --runtime-to-permanent
	fi
elif [[ $distro =~ "Ubuntu" ]]; then
	if dpkg --get-selections | grep -q "^ufw[[:space:]]*install$" >/dev/null; then
		ufw allow "$PORT"/tcp
	else
		echo
		read -r -p 'Looks like "UFW"(Firewall) is not installed Do you want to install it?(y/n) ' -e -i "y" OPTION
		case $OPTION in
		"y" | "Y")
			apt-get install ufw
			ufw enable
			ufw allow ssh
			ufw allow "$PORT"/tcp
			;;
		esac
	fi
	#Use BBR on user will
	if ! [ "$(sysctl -n net.ipv4.tcp_congestion_control)" = "bbr" ] && { [[ $(lsb_release -r -s) =~ "20" ]] || [[ $(lsb_release -r -s) =~ "19" ]] || [[ $(lsb_release -r -s) =~ "18" ]]; }; then
		echo
		read -r -p "Do you want to use BBR? BBR might help your proxy run faster.(y/n) " -e -i "y" OPTION
		case $OPTION in
		"y" | "Y")
			echo 'net.core.default_qdisc=fq' | tee -a /etc/sysctl.conf
			echo 'net.ipv4.tcp_congestion_control=bbr' | tee -a /etc/sysctl.conf
			sysctl -p
			;;
		esac
	fi
fi
#Now lets create the service
cd /etc/systemd/system || exit 2
echo "[Unit]
Description = MTProto Proxy Service
After=network.target

[Service]
Type = simple
ExecStart = /usr/bin/python3.8 /opt/mtprotoproxy/mtprotoproxy.py
StartLimitBurst=0

[Install]
WantedBy = multi-user.target" >mtprotoproxy.service
systemctl daemon-reload
systemctl enable mtprotoproxy
systemctl start mtprotoproxy
tput setaf 3
printf "%$(tput cols)s" | tr ' ' '#'
tput sgr 0
echo "Ok it must be done. I created a service to run or stop the proxy."
echo 'Use "systemctl start mtprotoproxy" or "systemctl stop mtprotoproxy" to start or stop it'
echo
echo "Use these links to connect to your proxy:"
PUBLIC_IP="$(curl https://api.ipify.org -sS)"
CURL_EXIT_STATUS=$?
[ $CURL_EXIT_STATUS -ne 0 ] && PUBLIC_IP="YOUR_IP"
COUNTER=0
for i in "${SECRET_END_ARY[@]}"; do
	s=$(python3.8 -c "print(\"ee\" + \"$SECRET\" + \"$TLS_DOMAIN\".encode().hex())")
	echo "${USERNAME_END_ARY[$COUNTER]}: tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$s"
	COUNTER=$COUNTER+1
done
