#!/bin/bash
function RemoveMultiLineUser(){
  local SECRET_T
  SECRET_T=$(python3.6 -c 'import config;print(getattr(config, "USERS",""))')
  SECRET_T=$(echo "$SECRET_T" | tr "'" '"')
  python3.6 -c "import re;f = open('config.py', 'r');s = f.read();p = re.compile('USERS\\s*=\\s*\\{.*?\\}', re.DOTALL);nonBracketedString = p.sub('', s);f = open('config.py', 'w');f.write(nonBracketedString)"
  echo "" >> config.py
  echo "USERS = $SECRET_T" >> config.py
}
function GetRandomPort(){
  if ! [ "$INSTALLED_LSOF" == true ]; then
    echo "Installing lsof package. Please wait."
    if [[ $distro =~ "CentOS" ]]; then
      yum -y -q install lsof
    elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
      apt-get -y install lsof > /dev/null
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
  if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
    GetRandomPort
  fi
}
function GenerateConnectionLimiterConfig(){
  LIMITER_CONFIG=""
  LIMITER_FILE=""
  for user in "${!limits[@]}"
  do
    LIMITER_CONFIG+='"'
    LIMITER_CONFIG+=$user
    LIMITER_CONFIG+='": '
    LIMITER_CONFIG+=${limits[$user]}
    LIMITER_CONFIG+=" , "
    LIMITER_FILE+="$user;${limits[$user]}\n"
  done
  LIMITER_CONFIG=${LIMITER_CONFIG::${#LIMITER_CONFIG}-2}
}
#User must run the script as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root"
  exit 1
fi
distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
clear
#Check if user already installed Proxy
if [ -d "/opt/mtprotoproxy" ]; then
  echo "You have already installed MTProtoProxy! What do you want to do?"
  echo "  1) View all connection links"
  echo "  2) Upgrade proxy software"
  echo "  3) Change AD TAG"
  echo "  4) Add a secret"
  echo "  5) Revoke a secret"
  echo "  6) Change user connection limits"
  echo "  7) Generate firewall rules"
  echo "  8) Change secure mode"
  echo "  9) Uninstall Proxy"
  echo "  *) Exit"
  read -r -p "Please enter a number: " OPTION
  cd /opt/mtprotoproxy/ || exit 2
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
      rm -f tempSecrets.json
      PORT=$(python3.6 -c 'import config;print(getattr(config, "PORT",-1))')
      SECRET=$(python3.6 -c 'import config;print(getattr(config, "USERS",""))')
      SECRET_COUNT=$(python3.6 -c 'import config;print(len(getattr(config, "USERS","")))')
      if [ "$SECRET_COUNT" == "0" ] ; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) You have no secrets. Cannot show nothing!"
        exit 4
      fi
      RemoveMultiLineUser #Regenerate USERS only in one line
      SECRET=$(echo "$SECRET" | tr "'" '"')
      echo "$SECRET" >> tempSecrets.json
      SECRET_ARY=()
      mapfile -t SECRET_ARY < <(jq -r 'keys[]' tempSecrets.json)
      for user in "${SECRET_ARY[@]}"
      do
        SECRET=$(jq --arg u "$user" -r '.[$u]' tempSecrets.json)
        echo "$user: tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=dd$SECRET"
        s=$(python3.6 -c "print(\"ee\" + \"$SECRET\" + \"google.com\".encode().hex())")
        #s="${s::-1}"
        #s="${s:2}"
        echo "$user: tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$s (Fake-TLS)"
        echo
      done
      sed -i '/^$/d' config.py #Remove empty lines
      rm -f tempSecrets.json
      ;;
    #Update
    2)
      systemctl stop mtprotoproxy
      mv /opt/mtprotoproxy/config.py /tmp/config.py
      git pull
      mv /tmp/config.py /opt/mtprotoproxy/config.py
      #Update cryptography and uvloop
      pip3.6 install --upgrade cryptography uvloop
      systemctl start mtprotoproxy
      echo "Proxy updated."
      ;;
    #Change AD_TAG
    3)
      TAG=$(python3.6 -c 'import config;print(getattr(config, "AD_TAG",""))')
      OldEmptyTag=false
      if [ -z "$TAG" ]; then
        OldEmptyTag=true
        echo "It looks like your AD TAG is empty. Get the AD TAG at https://t.me/mtproxybot and enter it here:"
      else
        echo "Current tag is $TAG. If you want to remove it, just press enter. Otherwise type the new TAG:"
      fi
      read -r TAG
      if ! [ -z "$TAG" ] && [ "$OldEmptyTag" = true ]; then
        #This adds the AD_TAG to end of file
        echo "" >> config.py #Adds a new line
        TAGTEMP="AD_TAG = "
        TAGTEMP+='"'
        TAGTEMP+="$TAG"
        TAGTEMP+='"'
        echo "$TAGTEMP" >> config.py
      elif ! [ -z "$TAG" ] && [ "$OldEmptyTag" = false ]; then
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
      pid=$(systemctl show --property MainPID --value mtprotoproxy)
      kill -USR2 "$pid"
      echo "Done"
      ;;
    #New secret
    4)
      SECRETS=$(python3.6 -c 'import config;print(getattr(config, "USERS","{}"))')
      SECRET_COUNT=$(python3.6 -c 'import config;print(len(getattr(config, "USERS","")))')
      SECRETS=$(echo "$SECRETS" | tr "'" '"')
      SECRETS="${SECRETS: : -1}" #Remove last char "}" here
      read -r -p "Ok now please enter the username: " -e -i "NewUser" NEW_USR
      echo "Do you want to set secret manually or shall I create a random secret?"
      echo "   1) Manually enter a secret"
      echo "   2) Create a random secret"
      read -r -p "Please select one [1-2]: " -e -i 2 OPTION
      case $OPTION in
        1)
          echo "Enter a 32 character string filled by 0-9 and a-f: "
          read -r SECRET
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
      RemoveMultiLineUser #Regenerate USERS only in one line
      if [ "$SECRET_COUNT" -ne 0 ] ; then
        SECRETS+=','
      fi
      SECRETS+='"'
      SECRETS+="$NEW_USR"
      SECRETS+='": "'
      SECRETS+="$SECRET"
      SECRETS+='"}'
      sed -i '/^USERS\s*=.*/ d' config.py #Remove USERS
      echo "" >> config.py
      echo "USERS = $SECRETS" >> config.py
      sed -i '/^$/d' config.py #Remove empty lines
      pid=$(systemctl show --property MainPID --value mtprotoproxy)
      kill -USR2 "$pid"
      echo "Done"
      PUBLIC_IP="$(curl https://api.ipify.org -sS)"
      CURL_EXIT_STATUS=$?
      if [ $CURL_EXIT_STATUS -ne 0 ]; then
        PUBLIC_IP="YOUR_IP"
      fi
      PORT=$(python3.6 -c 'import config;print(getattr(config, "PORT",-1))')
      echo
      echo "You can now connect to your server with this secret with this link:"
      echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=dd$SECRET"
      s=$(python3.6 -c "print(\"ee\" + \"$SECRET\" + \"google.com\".encode().hex())")
      #s="${s::-1}"
      #s="${s:2}"
      echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$s (Fake-TLS)"
      ;;
    #Revoke secret
    5)
      clear
      rm -f tempSecrets.json
      SECRET=$(python3.6 -c 'import config;print(getattr(config, "USERS",""))')
      SECRET_COUNT=$(python3.6 -c 'import config;print(len(getattr(config, "USERS","")))')
      if [ "$SECRET_COUNT" == "0" ] ; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) You have no secrets. Cannot revoke nothing!"
        exit 4
      fi
      RemoveMultiLineUser #Regenerate USERS only in one line
      SECRET=$(echo "$SECRET" | tr "'" '"')
      echo "$SECRET" >> tempSecrets.json
      SECRET_ARY=()
      mapfile -t SECRET_ARY < <(jq -r 'keys[]' tempSecrets.json)
      echo "Here are list of current users:"
      COUNTER=1
      NUMBER_OF_SECRETS=${#SECRET_ARY[@]}
      for i in "${SECRET_ARY[@]}"
      do
        echo "	$COUNTER) $i"
        COUNTER=$((COUNTER+1))
      done
      read -r -p "Please select a user by it's index to revoke: " USER_TO_REVOKE
      regex='^[0-9]+$'
      if ! [[ $USER_TO_REVOKE =~ $regex ]] ; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
        exit 1
      fi
      if [ "$USER_TO_REVOKE" -lt 1 ] || [ "$USER_TO_REVOKE" -gt "$NUMBER_OF_SECRETS" ]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) Invalid number"
        exit 1
      fi
      USER_TO_REVOKE=$((USER_TO_REVOKE-1))
      SECRET=$(jq --arg u "${SECRET_ARY[$USER_TO_REVOKE]}" 'del(.[$u])' tempSecrets.json)
      sed -i '/^USERS\s*=.*/ d' config.py #Remove USERS
      echo "" >> config.py
      echo "USERS = $SECRET" >> config.py
      sed -i '/^$/d' config.py #Remove empty lines
      pid=$(systemctl show --property MainPID --value mtprotoproxy)
      kill -USR2 "$pid"
      rm -f tempSecrets.json
      echo "Done"
      ;;
    #User limits
    6)
      clear
      rm -f tempSecrets.json
      SECRET=$(python3.6 -c 'import config;print(getattr(config, "USERS",""))')
      SECRET_COUNT=$(python3.6 -c 'import config;print(len(getattr(config, "USERS","")))')
      if [ "$SECRET_COUNT" == "0" ] ; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) You have no secrets. Cannot limit nothing!"
        exit 4
      fi
      RemoveMultiLineUser #Regenerate USERS only in one line
      SECRET=$(echo "$SECRET" | tr "'" '"')
      echo "$SECRET" >> tempSecrets.json
      SECRET_ARY=()
      mapfile -t SECRET_ARY < <(jq -r 'keys[]' tempSecrets.json)
      echo "Here are list of current users:"
      COUNTER=1
      NUMBER_OF_SECRETS=${#SECRET_ARY[@]}
      for i in "${SECRET_ARY[@]}"
      do
        echo "	$COUNTER) $i"
        COUNTER=$((COUNTER+1))
      done
      read -r -p "Please select a user by it's index to change the limits: " USER_TO_LIMIT
      regex='^[0-9]+$'
      if ! [[ $USER_TO_LIMIT =~ $regex ]] ; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
        exit 1
      fi
      if [ "$USER_TO_LIMIT" -lt 1 ] || [ "$USER_TO_LIMIT" -gt "$NUMBER_OF_SECRETS" ]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) Invalid number"
        exit 1
      fi
      USER_TO_LIMIT=$((USER_TO_LIMIT-1))
      KEY=${SECRET_ARY[$USER_TO_LIMIT]}
      declare -A limits
      while IFS= read -r line
      do
        if [ "$line" != "" ]; then
          arrIN=(${line//;/ })
          limits+=( ["${arrIN[0]}"]="${arrIN[1]}")
        fi
      done < "limits_bash.txt"
      if [ ${limits[$KEY]+abc} ]; then
        MAX_USER=$((${limits[$KEY]} / 5))
        echo "Current limit is $MAX_USER concurrent users. (${limits[$KEY]} connections)"
      else
        echo "This user have no restrictions."
      fi
      read -r -p "Please enter the max users that you want to connect to this user; Enter 0 for unlimited.: " MAX_USER
      regex='^[0-9]+$'
      if ! [[ $MAX_USER =~ $regex ]] ; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
        exit 1
      fi
      MAX_USER=$((MAX_USER * 5))
      if [ "$MAX_USER" = "0" ]; then
        unset limits["$KEY"]
      else
        limits[$KEY]=$MAX_USER
      fi
      GenerateConnectionLimiterConfig
      rm limits_bash.txt
      echo -e "$LIMITER_FILE" >> "limits_bash.txt" 
      sed -i '/^USER_MAX_TCP_CONNS\s*=.*/ d' config.py #Remove settings
      echo "" >> config.py
      echo "USER_MAX_TCP_CONNS = { $LIMITER_CONFIG }" >> config.py
      sed -i '/^$/d' config.py #Remove empty lines
      pid=$(systemctl show --property MainPID --value mtprotoproxy)
      kill -USR2 "$pid"
      echo "Done"
    ;;
    7)
      #Firewall rules
      PORT=$(python3.6 -c 'import config;print(getattr(config, "PORT",-1))')
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
      if [ "$OPTION" == "y" ] || [ "$OPTION" == "Y" ] ; then
        if [[ $distro =~ "CentOS" ]]; then
          firewall-cmd --zone=public --add-port="$PORT"/tcp
          firewall-cmd --runtime-to-permanent
        elif [[ $distro =~ "Ubuntu" ]]; then
          ufw allow "$PORT"/tcp
        elif [[ $distro =~ "Debian" ]]; then
          iptables -A INPUT -p tcp --dport "$PORT" --jump ACCEPT
          iptables-save > /etc/iptables/rules.v4  
        fi
      fi
      ;;
    8)
      #Change Secure only
      read -r -p "Enable \"Secure Only Mode\"? If yes, only connections with random padding enabled are accepted.(y/n) " -e -i "y" OPTION
      OPTION="$(echo $OPTION | tr '[A-Z]' '[a-z]')"
      case $OPTION in
        'y')
          SECURE_MODE="True"
          ;;
        'n')
          SECURE_MODE="False"
          ;;
        *)
          echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
          exit 1
      esac
      sed -i '/^SECURE_ONLY\s*=.*/ d' config.py #Remove Secret_Only
      echo "" >> config.py
      echo "SECURE_ONLY = $SECURE_MODE" >> config.py
      sed -i '/^$/d' config.py #Remove empty lines
      pid=$(systemctl show --property MainPID --value mtprotoproxy)
      kill -USR2 "$pid"
      echo "Done"
      ;;
    #Uninstall proxy
    9)
      read -r -p "I still keep some packages like python. Do want to uninstall MTProto-Proxy?(y/n) " OPTION
      OPTION="$(echo $OPTION | tr '[A-Z]' '[a-z]')"
      case $OPTION in
        "y")
          PORT=$(python3.6 -c 'import config;print(getattr(config, "PORT",-1))')
          systemctl stop mtprotoproxy
          systemctl disable mtprotoproxy
          rm -rf /opt/mtprotoproxy
          rm -f /etc/systemd/system/mtprotoproxy.service
          systemctl daemon-reload
          if [[ $distro =~ "CentOS" ]]; then
            firewall-cmd --remove-port="$PORT"/tcp
            firewall-cmd --runtime-to-permanent
          elif [[ $distro =~ "Ubuntu" ]]; then
            ufw delete allow "$PORT"/tcp
          elif [[ $distro =~ "Debian" ]]; then
            iptables -D INPUT -p tcp --dport "$PORT" --jump ACCEPT
            iptables-save > /etc/iptables/rules.v4
          fi
          echo "Ok it's done."
          ;;
      esac
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
read -r -p "Select a port to proxy listen on it (-1 to randomize): " -e -i "-1" PORT
if [[ $PORT -eq -1 ]] ; then
  GetRandomPort
  echo "I've selected $PORT as your port."
