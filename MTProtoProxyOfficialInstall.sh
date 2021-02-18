#!/bin/bash
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
function GenerateService() {
	local ARGS_STR
	ARGS_STR="-u nobody -H $PORT"
	for i in "${SECRET_ARY[@]}"; do # Add secrets
		ARGS_STR+=" -S $i"
	done
	if [ -n "$TAG" ]; then
		ARGS_STR+=" -P $TAG "
	fi
	if [ -n "$TLS_DOMAIN" ]; then
		ARGS_STR+=" -D $TLS_DOMAIN "
	fi
	if [ "$HAVE_NAT" == "y" ]; then
		ARGS_STR+=" --nat-info $PRIVATE_IP:$PUBLIC_IP "
	fi
	NEW_CORE=$((CPU_CORES - 1))
	ARGS_STR+=" -M $NEW_CORE $CUSTOM_ARGS --aes-pwd proxy-secret proxy-multi.conf"
	SERVICE_STR="[Unit]
Description=MTProxy
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/MTProxy/objs/bin
ExecStart=/opt/MTProxy/objs/bin/mtproto-proxy $ARGS_STR
Restart=on-failure
StartLimitBurst=0

[Install]
WantedBy=multi-user.target"
}
#User must run the script as root
if [[ "$EUID" -ne 0 ]]; then
	echo "Please run this script as root"
	exit 1
