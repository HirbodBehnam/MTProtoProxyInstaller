# MTProto Proxy Auto Installer
A very small script to install MTProtoProxy On Centos or Ubuntu

**Using fake-tls protocol is highly advised**
## Why this installer?
* Generate random secret
* Automatically configure firewall
* Create a service to run it on background and start up
* Choose between Official Proxy, Python Proxy and Erlang Proxy
* Easy to setup
* Revoke and add secrets after install
* Supports Centos 7 or Ubuntu 16 or later and Debian 9 and 8
* Automatically configure NTP
* API Support [[Reference](https://github.com/HirbodBehnam/MTProtoProxyInstaller/wiki/API-For-Python-Script)]
## Official Or Python Proxy?
Use python if:
1. Your server's CPU has one core or you want to run proxy on one core.
2. Your server is low-end.
3. You are serving a small group of people. (Like family or small company)
4. You want to limit user connections.
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
curl -o MTProtoProxyInstall.sh -L https://git.io/fjo34 && bash MTProtoProxyInstall.sh
```
Wait until the setup finishes, you should be given the links. (using `systemctl status mtprotoproxy -l` will display said links as well)

To update, uninstall, change port, revoke secret or... the proxy, run this script again.
#### Managing The Proxy
##### Service
Use `systemctl start mtprotoproxy` to start, `systemctl stop mtprotoproxy` to stop and `systemctl status mtprotoproxy -l` to see logs of script.
##### Config
To manually config, proxy edit config.py in /opt/mtprotoproxy to change the config; Then restart the server using `systemctl restart mtprotoproxy` or just run script again.
### API
This script gives you post-install API support to control the proxy. [More Info](https://github.com/HirbodBehnam/MTProtoProxyInstaller/wiki/API-For-Python-Script)
## Official Script
**Before You Begin**: Do not use OVH or IPHoster datacenters for MTProto.
### Install
On your server run
```bash
curl -o MTProtoProxyOfficialInstall.sh -L https://git.io/fjo3u && bash MTProtoProxyOfficialInstall.sh
```
and wait until the setup finishes and you will see the links after install.
#### Workers
Each worker can handle more than 10000 connections on a modern CPU. Connections will be split between workers. Do not spawn workers more than your CPUs thread count.
#### Auto Install (Keyless)
You can use command below to automatically install MTProto proxy to without even pressing a key.
```bash
curl -o MTProtoProxyOfficialInstall.sh -L https://git.io/fjo3u && bash MTProtoProxyOfficialInstall.sh PORT SECRET [TAG]
```
You can enter more than one secret by splitting secrets by `,`.

Example of using 443 as proxy port, 00000000000000000000000000000000 and 0123456789abcdef0123456789abcdef as secrets , and empty tag:
```bash
curl -o MTProtoProxyOfficialInstall.sh -L https://git.io/fjo3u && bash MTProtoProxyOfficialInstall.sh 443 00000000000000000000000000000000,0123456789abcdef0123456789abcdef
```
#### Managing The Proxy
##### Service
Use `systemctl start MTProxy` to start, `systemctl stop MTProxy` to stop and `systemctl status MTProxy -l` to see logs of script.
##### Config
The service file is saved in `/etc/systemd/system/MTProxy.service`. You can edit it manually. There is also a file named `mtconfig.conf` at `/opt/MTProxy/objs/bin` that is created by script. It’s used in loading proxy configs by script. *You must not delete this file* ,however, you can edit it. Also if you have enabled auto updater, you will have two other files named `updater.sh` and `updater.log`
## Erlang Installer
Thanks to @seriyps creator of the [Erlang Proxy](https://github.com/seriyps/mtproto_proxy) you can now install the Erlang proxy with a script.

**Note:** This script works on Ubuntu 18/19 , Debian 9/10 and Centos 7.
```bash
curl -L -o mtp_install.sh https://git.io/fj5ru && bash mtp_install.sh
```
You can also just provide port/secret/ad-tag/protocols as command line arguments:
```bash
curl -L -o mtp_install.sh https://git.io/fj5ru && bash mtp_install.sh -p 443 -s d0d6e111bada5511fcce9584deadbeef -t dcbe8f1493fa4cd9ab300891c0b5b326 -a dd -a tls
```
## Other Information
### Firewall
Setup will try to configure the proxy on public zone. However you can manually enter these rules in case of any error or whatever. Just rerun the script and choose `Generate Firewalld Rules` and script will generate and apply firewall rules.
### Random Padding
Due to some ISPs detecting MTProxy by packet sizes, random padding is added to packets if such mode is enabled.
It's only enabled for clients which request it.
Add dd prefix to secret (cafe...babe => ddcafe...babe) to enable this mode on client side.

**DO NOT USE RANDOM PADDING AT THE MOMENT OR YOUR SERVER WILL BE LIKELY BLOCKED**
### Fake TLS
Fake TLS is a method that makes the proxy traffic look like TLS (something like websites traffic). In order to make your clients use it you have to share the specific link with them. The script will print it at the end. Fake-TLS links begins with `ee`.
### Quota Managment
I've written a small program in golang([link](https://github.com/HirbodBehnam/PortForwarder)) to forward traffic with quota managment. I've also written a guide [here](https://github.com/HirbodBehnam/MTProtoProxyInstaller/wiki/Quota-Management-For-Server) in order to configure it with MTProto. Right now it also supports the limiting the amount of _connections_ per port. [Persian Guild](http://www.mediafire.com/file/4u3khp5oj7ecgxk/%25D9%2585%25D8%25AD%25D8%25AF%25D9%2588%25D8%25AF_%25DA%25A9%25D8%25B1%25D8%25AF%25D9%2586_%25DA%25A9%25D8%25A7%25D8%25B1%25D8%25A8%25D8%25B1%25D8%25A7%25D9%2586.pdf/file)
### How to install on Windows?
I've written a small guide to install that on Windows. Please read [wiki](https://github.com/HirbodBehnam/MTProtoProxyInstaller/wiki) for more info.
### Server
You can use any VPS or Dedicated Server. If you want a cheap and low-end server, I personally recommend to buy one at [Virmach](https://virmach.com/); They also accept cryptos!

If you live in Iran and you want to pay with IRR you can buy one at [Tikweb](https://tikweb.ir/) or [ParsHost](https://pars.host/).
#### Persian guide to buying servers, installing script, making servers _nearly_ censorship-resistant, FAQ and QoS
___TL;DR___: It wont get blocked, unless your ip gets exposed.(You share the proxy in a channel or something like it) DPI cannot detect fake-tls.

At first let's talk about Fake-TLS mode.

So basically Fake TLS is here in order make the proxies censorship resistent. So does it makes it censorship-resistent? _Well yes but actually, no_.

Some of you guys tested it for me! And here are the results: Most likely, _Private Proxies_ do not get banned. Some guy told me that he had a private server with about 1k users and it's not blocked yet. So it looks like that it's undetectable by Iran's DPI.
But unfortunately, _Public Proxies_ are still getting blocked. It looks like (totally not sure) that they are using TL-Client bots (The users that are not users but they are bots; [example api](https://github.com/sochix/TLSharp)) are scanning the channels randomly for mtproto links and then they block it's IP. They usually get blocked in 2 hours.
If you are planing to sell mtproto, your server may got blocked if it is shared alot. You can plain tunnel it through a domestic server to make sure that your foreign server is safe.

You are still reading? Good. Because I have something for you: As I said before, Iran most likely uses bots to scan the channels to detect proxy links. So to counter this, I've written a small bot to protect the proxy links with a captcha. Here is the [link](https://github.com/HirbodBehnam/CaptchaBot). In this case bots can't access the links and unless people do not share it in other channels, they have to manually go and extract the link of proxy.

<details><summary>What it used to be</summary>

***BEFORE YOU BEGIN***: If you are going to invest in MTProto and you are going to publish your proxy's link, I think you should just turn back. I believe MTProto Proxy is a failed project in Iran. Continue reading for more info. Utilizing this for self-use could significantly lessen the chance of your server's IP getting censored. *I don't say there is no way to make your server censorship-resistant, I just don't know them.* **Please do not contact me and ask me for other ways.**

More info about Iran censorship: It roughly takes 15 ~ 2 hours to block your new public and non-resistant server. If you route your traffic through a local server, it speed will be throttled in 3 hours ~ 2 days. (Normal VPS)

Iran _MAY_ use DPI to block your server. So private uses may not be safe too. I've written a [small guide](https://github.com/HirbodBehnam/MTProtoProxyInstaller/wiki/Route-Traffic-Through-Domestic-Server) to route proxy with some programs from domestic servers. These methods are useful if you are using your proxy privately.

~~I DO NOT USE MTPROTO PROXY MYSELF~~ (Right now I'm using it with Fake-TLS and it's been a month that my server is not blocked yet) You can also use [shadowsocks with Cloak](https://github.com/HirbodBehnam/Shadowsocks-Cloak-Installer)(**Highly Recommended**) or [wireguard](https://github.com/l-n-s/wireguard-install) or [openvpn](https://github.com/angristan/openvpn-install) instead.
</details>
(If you are from Iran, you may need to open this link with VPN)

http://www.mediafire.com/folder/3zcys4aw9v232/Guide
#### English guide to buying servers and installing script
https://www.reddit.com/r/Telegram/comments/95m5vi/how_to_deploy_mtproto_proxy_server_on_centos/
### Proxy Projects
[Python Proxy](https://github.com/alexbers/mtprotoproxy)

[Official C Proxy](https://github.com/TelegramMessenger/MTProxy)

[Erlang Proxy](https://github.com/seriyps/mtproto_proxy)
### Donations
You can donate to me through bitcoin at `1XDgEkpnkJ7hC8Kwv5adfaDC1Z3FrkwsK`, Ethereum at `0xbb527a28B76235E1C125206B7CcFF944459b4894`, ZCash 
at `t1ZKYrYZCjxDYvo6mQaLZi3gNe2a6MydUo3` and Bitcoin Gold at `GcNgxfyR3nnAsD3Nhuckvq14sXYuDFkK9P`
