#!/bin/bash
regex='^[0-9]+$'
# User must run the script as root
if [[ $EUID -ne 0 ]]; then
	echo "Please run this script as root"
	exit 1
fi
distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
# Get a random open port
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
# Get arch of system for downloading the executable
function GetArch(){
	arch=$(uname -m)
	case $arch in
	"i386" | "i686") ;;

	"x86_64")
		arch=2
		;;
	*)
		if [[ "$arch" =~ "armv" ]]; then
			arch=${arch:4:1}
			if [ "$arch" -gt 7 ]; then
				arch=4
			else
				arch=3
			fi
		else
			arch=0
		fi
		;;
	esac
	if [ "$arch" == "0" ]; then
		arch=1
		PrintWarning "Cannot automatically determine architecture."
	fi
	echo "1) 386"
	echo "2) amd64"
	echo "3) arm"
	echo "4) arm64"
	read -r -p "Select your architecture: " -e -i $arch arch
	case $arch in
	1)
		arch="386"
		;;
	2)
		arch="amd64"
		;;
	3)
		arch="arm"
		;;
	4)
		arch="arm64"
		;;
	*)
		echo "$(tput setaf 1)Error:$(tput sgr 0) Invalid option"
		exit 1
		;;
	esac
}
# Download the proxy
function DownloadProxy(){
	local url
	#url="https://github.com/9seconds/mtg/releases/download/v1.0.6/mtg-linux-$arch" <- Will be used if I want to lock the version
	url=$(wget -O - -o /dev/null https://api.github.com/repos/9seconds/mtg/releases/latest | grep "/mtg-linux-$arch" | grep -P 'https(.*)[^"]' -o)
	wget -O mtg "$url"
	chmod +x mtg
	mv mtg /usr/bin
}
# Get port from service file
function ParseService(){
	PORT=$(awk '/^Environment=MTG_BIND/ {split($1,a,":"); print(a[2])}' /etc/systemd/system/mtg.service)
	SECRET=$(grep "ExecStart=/usr/bin/mtg" /etc/systemd/system/mtg.service | cut -d\  -f3)
}
# Remove Trailing Whitespaces
function RemoveTrailingSpaces(){
	sed -i 's/ *$//' /etc/systemd/system/mtg.service
}
# Generate or get secret from user
function GetSecret(){
	echo "Do you want to set secret manually or shall I create a random secret?"
	echo "   1) Manually enter a secret"
	echo "   2) Create a random secret"
	read -r -p "Please select one [1-2]: " -e -i 2 OPTION
	case $OPTION in
	1)
		echo "Enter a 32 character string filled by 0-9 and a-f(hexadecimal): "
		read -r SECRET
		# Validate length
		SECRET=$(echo "$SECRET" | tr '[A-Z]' '[a-z]')
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
}
# Change the secret based on mode
function GetMode(){
	echo
	echo "1) Simple (Old school)"
	echo "2) Secured (Random padding)"
	echo "3) Fake TLS"
	read -r -p "What mode do you want to the proxy to run in? Select one: " -e -i "3" PROXY_MODE
	if [[ "$PROXY_MODE" == "2" ]]; then
		SECRET="dd$SECRET"
	elif [[ "$PROXY_MODE" == "3" ]]; then
		read -r -p "Select a host that DPI thinks you are visiting: " -e -i "www.cloudflare.com" TLS_DOMAIN
		TLS_DOMAIN=$(hexdump -v -e ' /1 "%02x"' <<< "$TLS_DOMAIN") # Convert to hex for secret
		SECRET="ee$SECRET$TLS_DOMAIN"
	fi
}
# Get the link for proxy
function GetLink(){
	ParseService
	PUBLIC_IP="$(curl https://api.ipify.org -sS)"
	CURL_EXIT_STATUS=$?
	[ $CURL_EXIT_STATUS -ne 0 ] && PUBLIC_IP="YOUR_IP"
	echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$SECRET"
}
clear
if [ -f "/usr/bin/mtg" ]; then
	echo "You have already installed MTProtoProxy! What do you want to do?"
	echo "  1) View connection link"
	echo "  2) Upgrade proxy software"
	echo "  3) Change AD TAG"
	echo "  4) Change secret"
	echo "  5) Generate firewall rules"
	echo "  6) Uninstall Proxy"
	echo "  *) Exit"
	read -r -p "Please enter a number: " OPTION
	case $OPTION in
	# View connection links
	1)
		GetLink
		;;
	# Upgrade proxy
	2)
		GetArch
		DownloadProxy
		systemctl restart mtg
		echo "Done"
		;;
	# Change AD TAG
	3)
		read -r -p "Please enter the new TAG. Press enter in order to remove tag: " TAG
		RemoveTrailingSpaces
		WORDS_EXE_LINE=$(grep "ExecStart=/usr/bin/mtg" /etc/systemd/system/mtg.service | wc -w)
		for (( ; WORDS_EXE_LINE>3; WORDS_EXE_LINE-- )); do
			sed -i "/ExecStart=\/usr\/bin\/mtg/s/\w*$//" /etc/systemd/system/mtg.service
		done
		RemoveTrailingSpaces
		sed -i "/ExecStart=\/usr\/bin\/mtg/s/$/ $TAG/" /etc/systemd/system/mtg.service
		systemctl daemon-reload
		systemctl restart mtg
		echo "Done"
		;;
	# Change secret
	4)
		RemoveTrailingSpaces
		GetSecret
		GetMode
		SECRET_OLD=$(grep "ExecStart=/usr/bin/mtg" /etc/systemd/system/mtg.service | cut -d\  -f3)
		sed -i "0,/$SECRET_OLD/s//$SECRET/" /etc/systemd/system/mtg.service
		systemctl daemon-reload
		systemctl restart mtg
		GetLink
		;;
	# Generate firewall rules
	5)
		ParseService
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
	# Uninstall proxy
	6)
		read -r -p "Do want to uninstall MTG?(y/n) " OPTION
		if [[ "$OPTION" == "y" || "$OPTION" == "Y" ]]; then
			ParseService # Get port for firewall
			systemctl stop mtg
			systemctl disable mtg
			rm -f /etc/systemd/system/mtg.service /usr/bin/mtg
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
			echo "Done"
		fi
		;;
	esac
	exit