fi
regex='^[0-9]+$'
distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
clear
if [ -d "/opt/MTProxy" ]; then
	echo "You have already installed MTProxy! What do you want to do?"
	echo "  1) Show connection links"
	echo "  2) Change TAG"
	echo "  3) Add a secret"
	echo "  4) Revoke a secret"
	echo "  5) Change Worker Numbers"
	echo "  6) Change NAT settings"
	echo "  7) Change Custom Arguments"
	echo "  8) Generate Firewall Rules"
	echo "  9) Uninstall Proxy"
	echo "  *) Exit"
	read -r -p "Please enter a number: " OPTION
	source /opt/MTProxy/objs/bin/mtconfig.conf #Load Configs
	case $OPTION in
	#Show connections
	1)
		clear
		echo "$(tput setaf 3)Getting your IP address.$(tput sgr 0)"
		PUBLIC_IP="$(curl https://api.ipify.org -sS)"
		CURL_EXIT_STATUS=$?
		if [ $CURL_EXIT_STATUS -ne 0 ]; then
			PUBLIC_IP="YOUR_IP"
		fi
		HEX_DOMAIN=$(printf "%s" "$TLS_DOMAIN" | xxd -pu)
		HEX_DOMAIN="$(echo $HEX_DOMAIN | tr '[A-Z]' '[a-z]')"
		for i in "${SECRET_ARY[@]}"; do
			if [ -z "$TLS_DOMAIN" ]; then
				echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=dd$i"
			else
				echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=ee$i$HEX_DOMAIN"
			fi
		done
		;;
	#Change TAG
	2)
		if [ -z "$TAG" ]; then
			echo "It looks like your AD TAG is empty. Get the AD TAG at https://t.me/mtproxybot and enter it here:"
		else
			echo "Current tag is $TAG. If you want to remove it, just press enter. Otherwise type the new TAG:"
		fi
		read -r TAG
		cd /etc/systemd/system || exit 2
		systemctl stop MTProxy
		GenerateService
		echo "$SERVICE_STR" >MTProxy.service
		systemctl daemon-reload
		systemctl start MTProxy
		cd /opt/MTProxy/objs/bin/ || exit 2
		sed -i "s/^TAG=.*/TAG=\"$TAG\"/" mtconfig.conf
		echo "Done"
		;;
	#Add secret
	3)
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
		SECRET_ARY+=("$SECRET")
		#Add secret to config
		cd /etc/systemd/system || exit 2
		systemctl stop MTProxy
		GenerateService
		echo "$SERVICE_STR" >MTProxy.service
		systemctl daemon-reload
		systemctl start MTProxy
		cd /opt/MTProxy/objs/bin/ || exit 2
		SECRET_ARY_STR=${SECRET_ARY[*]}
		sed -i "s/^SECRET_ARY=.*/SECRET_ARY=($SECRET_ARY_STR)/" mtconfig.conf
		echo "Done"
		PUBLIC_IP="$(curl https://api.ipify.org -sS)"
		CURL_EXIT_STATUS=$?
		if [ $CURL_EXIT_STATUS -ne 0 ]; then
			PUBLIC_IP="YOUR_IP"
		fi
		echo
		echo "You can now connect to your server with this secret with this link:"
		echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=dd$SECRET"
		;;
	#Revoke Secret
	4)
		NUMBER_OF_SECRETS=${#SECRET_ARY[@]}
		if [ "$NUMBER_OF_SECRETS" -le 1 ]; then
			echo "Cannot remove the last secret."
			exit 1
		fi
		echo "Select a secret to revoke:"
		COUNTER=1
		for i in "${SECRET_ARY[@]}"; do
			echo "  $COUNTER) $i"
			COUNTER=$((COUNTER + 1))
		done
		read -r -p "Select a user by it's index to revoke: " USER_TO_REVOKE
		if ! [[ $USER_TO_REVOKE =~ $regex ]]; then
			echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
			exit 1
		fi
		if [ "$USER_TO_REVOKE" -lt 1 ] || [ "$USER_TO_REVOKE" -gt "$NUMBER_OF_SECRETS" ]; then
			echo "$(tput setaf 1)Error:$(tput sgr 0) Invalid number"
			exit 1
		fi
		USER_TO_REVOKE1=$((USER_TO_REVOKE - 1))
		SECRET_ARY=("${SECRET_ARY[@]:0:$USER_TO_REVOKE1}" "${SECRET_ARY[@]:$USER_TO_REVOKE}")
		cd /etc/systemd/system || exit 2
		systemctl stop MTProxy
		GenerateService
		echo "$SERVICE_STR" >MTProxy.service
		systemctl daemon-reload
		systemctl start MTProxy
		cd /opt/MTProxy/objs/bin/ || exit 2 || exit 2
		SECRET_ARY_STR=${SECRET_ARY[*]}
		sed -i "s/^SECRET_ARY=.*/SECRET_ARY=($SECRET_ARY_STR)/" mtconfig.conf
		echo "Done"
		;;	
	#Change CPU workers
	5)
		CPU_CORES=$(nproc --all)
		echo "I've detected that your server has $CPU_CORES cores. If you want I can configure proxy to run at all of your cores. This will make the proxy to spawn $CPU_CORES workers. For some reasons, proxy will most likely to fail at more than 16 cores. So please choose a number between 1 and 16."
		read -r -p "Who many workers you want proxy to spawn? " -e -i "$CPU_CORES" CPU_CORES
		if ! [[ $CPU_CORES =~ $regex ]]; then #Check if input is number
			echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
			exit 1
		fi
		if [ "$CPU_CORES" -lt 1 ]; then #Check range of workers
			echo "$(tput setaf 1)Error:$(tput sgr 0) Enter number more than 1."
			exit 1
		fi
		if [ "$CPU_CORES" -gt 16 ]; then
			echo "(tput setaf 3)Warning:$(tput sgr 0) Values more than 16 can cause some problems later. Proceed at your own risk."
		fi
		#Save
		cd /etc/systemd/system || exit 2
		systemctl stop MTProxy
		GenerateService
		echo "$SERVICE_STR" >MTProxy.service
		systemctl daemon-reload
		systemctl start MTProxy
		cd /opt/MTProxy/objs/bin/ || exit 2
		sed -i "s/^CPU_CORES=.*/CPU_CORES=$CPU_CORES/" mtconfig.conf
		echo "Done"
		;;
	#Change NAT types
	6)
		#Try to autodetect private ip: https://github.com/angristan/openvpn-install/blob/master/openvpn-install.sh#L230
		IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)
		HAVE_NAT="n"
		if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
			HAVE_NAT="y"
		fi
		read -r -p "Is your server behind NAT? (You probably need this if you are using AWS)(y/n) " -e -i "$HAVE_NAT" HAVE_NAT
		if [[ "$HAVE_NAT" == "y" || "$HAVE_NAT" == "Y" ]]; then
			PUBLIC_IP="$(curl https://api.ipify.org -sS)"
			read -r -p "Please enter your public IP: " -e -i "$PUBLIC_IP" PUBLIC_IP
			if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
				echo "I have detected that $IP is your private IP address. Please verify it."
			else
				IP=""
			fi
			read -r -p "Please enter your private IP: " -e -i "$IP" PRIVATE_IP
		fi
		cd /opt/MTProxy/objs/bin/ || exit 2
		sed -i "s/^HAVE_NAT=.*/HAVE_NAT=\"$HAVE_NAT\"/" mtconfig.conf
		sed -i "s/^PUBLIC_IP=.*/PUBLIC_IP=\"$PUBLIC_IP\"/" mtconfig.conf
		sed -i "s/^PRIVATE_IP=.*/PRIVATE_IP=\"$PRIVATE_IP\"/" mtconfig.conf
		echo "Done"
		;;
	#Change other args
	7)
		echo "If you want to use custom arguments to run the proxy enter them here; Otherwise just press enter."
		read -r -e -i "$CUSTOM_ARGS" CUSTOM_ARGS
		#Save
		cd /etc/systemd/system || exit 2
		systemctl stop MTProxy
		GenerateService
		echo "$SERVICE_STR" >MTProxy.service
		systemctl daemon-reload
		systemctl start MTProxy
		cd /opt/MTProxy/objs/bin/ || exit 2
		sed -i "s/^CUSTOM_ARGS=.*/CUSTOM_ARGS=\"$CUSTOM_ARGS\"/" mtconfig.conf
		echo "Done"
		;;
	#Firewall rules
	8)
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
	9)
		read -r -p "I still keep some packages like \"Development Tools\". Do want to uninstall MTProto-Proxy?(y/n) " OPTION
		case $OPTION in
		"y" | "Y")
			cd /opt/MTProxy || exit 2
			systemctl stop MTProxy
			systemctl disable MTProxy
			if [[ $distro =~ "CentOS" ]]; then
				firewall-cmd --remove-port="$PORT"/tcp
				firewall-cmd --runtime-to-permanent
			elif [[ $distro =~ "Ubuntu" ]]; then
				ufw delete allow "$PORT"/tcp
			elif [[ $distro =~ "Debian" ]]; then
				iptables -D INPUT -p tcp --dport "$PORT" --jump ACCEPT
				iptables-save >/etc/iptables/rules.v4
			fi
			rm -rf /opt/MTProxy /etc/systemd/system/MTProxy.service
			systemctl daemon-reload
			sed -i '\|cd /opt/MTProxy/objs/bin && bash updater.sh|d' /etc/crontab
			if [[ $distro =~ "CentOS" ]]; then
				systemctl restart crond
			elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
				systemctl restart cron
			fi
			echo "Ok it's done."
			;;
		esac
		;;
	esac
	exit
