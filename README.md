# MTProtoProxyCentOSInstall
A very small script to install MTProtoProxy On CentOS 7
### Why this installer?
* Generate random secret
* Create a service to run it on background and start up
* Setup proxy with small knowledge
## Install
On your CentOS run
```
wget https://git.io/vhgUt
sudo bash MTProtoProxyInstall.sh
```
and wait until the setup finishes the install.
Then enter `systemctl status mtprotoproxypython -l` and you can see the proxy link there. (Usually the last line and it starts with tg://...)
## Control The Proxy
### Service
Use `systemctl start mtprotoproxypython` to start, `systemctl stop mtprotoproxypython` to stop and `systemctl status mtprotoproxypython` to see logs of script.
### Config
Edit config.py in /opt/mtprotoproxy to change the config. Then restart the server using `systemctl restart mtprotoproxypython`
## Server
You can buy a server at [Virmach](https://virmach.com/) they also accept cryptos!
# Main Project
I only and only created a simple installer to install [this repo](https://github.com/alexbers/mtprotoproxy) on CentOS 7. Please report proxy related issues at [here](https://github.com/alexbers/mtprotoproxy/issues)
## Donate
You can donate me with bitcoin at `1XDgEkpnkJ7hC8Kwv5adfaDC1Z3FrkwsK`, Ethereum at `0xbb527a28B76235E1C125206B7CcFF944459b4894` and ZCash at `t1ZKYrYZCjxDYvo6mQaLZi3gNe2a6MydUo3`
