# MTProto Proxy CentOS 7 Auto Installer
A very small script to install MTProtoProxy On CentOS 7
## Why this installer?
* Generate random secret
* Automatically configure firewall
* Create a service to run it on background and start up
* Choose between Official Proxy and Python Proxy
* Easy to setup
* Revoke and add secrets after install
## Official Or Python Proxy?
Use python if:
1. Your server's CPU has one core or you want to run proxy on one core.
2. Your server is low-end.
3. You are serving a small group of people. (Like family or small company)
4. You want to disable to access users without random padding. [See here](#secure-only)
5. You also have another application or service running on your server. (Openvpn, shadowsocks, nginx or ...)

Otherwise, use official proxy.
#### Performance?
Python proxy says it can serve about 4000 concurrent connections with 1 CPU core (~2.5 GHz) and 1024MB RAM.

Official proxy can serve about 10000 to 16000 connections per core.
## Python Script
**Before You Begin**: Do not use OVH or IPHoster datacenters for MTProto.
### Install
On your server run
```bash
curl -o MTProtoProxyInstall.sh -L https://git.io/vhgUt && bash MTProtoProxyInstall.sh
```
Wait until the setup finishes, you should be given the links. (using `systemctl status mtprotoproxy -l` will display said links as well)

To update, uninstall, change port, revoke secret or... the proxy, run this script again.
#### Secure Only
You can enable random padding with adding a `dd` at the beginning of secret in Telegram client. [Read More](#random-padding) If you enable secure mode, server drops the connections that are not using the random padding.
#### Managing The Proxy
##### Service
Use `systemctl start mtprotoproxy` to start, `systemctl stop mtprotoproxy` to stop and `systemctl status mtprotoproxy -l` to see logs of script.
##### Config
To manually config, proxy edit config.py in /opt/mtprotoproxy to change the config; Then restart the server using `systemctl restart mtprotoproxy` or just run script again.
###### Installing Proxy's Master Branch
Should you want to test the stuff that are not available in the stable branch of [mtprotoproxy](https://github.com/alexbers/mtprotoproxy), pass `-m` as argument to script to install master branch.
```bash
curl -o MTProtoProxyInstall.sh -L https://git.io/vhgUt && bash MTProtoProxyInstall.sh -m
```
## Official Script
### Install
On your server run
```bash
curl -o MTProtoProxyOfficialInstall.sh -L https://git.io/fhEFY && bash MTProtoProxyOfficialInstall.sh
```
and wait until the setup finishes and you will see the links after install.
#### Workers
Each worker can handle more than 10000 connections on a modern CPU. Connections will be split between workers. Do not spawn workers more than your CPUs thread count.
#### Auto Install (Keyless)
You can use command below to automatically install MTProto proxy to without even pressing a key.
```bash
curl -o MTProtoProxyOfficialInstall.sh -L https://git.io/fhEFY && bash MTProtoProxyOfficialInstall.sh PORT STATS_PORT SECRET [TAG]
```
You can enter more than one secret by splitting secrets by `,`.

Example of using 443 as proxy port, generate random port for stats port, 00000000000000000000000000000000 and 0123456789abcdef0123456789abcdef as secrets , and empty tag:
```bash
curl -o MTProtoProxyOfficialInstall.sh -L https://git.io/fhEFY && bash MTProtoProxyOfficialInstall.sh 443 -1 00000000000000000000000000000000,0123456789abcdef0123456789abcdef
```
#### Managing The Proxy
##### Service
Use `systemctl start MTProxy` to start, `systemctl stop MTProxy` to stop and `systemctl status MTProxy -l` to see logs of script.
##### Config
The service file is saved in `/etc/systemd/system/MTProxy.service`. You can edit it manually. There is also a file named `mtconfig.conf` at `/opt/MTProxy/objs/bin` that is created by script. It’s used in loading proxy configs by script. *You must not delete this file* ,however, you can edit it. Also if you have enabled auto updater, you will have two other files named `updater.sh` and `updater.log`
###### Secure Only?
There is a pull request that will do it for you. See [here](https://github.com/TelegramMessenger/MTProxy/pull/248). Script will ask you if you want to enable random padding only or not.
## Other Information
### Firewall
Setup will try to configure the proxy on public zone. However you can manually enter these rules in case of any error or whatever. Just rerun the script and choose `Generate Firewalld Rules` and script will generate and apply firewall rules.
### Random Padding
Due to some ISPs detecting MTProxy by packet sizes, random padding is added to packets if such mode is enabled.
It's only enabled for clients which request it.
Add dd prefix to secret (cafe...babe => ddcafe...babe) to enable this mode on client side.
### Debian, Ubuntu or Windows?
It is possible to patch the script to make it *partly* compatible with Ubutnu/Debian. However for windows you cannot patch the script, but I've written a small guide to install that on Windows. Please read [wiki](https://github.com/HirbodBehnam/MTProtoProxyCentOSInstall/wiki) for more info. 
### Server
You can use any VPS or Dedicated Server. If you want a cheap and low-end server, I personally recommend to buy one at [Virmach](https://virmach.com/); They also accept cryptos!

If you live in Iran and you want to pay with IRR you can buy one at [Tikweb](https://tikweb.ir/) or [ParsHost](https://pars.host/).
#### Persian guide to buying servers, installing script and making servers censorship-resistant
***BEFORE YOU BEGIN***: If you are going to invest in MTProto and you are going to publish your proxy's link, I think you should just turn back. I believe MTProto Proxy is a failed project in Iran. Continue reading for more info. Utilizing this for self-use could significantly lessen the chance of your server's IP getting censored. *I don't say there is no way to make your server censorship-resistant, I just don't know them.* **Please do not contact me and ask me for other ways.**

More info about Iran censorship: It roughly takes 15 ~ 2 hours to block your new public and non-resistant server. If you route your traffic through a local server, it speed will be throttled in 3 hours ~ 2 days. (Normal VPS)

Iran _MAY_ use DPI to block your server. So private uses may not be safe too. I've written a [small guide](https://github.com/HirbodBehnam/MTProtoProxyCentOSInstall/wiki/Route-Traffic-Through-Domestic-Server-With-Shadowsocks) to route proxy with shadowsocks. It's good if you are using your proxy privately.

__I DO NOT USE MTPROTO PROXY MYSELF.__ Use [shadowsocks with Cloak](https://github.com/HirbodBehnam/Shadowsocks-Cloak-Installer)(**Highly Recommended**) or [wireguard](https://github.com/l-n-s/wireguard-install) or [openvpn](https://github.com/angristan/openvpn-install) instead.

(If you are from Iran, you may need to open this link with VPN)

http://www.mediafire.com/folder/3zcys4aw9v232/Guide
#### English guide to buying servers and installing script
https://www.reddit.com/r/Telegram/comments/95m5vi/how_to_deploy_mtproto_proxy_server_on_centos/
### Proxy Projects
[Python Proxy](https://github.com/alexbers/mtprotoproxy)

[Official C Proxy](https://github.com/TelegramMessenger/MTProxy)
### Donations
You can donate to me through bitcoin at `1XDgEkpnkJ7hC8Kwv5adfaDC1Z3FrkwsK`, Ethereum at `0xbb527a28B76235E1C125206B7CcFF944459b4894`, ZCash 
at `t1ZKYrYZCjxDYvo6mQaLZi3gNe2a6MydUo3` and Bitcoin Gold at `GcNgxfyR3nnAsD3Nhuckvq14sXYuDFkK9P`