fi
SECRET_ARY=()
if [ "$#" -ge 2 ]; then
	AUTO=true
	# Parse arguments like: https://stackoverflow.com/4213397
	while [[ "$#" -gt 0 ]]; do
		case $1 in
			-s|--secret) SECRET_ARY+=("$2"); shift ;;
		 	-p|--port) PORT=$2; shift ;;
			-t|--tag) TAG=$2; shift ;;
			--workers) CPU_CORES=$2; shift ;;
			--disable-updater) ENABLE_UPDATER="n" ;;
			--tls) TLS_DOMAIN="$2"; shift ;;
			--custom-args) CUSTOM_ARGS="$2"; shift;;
			--no-nat) HAVE_NAT="n" ;;
			--no-bbr) ENABLE_BBR="n" ;;
		esac
		shift
	done
	#Check secret
	if [[ ${#SECRET_ARY[@]} -eq 0 ]];then
		echo "$(tput setaf 1)Error:$(tput sgr 0) Please enter at least one secret"
		exit 1
	fi
	for i in "${SECRET_ARY[@]}"; do
		if ! [[ $i =~ ^[0-9a-f]{32}$ ]]; then
			echo "$(tput setaf 1)Error:$(tput sgr 0) Enter hexadecimal characters and secret must be 32 characters. Error on secret $i"
			exit 1
		fi
	done
	#Check port
	if [ -z ${PORT+x} ]; then #Check random port
		GetRandomPort
		echo "I've selected $PORT as your port."
	fi
	if ! [[ $PORT =~ $regex ]]; then #Check if the port is valid
		echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
		exit 1
	fi
	if [ "$PORT" -gt 65535 ]; then
		echo "$(tput setaf 1)Error:$(tput sgr 0): Number must be less than 65536"
		exit 1
	fi
	#Check NAT
	if [[ "$HAVE_NAT" != "n" ]]; then
		PRIVATE_IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)
		PUBLIC_IP="$(curl https://api.ipify.org -sS)"
		HAVE_NAT="n"
		if echo "$PRIVATE_IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
			HAVE_NAT="y"
		fi
	fi
	#Check other stuff
	if [ -z ${CPU_CORES+x} ]; then CPU_CORES=$(nproc --all); fi
	if [ -z ${ENABLE_UPDATER+x} ]; then ENABLE_UPDATER="y"; fi
	if [ -z ${TLS_DOMAIN+x} ]; then TLS_DOMAIN="www.cloudflare.com"; fi
	if [ -z ${ENABLE_BBR+x} ]; then ENABLE_UPDATER="y"; fi
else
	#Variables
	SECRET=""
	TAG=""
	echo "Welcome to MTProto-Proxy auto installer!"
	echo "Created by Hirbod Behnam"
	echo "I will install mtprotoproxy, the official repository"
	echo "Source at https://github.com/TelegramMessenger/MTProxy"
	echo "Now I will gather some info from you..."
	echo ""
	echo ""
	#Proxy Port
	read -r -p "Select a port to proxy listen on it (-1 to randomize): " -e -i "443" PORT
	if [[ $PORT -eq -1 ]]; then #Check random port
		GetRandomPort
		echo "I've selected $PORT as your port."
	fi
	if ! [[ $PORT =~ $regex ]]; then #Check if the port is valid
		echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
		exit 1
	fi
	if [ "$PORT" -gt 65535 ]; then
		echo "$(tput setaf 1)Error:$(tput sgr 0): Number must be less than 65536"
		exit 1
	fi
	while true; do
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
		SECRET_ARY+=("$SECRET")
		read -r -p "Do you want to add another secret?(y/n) " -e -i "n" OPTION
		case $OPTION in
		'y' | "Y") ;;

		'n' | "N")
			break
			;;
		*)
			echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
			exit 1
			;;
		esac
	done
	#Now setup the tag
	read -r -p "Do you want to setup the advertising tag?(y/n) " -e -i "n" OPTION
	if [[ "$OPTION" == "y" || "$OPTION" == "Y" ]]; then
		echo "$(tput setaf 1)Note:$(tput sgr 0) Joined users and admins won't see the channel at very top."
		echo "On telegram, go to @MTProxybot Bot and enter this server's IP and $PORT as port. Then as secret enter $SECRET"
		echo "Bot will give you a string named TAG. Enter it here:"
		read -r TAG
	fi
	#Get CPU Cores
	CPU_CORES=$(nproc --all)
	echo "I've detected that your server has $CPU_CORES cores. If you want I can configure proxy to run at all of your cores. This will make the proxy to spawn $CPU_CORES workers. For some reasons, proxy will most likely to fail at more than 16 cores. So please choose a number between 1 and 16."
	read -r -p "How many workers you want proxy to spawn? " -e -i "$CPU_CORES" CPU_CORES
	if ! [[ $CPU_CORES =~ $regex ]]; then #Check if input is number
		echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
		exit 1
	fi
	if [ "$CPU_CORES" -lt 1 ]; then #Check range of workers
		echo "$(tput setaf 1)Error:$(tput sgr 0) Enter number more than 1."
		exit 1
	fi
	if [ "$CPU_CORES" -gt 16 ]; then
		echo "$(tput setaf 3)Warning:$(tput sgr 0) Values more than 16 can cause some problems later. Proceed at your own risk."
	fi
	#Secret and config updater
	read -r -p "Do you want to enable the automatic config updater? I will update \"proxy-secret\" and \"proxy-multi.conf\" each day at midnight(12:00 AM). It's recommended to enable this.[y/n] " -e -i "y" ENABLE_UPDATER
	#Change host mask
	read -r -p "Select a host that DPI thinks you are visiting (TLS_DOMAIN). Pass an empty string to disable Fake-TLS. Enabling this option will automaticly disable the 'dd' secrets: " -e -i "www.cloudflare.com" TLS_DOMAIN
	#Use nat status for proxies behind NAT
	#Try to autodetect private ip: https://github.com/angristan/openvpn-install/blob/master/openvpn-install.sh#L230
	IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)
	HAVE_NAT="n"
	if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
		HAVE_NAT="y"
	fi
	read -r -p "Is your server behind NAT? (You probably need this if you are using AWS)(y/n) " -e -i "$HAVE_NAT" HAVE_NAT
	if [[ "$HAVE_NAT" == "y" || "$HAVE_NAT" == "Y" ]]; then
		PUBLIC_IP="$(curl https://api.ipify.org -sS)"
		read -r -p "Please enter your public IP: " -e -i "$PUBLIC_IP" PUBLIC_IP
		if echo "$IP" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
			echo "I have detected that $IP is your private IP address. Please verify it."
		else
			IP=""
		fi
		read -r -p "Please enter your private IP: " -e -i "$IP" PRIVATE_IP
	fi
	#Other arguments
	echo "If you want to use custom arguments to run the proxy enter them here; Otherwise just press enter."
	read -r CUSTOM_ARGS
	#Install
	read -n 1 -s -r -p "Press any key to install..."
	clear