fi
#Lets check if the PORT is valid
if ! [[ $PORT =~ $regex ]] ; then
  echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
  exit 1
fi
if [ "$PORT" -gt 65535 ] ; then
  echo "$(tput setaf 1)Error:$(tput sgr 0): Number must be less than 65536"
  exit 1
fi
#Now the username and secrets
declare -A limits
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
      if ! [[ $OPTION =~ $regex ]] ; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
        exit 1
      fi
      #Multiply number of connections by 5. You can manualy change this. Read more: https://github.com/alexbers/mtprotoproxy/blob/master/mtprotoproxy.py#L128
      OPTION=$((OPTION * 5))
      limits+=( ["$USERNAME"]="$OPTION")
      ;;
    'n')
      ;;
    *)
      echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
      exit 1
  esac
  read -r -p "Do you want to add another secret?(y/n) " -e -i "n" OPTION
  OPTION="$(echo $OPTION | tr '[A-Z]' '[a-z]')"
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
if [ ${#limits[@]} -gt 0 ]; then
  GenerateConnectionLimiterConfig
fi
#Set secure mode
read -r -p "Enable \"Secure Only Mode\"? If yes, only connections with random padding enabled are accepted.(y/n) " -e -i "y" OPTION
OPTION="$(echo $OPTION | tr '[A-Z]' '[a-z]')"
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
read -r -p "Do you want to setup the advertising tag?(y/n) " -e -i "n" OPTION
OPTION="$(echo $OPTION | tr '[A-Z]' '[a-z]')"
case $OPTION in
  'y')
    echo "$(tput setaf 1)Note:$(tput sgr 0) Joined users and admins won't see the channel at very top."
    echo "On telegram, go to @MTProxybot Bot and enter this server's IP and $PORT as port. Then as secret enter $SECRET"
    echo "$(tput setaf 3)Also make sure server time is precise, otherwise the proxy may not work when AG is set.$(tput sgr 0) You may need to use ntp to sync your system time."
    echo "Bot will give you a string named TAG. Enter it here:"
    read -r TAG
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
if [[ $distro =~ "CentOS" ]]; then
  yum -y install epel-release
  yum -y update
  yum -y install sed git python36 curl ca-certificates jq ntp
elif [[ $distro =~ "Ubuntu" ]]; then
  apt update
  if ! [[ $(lsb_release -r -s) =~ "17" ]] && ! [[ $(lsb_release -r -s) =~ "18" ]] && ! [[ $(lsb_release -r -s) =~ "19" ]]; then 
    apt-get -y install software-properties-common python-software-properties
    add-apt-repository ppa:jonathonf/python-3.6
  fi
  apt-get update
  apt-get -y install python3.6 python3.6-distutils sed git curl jq ca-certificates ntp
elif [[ $distro =~ "Debian" ]]; then
  apt-get update
  apt-get install -y jq ca-certificates iptables-persistent iptables git sed curl wget ntp
  if ! command -v "python3.6" >/dev/null ; then
    apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev #python packages
    #Download and install python 3.6.9
    cd /tmp || exit 2
    curl -o Python-3.6.9.tar.xz https://www.python.org/ftp/python/3.6.9/Python-3.6.9.tar.xz
    tar xvf Python-3.6.9.tar.xz
    cd Python-3.6.9 || exit 2
    ./configure --enable-optimizations
    make -j8
    make altinstall
    ln -s /usr/local/bin/python3.6 /usr/bin/python3.6
  fi
  if ! [ -f "/usr/local/bin/python3.6" ]; then #in case user had python3.6
    ln -s /usr/local/bin/python3.6 /usr/bin/python3.6
  fi
  #Firewall
  iptables -A INPUT -p tcp --dport "$PORT" --jump ACCEPT
  iptables-save > /etc/iptables/rules.v4
else
  echo "Your OS is not supported"
  exit 2
fi
#Start NTP
if [[ $distro =~ "CentOS" ]]; then
  systemctl start ntpd
  systemctl enable ntpd
else
  systemctl start ntp
  systemctl enable ntp
fi
#Install pip
curl https://bootstrap.pypa.io/get-pip.py | python3.6
#This libs make proxy faster
pip3.6 install cryptography uvloop
if ! [ -d "/opt" ]; then
  mkdir /opt
fi
cd /opt || exit 2
git clone https://github.com/alexbers/mtprotoproxy.git
cd mtprotoproxy || exit 2
#Now edit the config file
rm -f config.py
touch config.py
chmod 0777 config.py
echo "PORT = $PORT
USERS = { $SECRETS }
USER_MAX_TCP_CONNS = { $LIMITER_CONFIG }
">> config.py
if ! [ -z "$TAG" ]; then
  TAGTEMP="AD_TAG = "
  TAGTEMP+='"'
  TAGTEMP+="$TAG"
  TAGTEMP+='"'
  echo "$TAGTEMP" >> config.py
fi
if [ "$SECURE_MODE" = true ]; then
  echo "SECURE_ONLY = True" >> config.py
fi
echo -e "$LIMITER_FILE" >> "limits_bash.txt" 
#Setup firewall
echo "Setting firewalld rules"
if [[ $distro =~ "CentOS" ]]; then
  SETFIREWALL=true
  if ! yum -q list installed firewalld &>/dev/null; then
    echo ""
    read -r -p "Looks like \"firewalld\" is not installed Do you want to install it?(y/n) " -e -i "y" OPTION
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
    read -r -p "Looks like \"UFW\"(Firewall) is not installed Do you want to install it?(y/n) " -e -i "y" OPTION
    case $OPTION in
      "y"|"Y")
        apt-get install ufw
        ufw enable
        ufw allow ssh
        ufw allow "$PORT"/tcp
      ;;
    esac
  fi
