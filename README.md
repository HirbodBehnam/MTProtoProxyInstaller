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
wget https://git.io/vhgUt -O MTProtoProxyInstall.sh && bash MTProtoProxyInstall.sh
```
and wait until the setup finishes the install. <br />
Then enter `systemctl status mtprotoproxy -l` and you can see the proxy link there. (Usually the last line and it starts with tg://...) <br />
To update, uninstall, change port, revoke secret or... the proxy, run the script again. <br />
**Remember to open the port you specified in your firewall.**
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
# Main Project
I only and only created a simple installer to install [this repo](https://github.com/alexbers/mtprotoproxy) on CentOS 7. Please report proxy related issues at [here](https://github.com/alexbers/mtprotoproxy/issues)
## Donate
You can donate me with bitcoin at `1XDgEkpnkJ7hC8Kwv5adfaDC1Z3FrkwsK`, Ethereum at `0xbb527a28B76235E1C125206B7CcFF944459b4894` and ZCash 
at `t1ZKYrYZCjxDYvo6mQaLZi3gNe2a6MydUo3`