fi
#Now install packages
if [[ $distro =~ "CentOS" ]]; then
	yum -y install epel-release
	yum -y install openssl-devel zlib-devel curl ca-certificates sed cronie vim-common
	yum -y groupinstall "Development Tools"
elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
	apt-get update
	apt-get -y install git curl build-essential libssl-dev zlib1g-dev sed cron ca-certificates vim-common
fi
timedatectl set-ntp on #Make the time accurate by enabling ntp
#Clone and build
cd /opt || exit 2
git clone https://github.com/TelegramMessenger/MTProxy
cd MTProxy || exit 2
make            #Build the proxy
BUILD_STATUS=$? #Check if build was successful
if [ $BUILD_STATUS -ne 0 ]; then
	echo "$(tput setaf 1)Error:$(tput sgr 0) Build failed with exit code $BUILD_STATUS"
	echo "Deleting the project files..."
	rm -rf /opt/MTProxy
	echo "Done"
	exit 3
fi
cd objs/bin || exit 2
curl -s https://core.telegram.org/getProxySecret -o proxy-secret
STATUS_SECRET=$?
if [ $STATUS_SECRET -ne 0 ]; then
	echo "$(tput setaf 1)Error:$(tput sgr 0) Cannot download proxy-secret from Telegram servers."
fi
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
STATUS_SECRET=$?
if [ $STATUS_SECRET -ne 0 ]; then
	echo "$(tput setaf 1)Error:$(tput sgr 0) Cannot download proxy-multi.conf from Telegram servers."
