# IQUIDUS EXPLORER INSTALLATION ON VPS

## INTRO: switch from Bitpay Inishgt
기존의 Bitpay Insight를 사용하고 있었다. 나쁘지 않았다 하지만 bitcoin `v0.16` 이후에 `getinfo`가 삭제되었고 최신버젼에서는 Bitpay Insight를 더이상 사용할수없다. 그 대안으로 찾은것이 바로 IQUIDUS EXPLORER 이다. 다양한 기능을 제공하며 꽤 괜찮은 성능을 보여준다.

Bitpay Insight doesn't support after bitcoin v0.16
```js
info: insight server listening on port 3000 in development mode
error: ERROR  code=-32601, message=getinfo

This call was removed in version 0.16.0. Use the appropriate fields from:
- getblockchaininfo: blocks, difficulty, chain
- getnetworkinfo: version, protocolversion, timeoffset, connections, proxy, relayfee, warnings
- getwalletinfo: balance, keypoololdest, keypoolsize, paytxfee, unlocked_until, walletversion
```

## install VPS server 

### locale all to `en_US.UTF-8`
```bash
export LANGUAGE="en_US.UTF-8" && \
echo 'LANGUAGE="en_US.UTF-8"' >> /etc/default/locale && \
echo 'LC_ALL="en_US.UTF-8"' >> /etc/default/locale
```

### timezone to `Asia/Seoul`
```bash
sudo timedatectl set-timezone Asia/Seoul
```
> LOGOUT/IN

## install coind 

### wallet depends
```bash
cd && \
sudo add-apt-repository ppa:bitcoin/bitcoin -y && \
sudo apt-get update -y && \
sudo apt-get install -y \
software-properties-common libdb4.8-dev libdb4.8++-dev build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-all-dev libminiupnpc-dev libzmq3-dev libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler libqrencode-dev
```

### wallet build (check branch!)
```bash
cd && \
git clone git@github.com:cryptozeny/sugarchain-v0.16.3.git && \
cd sugarchain-v0.16.3/ && \
./autogen.sh && \
./configure && \
make -j$(nproc)
```

if your VPS doesn't have enough memory (under 1GB)
```bash
./configure CXXFLAGS="--param ggc-min-expand=1 --param ggc-min-heapsize=32768"
```

if it doesn't help, use swap
https://github.com/bitcoin/bitcoin/issues/6624

### wallet run: explorer needs `-txindex=1` 
for testing log `-printtoconsole` instead of `-daemon`
```bash
/root/sugarchain-v0.16.3/src/sugarchaind -server=1 -txindex=1 -rpcuser=rpcuser -rpcpassword=rpcpassword -daemon
```

## install explorer 

### Nodejs (explorer needs node v0.10.28)
```bash
cd && curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.9/install.sh | bash
```
> LOGOUT/IN

```bash
nvm ls-remote && \
nvm install v0.10.28 && \
nvm ls && \
node -v && \
nvm use v0.10.28
```
> LOGOUT/IN

### MongoDB install (v3.2.21)
https://docs.mongodb.com/v3.2/tutorial/install-mongodb-on-ubuntu/
https://www.mkyong.com/mongodb/mongodb-failed-to-unlink-socket-file-tmpmongodb-27017/
https://github.com/mongodb-js/kerberos/issues/45

```
cd && \
wget -qO - https://www.mongodb.org/static/pgp/server-3.2.asc | sudo apt-key add - && \
echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list && \
sudo apt-get update && \
sudo apt-get install -y mongodb-org=3.2.21 mongodb-org-server=3.2.21 mongodb-org-shell=3.2.21 mongodb-org-mongos=3.2.21 mongodb-org-tools=3.2.21 && \
sudo service mongod start && \
sudo service mongod status
```

### MongoDB start
```
sudo service mongod stop && \
sudo service mongod start
```

### MongoDB DB create
```
$ mongo
> use explorerdb
> db.createUser( { user: "mongo-user", pwd: "mongo-pwd", roles: [ "readWrite" ] } )
> exit
```

### option: drop MongoDB
```bash
$ mongo
> use explorerdb;
> db.dropDatabase();
> db.dropUser("mongo-user")
> exit
```

### explorer install (check branch!)
```bash
cd && \
sudo apt-get install -y libkrb5-dev && \
git clone git@github.com:sugarchain-project/explorer.git explorer && \
cd explorer && npm install --production
```

### explorer settings
```bash
cp ./settings.json.sugarchain ./settings.json
```
> edit `./settings.json`

### explorer test-run (use different terminals)
```bash
npm start # term-1
node scripts/sync.js index update # term-2 (run twice: take a while...)
```
> stop both after sync completed

