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
  if ! [ "$INSTALLED_LSOF" == true ];then 
    echo "Installing lsof package. Please wait."
    yum -y -q install lsof
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
#User must run the script as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root"
  exit 1
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
  echo "  6) Generate Firewalld Rules"
  echo "  7) Change Secure Mode"
  echo "  8) Change User Limits"
  echo "  *) Exit"
  read -r -p "Please enter a number: " OPTION
  case $OPTION in
    #Uninstall proxy
    1)
      read -r -p "I still keep some packages like python. Do want to uninstall MTProto-Proxy?(y/n) " OPTION
      OPTION="$(echo $OPTION | tr '[A-Z]' '[a-z]')"
      case $OPTION in
        "y")
          cd /opt/mtprotoproxy/ || exit 2
          PORT=$(python3.6 -c 'import config;print(getattr(config, "PORT",-1))')
          systemctl stop mtprotoproxy
          systemctl disable mtprotoproxy
          rm -rf /opt/mtprotoproxy
          rm -f /etc/systemd/system/mtprotoproxy.service
          systemctl daemon-reload
          firewall-cmd --remove-port="$PORT"/tcp
          firewall-cmd --runtime-to-permanent
          echo "Ok it's done."
          ;;
      esac
      ;;
    #Update
    2)
      cd /opt/mtprotoproxy/ || exit 2
      systemctl stop mtprotoproxy
      mv /opt/mtprotoproxy/config.py /tmp/config.py
      BRANCH=$(git rev-parse --abbrev-ref HEAD)
      git pull origin "$BRANCH"
      mv /tmp/config.py /opt/mtprotoproxy/config.py
      #Update cryptography and uvloop
      pip3.6 install --upgrade cryptography uvloop
      yum -y update #Update whole system
      systemctl start mtprotoproxy
      echo "Proxy updated."
      ;;
    #Change AD_TAG
    3)
      cd /opt/mtprotoproxy || exit 2
      TAG=$(python3.6 -c 'import config;print(getattr(config, "AD_TAG",""))')
      OldEmptyTag=false
      if [ -z "$TAG" ]; then
        OldEmptyTag=true
        echo "It looks like your AD TAG is empty. Get the AD TAG at https://t.me/mtproxybot and enter it here:"
      else
        echo "Current tag is $TAG. If you want to remove it, just press enter. Otherwise type the new TAG:"
      fi
      read -r TAG
      systemctl stop mtprotoproxy
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
      systemctl start mtprotoproxy
      echo "Done"
      ;;
    #Revoke secret
    4)
      echo "$(tput setaf 3)Just a second...$(tput sgr 0)"
      if ! yum -q list installed jq &>/dev/null; then
        read -r -p "In order to revoke a user I must install jq package. Continue?(y/n) " -e -i "y" OPTION
        case $OPTION in
          "y")
            yum -y install jq
            ;;
          *)
            exit 3
            ;;
        esac
      fi
      cd /opt/mtprotoproxy || exit 2
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
      SECRET=$(jq "del(.${SECRET_ARY[$USER_TO_REVOKE]})" tempSecrets.json)
      systemctl stop mtprotoproxy
      sed -i '/^USERS\s*=.*/ d' config.py #Remove USERS
      echo "" >> config.py
      echo "USERS = $SECRET" >> config.py
      sed -i '/^$/d' config.py #Remove empty lines
      systemctl start mtprotoproxy
      rm -f tempSecrets.json
      echo "Done"
      ;;
    #New secret
    5)
      cd /opt/mtprotoproxy || exit 2
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
      systemctl stop mtprotoproxy
      sed -i '/^USERS\s*=.*/ d' config.py #Remove USERS
      echo "" >> config.py
      echo "USERS = $SECRETS" >> config.py
      sed -i '/^$/d' config.py #Remove empty lines
      systemctl start mtprotoproxy
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
      ;;
    6)
      #Firewall rules
      cd /opt/mtprotoproxy/ || exit 2
      PORT=$(python3.6 -c 'import config;print(getattr(config, "PORT",-1))')
      echo "firewall-cmd --zone=public --add-port=$PORT/tcp"
      echo "firewall-cmd --runtime-to-permanent"
      read -r -p "Do you want to apply these rules?[y/n] " -e -i "y" OPTION
      if [ "$OPTION" == "y" ] || [ "$OPTION" == "Y" ] ; then
        firewall-cmd --zone=public --add-port="$PORT"/tcp
        firewall-cmd --runtime-to-permanent
      fi
      ;;
    7)
      #Change Secure only
      cd /opt/mtprotoproxy || exit 2
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
      systemctl stop mtprotoproxy
      sed -i '/^SECURE_ONLY\s*=.*/ d' config.py #Remove Secret_Only
      echo "" >> config.py
      echo "SECURE_ONLY = $SECURE_MODE" >> config.py
      sed -i '/^$/d' config.py #Remove empty lines
      systemctl start mtprotoproxy
      echo "Done"
      ;;
    8)
      echo "$(tput setaf 3)Make sure you installed master branch!$(tput sgr 0)"
      echo ""
      echo "Right now, you can edit limits by \"sudo nano /opt/mtprotoproxy/config.py\" and edit \"USER_MAX_TCP_CONNS\"."
      echo "It's better to multiply your preferred value by 5. Read more here: https://github.com/alexbers/mtprotoproxy/blob/master/mtprotoproxy.py#L48"
      echo "I will later add something in script." 
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
  if [ "$1" == "-m" ]; then
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
      #Multiply number of connections by 5. You can manualy change this. Read more: https://github.com/alexbers/mtprotoproxy/blob/master/mtprotoproxy.py#L48
      OPTION=$(expr "$OPTION" \* 5)
      LIMITER_CONFIG='"'
      LIMITER_CONFIG+=$USERNAME
      LIMITER_CONFIG+='": '
      LIMITER_CONFIG+=$OPTION
      LIMITER_CONFIG+=" , "
      ;;
    'n')
      ;;
    *)
      echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
      exit 1
  esac
  fi
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
LIMITER_CONFIG=${LIMITER_CONFIG::${#LIMITER_CONFIG}-2}
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
yum -y install epel-release
yum -y update
yum -y install sed git python36 curl ca-certificates
curl https://bootstrap.pypa.io/get-pip.py | python3.6
#This libs make proxy faster
pip3.6 install cryptography uvloop
if ! [ -d "/opt" ]; then
  mkdir /opt
fi
cd /opt || exit 2
if [ "$1" == "-m" ]; then
  git clone https://github.com/alexbers/mtprotoproxy.git
else
  git clone -b stable https://github.com/alexbers/mtprotoproxy.git
fi
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
#Setup firewall
echo "Setting firewalld rules"
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
  COUNTER=$COUNTER+1
done