fi
#Now lets create the service
cd /etc/systemd/system || exit 2
touch mtprotoproxy.service
echo "[Unit]
Description = MTProto Proxy Service
After=network.target

[Service]
Type = simple
ExecStart = /usr/bin/python3.6 /opt/mtprotoproxy/mtprotoproxy.py
StartLimitBurst=0

[Install]
WantedBy = multi-user.target" >> mtprotoproxy.service
systemctl daemon-reload
systemctl enable mtprotoproxy
systemctl start mtprotoproxy
tput setaf 3
printf "%`tput cols`s"|tr ' ' '#'
tput sgr 0
echo "Ok it must be done. I created a service to run or stop the proxy."
echo 'Use "systemctl start mtprotoproxy" or "systemctl stop mtprotoproxy" to start or stop it'
echo
echo "Use these links to connect to your proxy (With random padding):"
PUBLIC_IP="$(curl https://api.ipify.org -sS)"
CURL_EXIT_STATUS=$?
if [ $CURL_EXIT_STATUS -ne 0 ]; then
  PUBLIC_IP="YOUR_IP"
fi
COUNTER=0
for i in "${SECRET_END_ARY[@]}"
do
  echo "${USERNAME_END_ARY[$COUNTER]}: tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=dd$i"
  s=$(python3.6 -c "print(\"ee\" + \"$SECRET\" + \"google.com\".encode().hex())")
  #s="${s::-1}"
  #s="${s:2}"
  echo "${USERNAME_END_ARY[$COUNTER]}: tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$s (Fake-TLS)"
  COUNTER=$COUNTER+1
done