### forever for Nodejs
```bash
npm install forever -g
npm install forever-monitor
```

### [debug] explorer start
```
forever start bin/cluster
```

### [debug] explorer update every `5s` (sync.js peer.js)
update first
```bash
node scripts/sync.js index update && \
node scripts/sync.js market && \
node scripts/peers.js
```

update auto
```bash
while true; 
do touch tmp/index.pid && \
rm -f ./tmp/index.pid && \
node scripts/sync.js index update && \
node scripts/sync.js market && \
node scripts/peers.js && \
sleep 5.0;
done
```

### [production] cron
fix forever location for crontab
```bash
sudo ln -s $(which node) /usr/bin/node
```

make crontab
```bash
sudo crontab -e
```

```
# run explorer with logfile
@reboot /root/explorer/run.sh >> /root/run.log 2>&1

# clear logfile (every monday 9:00)
0 9 * * 1       > $HOME/run.log
```

run.log
```bash
#!/bin/bash

# coind daemon
$HOME/sugarchain-v0.16.3/src/sugarchaind -server=1 -rpcuser=rpcuser -rpcpassword=rpcpassword -txindex -daemon

# waiting for daemon
echo "***** sleep 30 seconds for daemon *****"
sleep 30.0

# start explorer
cd $HOME/explorer/
touch ./tmp/index.pid
rm -f ./tmp/index.pid
$HOME/.nvm/v0.10.28/bin/forever start ./bin/cluster

# waiting for explorer
echo "***** sleep 30 seconds for explorer *****"
sleep 30.0

# update
while true;
do
    cd $HOME/explorer/
    touch ./tmp/index.pid
    rm -f ./tmp/index.pid
    node ./scripts/sync.js index update
    # node scripts/sync.js market
    node ./scripts/peers.js
    echo "***** sleep 5 seconds *****"
    sleep 5.0
done
```

### (OPTION) stop and restart
```bash
cd /root/explorer/ && forever stop bin/cluster
cd /root/explorer/ && forever start bin/cluster
cd /root/explorer/ && forever restart bin/cluster
```

### (OPTION) check forever log
```bash
forever list
tail -f /root/.forever/PwHy.log
```

## DNS
setting up for website

### firewall
22 for SSH 
80 for Website
443 for Redirect
34230 for Sugarchain(Main)
44230 for Sugarchain(Testnet)
45340 for Sugarchain(Regtest)
 
```bash 
sudo ufw status && \
sudo ufw allow 22 && \
sudo ufw allow 80 && \
sudo ufw allow 443 && \
sudo ufw allow 34230 && \
sudo ufw allow 44230 && \
sudo ufw allow 45340 && \
sudo ufw enable && \
sudo ufw status
```

### nginx
website url is `explorer.sugarchain.org`
```bash 
sudo apt-get install -y nginx && \
sudo rm /etc/nginx/sites-enabled/default
```

make file
```bash 
sudo nano /etc/nginx/sites-available/explorer.sugarchain.org
```

paste it
```
server {
    listen 80;
    server_name explorer.sugarchain.org;

    location / {
        proxy_set_header   X-Forwarded-For $remote_addr;
        proxy_set_header   Host $http_host;
        proxy_pass         "http://127.0.0.1:3001";
    }
}
```

make ln & restart nginx
```bash 
sudo ln -s \
/etc/nginx/sites-available/explorer.sugarchain.org \
/etc/nginx/sites-enabled/explorer.sugarchain.org && \
sudo service nginx restart
```

### get a DNS name 
AWS `route53` recommended
Adds `A` record with `explorer`.
Add nameserver to route53

### SSL certbot
```bash 
cd && \
git clone https://github.com/certbot/certbot && \
cd certbot && \
sudo service nginx restart && \
LC_ALL=C ./certbot-auto run --nginx && \
sudo service nginx reload
```

### cron for renew certbot
```bash 
sudo crontab -e 
```

add it (every Wed at 08:16 AM)
```bash 
# SSL renew by certbot (every Wed at 08:16 AM)
16 8 * * 4 . $HOME/certbot/certbot-auto renew --pre-hook "service nginx stop" --post-hook "service nginx start"
```

> REBOOT 

## MISC

### (OPTION) change website URL  
https://github.com/sugarchain-project/explorer/commit/2d29302470e1164d0aff9001bf2dbdcd486bec71

# License

Copyright (c) 2018, The Sugarchain developers  
Copyright (c) 2018, cryptozeny  
Copyright (c) 2015, Iquidus Technology  
Copyright (c) 2015, Luke Williams  
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of Iquidus Technology nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
