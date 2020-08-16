# MTProto Proxy Auto Installer
A very small script to install MTProtoProxy On Centos or Ubuntu

## Why this installer?
* Generate random secret
* Automatically configure firewall
* Create a service to run it on background and start up
* Choose between Official Proxy, Python Proxy and Erlang Proxy
* Easy to setup
* Revoke and add secrets after install
* Supports Centos 7/8 or Ubuntu 16 or later and Debian 9 and 8
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
### Install
On your server run
```bash
curl -o MTProtoProxyInstall.sh -L https://git.io/fjo34 && bash MTProtoProxyInstall.sh
```
Wait until the setup finishes, you should be given the links. (using `systemctl status mtprotoproxy -l` will display said links as well)

To update, uninstall, change port, revoke secret or... the proxy, run this script again.
#### Managing The Proxy
##### Service
Use `systemctl start mtprotoproxy` to start, `systemctl stop mtprotoproxy` to stop and `systemctl status mtprotoproxy -l` to see logs of script. For hot reload see below.
##### Config
To manually config, proxy edit config.py in /opt/mtprotoproxy to change the config; Then restart the server using `systemctl restart mtprotoproxy` or use hot reload.
##### Quota Limiter
Python version of the proxy has the ability to limit the users by the traffic they use. You can change the quota by re-running the script after the installation. But remember that if you restart the proxy, all of the usages will reset. (They start counting from 0 again.)

Therefore, if you want user management you can use this [program](https://github.com/HirbodBehnam/PortForwarder)
##### Hot Reload:
Hot reload reloads the config file without restarting the service. It can be useful if you have set some quota limits.

Copy and execute each of these lines on your terminal:
```bash
pid=$(systemctl show --property MainPID mtprotoproxy)
arrPID=(${pid//=/ })
pid=${arrPID[1]}
kill -USR2 "$pid"
```
### API
This script gives you post-install API support to control the proxy. [More Info](https://github.com/HirbodBehnam/MTProtoProxyInstaller/wiki/API-For-Python-Script)
## Official Script
### Install
On your server run
```bash
curl -o MTProtoProxyOfficialInstall.sh -L https://git.io/fjo3u && bash MTProtoProxyOfficialInstall.sh
```
and wait until the setup finishes and you will see the links after install.
#### Workers
Each worker can handle more than 10000 connections on a modern CPU. Connections will be split between workers. Do not spawn workers more than your CPUs thread count.
#### Auto Install (Keyless)
You can run the script with arguments to enable the "keyless installer".

For example:
```bash
curl -o MTProtoProxyOfficialInstall.sh -L https://git.io/fjo3u && bash MTProtoProxyOfficialInstall.sh --port 443 --secret 00000000000000000000000000000000
```
Reference:
```
-p | --port : int -> The port that the proxy will listen on it. Do not include this argument to choose a random port
-s | --secret : string -> Adds a secret to list of secrets. Secret must be a 32 characters and in hexadecimal format; Use multiple of this argument to add more secrets (See example below)
-t | --tag : string -> Set the advertisement tag for the proxy. Do not pass this argument to disable the tag.
--workers : int -> The number of workers that the proxy spawns. Default is number of your CPU threads - 1.
--disable-updater : bool -> Pass this argument to disable the proxy updater.
--tls : string -> The host that the proxy must mimic. The default is www.cloudflare.com. To disable the fake tls, use this: '--tls ""'
--custom-args : string -> If you want you can set some other arguments that are directly put into the service file.
--no-bbr : bool -> Pass this argument to do not enable BBR if the operating system is Ubuntu 18.04 or higher. (Does not have any effect on other operating systems).
```

Example:
```bash
bash MTProtoProxyOfficialInstall.sh --port 443 --secret 00000000000000000000000000000000 --secret 0123456789abcdef0123456789abcdef --tag dcbe8f1493fa4cd9ab300891c0b5b326 --tls "www.google.com"
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

### Fake TLS
Fake TLS is a method that makes the proxy traffic look like TLS (something like websites traffic). In order to make your clients use it you have to share the specific link with them. The script will print it at the end. Fake-TLS links begins with `ee`.
### Quota Managment
I've written a small program in golang([link](https://github.com/HirbodBehnam/PortForwarder)) to forward traffic with quota managment. I've also written a guide [here](https://github.com/HirbodBehnam/MTProtoProxyInstaller/wiki/Quota-Management-For-Server) in order to configure it with MTProto. Right now it also supports the limiting the amount of _connections_ per port. [Persian Guide](http://rizy.ir/limitUsers)
### How to install on Windows?
I've written a small guide to install that on Windows. Please read [wiki](https://github.com/HirbodBehnam/MTProtoProxyInstaller/wiki) for more info.
### Server
You can use any VPS or Dedicated Server. If you want a cheap and low-end server, I personally recommend to buy one at [Virmach](https://virmach.com/); They also accept cryptos!

#### Persian guide to buying servers, installing script, FAQ and QoS
***I DO NOT USE MTPROTO PROXY MYSELF.*** You can also use [shadowsocks with Cloak](https://github.com/HirbodBehnam/Shadowsocks-Cloak-Installer)(**Highly Recommended** and I use it myself) or [wireguard](https://github.com/l-n-s/wireguard-install) or [openvpn](https://github.com/angristan/openvpn-install) instead.

(If you are from Iran, you may need to open this link with VPN)

http://rizy.ir/4EbW
#### English guide to buying servers and installing script
https://www.reddit.com/r/Telegram/comments/95m5vi/how_to_deploy_mtproto_proxy_server_on_centos/
### Proxy Projects
[Python Proxy](https://github.com/alexbers/mtprotoproxy)

[Official C Proxy](https://github.com/TelegramMessenger/MTProxy)

[Erlang Proxy](https://github.com/seriyps/mtproto_proxy)
### Donations
You can donate to me through bitcoin at `1XDgEkpnkJ7hC8Kwv5adfaDC1Z3FrkwsK`, Ethereum at `0xbb527a28B76235E1C125206B7CcFF944459b4894`, ZCash 
at `t1ZKYrYZCjxDYvo6mQaLZi3gNe2a6MydUo3` and Bitcoin Gold at `GcNgxfyR3nnAsD3Nhuckvq14sXYuDFkK9P`