fi
echo "Welcome to MTG auto installer!"
echo "Created by Hirbod Behnam"
echo "I will install mtg proxy by 9seconds"
echo "Source at https://github.com/9seconds/mtg"
echo "Now I will gather some info from you."
echo ""
echo ""
# Get port
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
# Get secret
GetSecret
# Setup the tag
read -r -p "Do you want to setup the advertising tag?(y/n) " -e -i "n" OPTION
if [[ "$OPTION" == "y" || "$OPTION" == "Y" ]]; then
	echo "$(tput setaf 1)Note:$(tput sgr 0) Joined users and admins won't see the channel at very top."
	echo "On telegram, go to @MTProxybot Bot and enter this server's IP and $PORT as port. Then as secret enter $SECRET"
	echo "Bot will give you a string named TAG. Enter it here:"
	read -r TAG
fi
# Get Mode
GetMode
# Check arch
GetArch
read -n 1 -s -r -p "Press any key to install..."
clear
# Install some small programs for script (The proxy itself does not require any specific program)
if [[ $distro =~ "CentOS" ]]; then
	yum -y install epel-release
	yum -y install ca-certificates sed grep wget
elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
	apt-get update
	apt-get -y install ca-certificates sed grep wget
fi
# Download latest executable
DownloadProxy
# Make a service
echo "[Unit]
Description=MTG Proxy Service
After=network-online.target
Wants=network-online.target

[Service]
Environment=MTG_BIND=0.0.0.0:$PORT
Type=simple
User=root
Group=root
ExecStart=/usr/bin/mtg run $SECRET $TAG

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/mtg.service
systemctl daemon-reload
systemctl start mtg
systemctl enable mtg
# Setup firewall
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
	# Use BBR on user will
	if ! [ "$(sysctl -n net.ipv4.tcp_congestion_control)" = "bbr" ]; then
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
# Show links
GetLink