fi
#Setup mtconfig.conf
echo "PORT=$PORT" >mtconfig.conf
echo "CPU_CORES=$CPU_CORES" >>mtconfig.conf
echo "SECRET_ARY=(${SECRET_ARY[*]})" >>mtconfig.conf
echo "TAG=\"$TAG\"" >>mtconfig.conf
echo "CUSTOM_ARGS=\"$CUSTOM_ARGS\"" >>mtconfig.conf
echo "TLS_DOMAIN=\"$TLS_DOMAIN\"" >>mtconfig.conf
echo "HAVE_NAT=\"$HAVE_NAT\"" >>mtconfig.conf
echo "PUBLIC_IP=\"$PUBLIC_IP\"" >>mtconfig.conf
echo "PRIVATE_IP=\"$PRIVATE_IP\"" >>mtconfig.conf
#Setup firewall
echo "Setting firewalld rules"
if [[ $distro =~ "CentOS" ]]; then
	SETFIREWALL=true
	if ! yum -q list installed firewalld &>/dev/null; then
		echo ""
		if [ "$AUTO" = true ]; then
			OPTION="y"
		else
			read -r -p "Looks like \"firewalld\" is not installed Do you want to install it?(y/n) " -e -i "y" OPTION
		fi
		case $OPTION in
		"y" | "Y")
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
		if [ "$AUTO" = true ]; then
			OPTION="y"
		else
			echo
			read -r -p "Looks like \"UFW\"(Firewall) is not installed Do you want to install it?(y/n) " -e -i "y" OPTION
		fi
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
		if [ "$AUTO" != true ]; then
			echo
			read -r -p "Do you want to use BBR? BBR might help your proxy run faster.(y/n) " -e -i "y" ENABLE_BBR
		fi
		case $ENABLE_BBR in
		"y" | "Y")
			echo 'net.core.default_qdisc=fq' | tee -a /etc/sysctl.conf
			echo 'net.ipv4.tcp_congestion_control=bbr' | tee -a /etc/sysctl.conf
			sysctl -p
			;;
		esac
	fi
