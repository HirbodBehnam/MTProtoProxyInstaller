# MTProto Proxy CentOS 7 Auto Installer
A very small script to install MTProtoProxy On CentOS 7
### Why this installer?
* Generate random secret
* Create a service to run it on background and start up
* Setup proxy with small knowledge
* Simple updater
* Revoke and add secrets after install
## Install
On your machine run
```
curl -o MTProtoProxyInstall.sh -L https://git.io/vhgUt && bash MTProtoProxyInstall.sh
```
and wait until the setup finishes the install you will see the links after install. (Or enter `systemctl status mtprotoproxy -l`) <br />
To update, uninstall, change port, revoke secret or... the proxy, run this script again. <br />
### Firewall
If you are using firewalld you can open the port you specified with this command. (Change 443 with port you specified)
```
firewall-cmd --zone=public --permanent --add-port=443/tcp
firewall-cmd --reload
```
### Random Padding
Due to some ISPs detecting MTProxy by packet sizes, random padding is added to packets if such mode is enabled.
It's only enabled for clients which request it.
Add dd prefix to secret (cafe...babe => ddcafe...babe) to enable this mode on client side.

To deny all connections but ones with random padding, set "Secure Mode" true. (Only works in master branch)
##### Install Master Branch
Run this:
```
wget https://git.io/vhgUt -O MTProtoProxyInstall.sh && bash MTProtoProxyInstall.sh -m
```
## Control The Proxy
### Service
Use `systemctl start mtprotoproxy` to start, `systemctl stop mtprotoproxy` to stop and `systemctl status mtprotoproxy` to see logs of script.
### Config
To manually config proxy edit config.py in /opt/mtprotoproxy to change the config. Then restart the server using `systemctl restart mtprotoproxy` or just run script again.
## Server
You can buy a server at [Virmach](https://virmach.com/) they also accept cryptos!
### Persian Guide To Buy Server and Install Script
http://www.mediafire.com/folder/3zcys4aw9v232/Guide
### English To Buy Server And Config It
https://www.reddit.com/r/Telegram/comments/95m5vi/how_to_deploy_mtproto_proxy_server_on_centos/
# Main Project
I only and only created a simple installer to install [this repo](https://github.com/alexbers/mtprotoproxy) on CentOS 7. Please report proxy related issues at [here](https://github.com/alexbers/mtprotoproxy/issues)
## Donate
You can donate me with bitcoin at `1XDgEkpnkJ7hC8Kwv5adfaDC1Z3FrkwsK`, Ethereum at `0xbb527a28B76235E1C125206B7CcFF944459b4894` and ZCash 
at `t1ZKYrYZCjxDYvo6mQaLZi3gNe2a6MydUo3`