elif [[ $distro =~ "Debian" ]]; then
	apt-get install -y iptables iptables-persistent
	iptables -A INPUT -p tcp --dport "$PORT" --jump ACCEPT
	iptables-save >/etc/iptables/rules.v4
fi
#Setup service files
cd /etc/systemd/system || exit 2
GenerateService
echo "$SERVICE_STR" >MTProxy.service
systemctl daemon-reload
systemctl start MTProxy
systemctl is-active --quiet MTProxy #Check if service is active
SERVICE_STATUS=$?
if [ $SERVICE_STATUS -ne 0 ]; then
	echo "$(tput setaf 3)Warning: $(tput sgr 0)Building looks successful but the sevice is not running."
	echo "Check status with \"systemctl status MTProxy\""
fi
systemctl enable MTProxy
#Setup cornjob
if [ "$ENABLE_UPDATER" = "y" ] || [ "$ENABLE_UPDATER" = "Y" ]; then
	echo '#!/bin/bash
systemctl stop MTProxy
cd /opt/MTProxy/objs/bin
curl -s https://core.telegram.org/getProxySecret -o proxy-secret1
STATUS_SECRET=$?
if [ $STATUS_SECRET -eq 0 ]; then
  cp proxy-secret1 proxy-secret
fi
rm proxy-secret1
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf1
STATUS_CONF=$?
if [ $STATUS_CONF -eq 0 ]; then
  cp proxy-multi.conf1 proxy-multi.conf
fi
rm proxy-multi.conf1
systemctl start MTProxy
echo "Updater runned at $(date). Exit codes of getProxySecret and getProxyConfig are $STATUS_SECRET and $STATUS_CONF" >> updater.log' >/opt/MTProxy/objs/bin/updater.sh
	echo "" >>/etc/crontab
	echo "0 0 * * * root cd /opt/MTProxy/objs/bin && bash updater.sh" >>/etc/crontab
	if [[ $distro =~ "CentOS" ]]; then
		systemctl restart crond
	elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
		systemctl restart cron
	fi
fi
#Show proxy links
tput setaf 3
printf "%$(tput cols)s" | tr ' ' '#'
tput sgr 0
echo "These are the links for proxy:"
PUBLIC_IP="$(curl https://api.ipify.org -sS)"
CURL_EXIT_STATUS=$?
[ $CURL_EXIT_STATUS -ne 0 ] && PUBLIC_IP="YOUR_IP"
HEX_DOMAIN=$(printf "%s" "$TLS_DOMAIN" | xxd -pu)
HEX_DOMAIN="$(echo $HEX_DOMAIN | tr '[A-Z]' '[a-z]')"
for i in "${SECRET_ARY[@]}"; do
	if [ -z "$TLS_DOMAIN" ]; then
		echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=dd$i"
	else
		echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=ee$i$HEX_DOMAIN"
	fi
done
