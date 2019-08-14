# IQUIDUS EXPLORER INSTALLATION ON VPS

## VPS SERVER
Requirement 
 - Minimum : 1 CPU / 1 GB RAM 
 - Recommended : 2 CPUs / 4 GB RAM 

### make swap
if you have under 1GB ram, you need at least 2GB swap or 2x of your RAM size.
```
sudo fallocate -l 2G /swapfile && \
sudo chmod 600 /swapfile && \
ls -lh /swapfile | grep -e "-rw-------" && \
sudo mkswap /swapfile && \
sudo swapon /swapfile && \
sudo swapon --show && \
sudo cp /etc/fstab /etc/fstab.bak && \
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### locale all to `en_US.UTF-8`
```
#
export LANGUAGE="en_US.UTF-8" && \
echo 'LANGUAGE="en_US.UTF-8"' >> /etc/default/locale && \
echo 'LC_ALL="en_US.UTF-8"' >> /etc/default/locale
```

### timezone to `Asia/Seoul`
```bash
sudo timedatectl set-timezone Asia/Seoul
```
> LOGOUT/IN

## INSTALL COIND 

### wallet depends
```bash
cd && \
sudo add-apt-repository ppa:bitcoin/bitcoin -y && \
sudo apt-get update -y && \
sudo apt-get install -y \
software-properties-common libdb4.8-dev libdb4.8++-dev build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-all-dev libminiupnpc-dev libzmq3-dev libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler libqrencode-dev
```

### wallet build
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
$HOME/sugarchain-v0.16.3/src/sugarchaind -server=1 -txindex=1 -rpcuser=rpcuser -rpcpassword=rpcpassword -daemon
```

### (optional) copy blockchain
```
rsync -avzu -e "ssh -i ~/key.pem" ~/.sugarchain/testnet4/chainstate/ root@111.222.333.444:~/chainstate/
 ( OR )
scp -r -i ~/key.pem ~/.sugarchain/testnet4/blocks/ root@111.222.333.444:~/blocks/
```

## INSTALL EXPLORER

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

### MongoDB install (v3.2.21) ...wired...
https://docs.mongodb.com/v3.2/tutorial/install-mongodb-on-ubuntu/
https://github.com/mongodb-js/kerberos/issues/45
https://www.mkyong.com/mongodb/mongodb-failed-to-unlink-socket-file-tmpmongodb-27017/

```
cd && \
wget -qO - https://www.mongodb.org/static/pgp/server-3.2.asc | sudo apt-key add - && \
echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list && \
sudo apt-get update && \
sudo apt-get install -y mongodb-org=3.2.21 mongodb-org-server=3.2.21 mongodb-org-shell=3.2.21 mongodb-org-mongos=3.2.21 mongodb-org-tools=3.2.21 && \
sudo service mongod stop && \
sudo rm -f /tmp/mongodb-27017.sock && \
sudo systemctl enable mongod.service && \
sudo service mongod start && \
mongod --version | grep "v3.2.21" && \
sudo service mongod status
```

### (optional) MongoDB fix warning
Warning
```
Server has startup warnings: 
2019-08-14T22:50:19.528+0900 I CONTROL  [initandlisten] 
2019-08-14T22:50:19.528+0900 I CONTROL  [initandlisten] ** WARNING: /sys/kernel/mm/transparent_hugepage/enabled is 'always'.
2019-08-14T22:50:19.528+0900 I CONTROL  [initandlisten] **        We suggest setting it to 'never'
2019-08-14T22:50:19.528+0900 I CONTROL  [initandlisten] 
2019-08-14T22:50:19.528+0900 I CONTROL  [initandlisten] ** WARNING: /sys/kernel/mm/transparent_hugepage/defrag is 'always'.
2019-08-14T22:50:19.528+0900 I CONTROL  [initandlisten] **        We suggest setting it to 'never'
2019-08-14T22:50:19.528+0900 I CONTROL  [initandlisten]
```

Solution: paste it to `/etc/rc.local` before `exit 0` and `reboot`. then try mongo again.
```
# mongo - begin
if test -f /sys/kernel/mm/transparent_hugepage/khugepaged/defrag; then
  echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
# mongo - end
```

### MongoDB DB create
```
$ mongo
> use explorerdb
> db.createUser( { user: "mongo-user", pwd: "mongo-pwd", roles: [ "readWrite" ] } )
> exit
```

### (optional): MongoDB DROP DB (caution!! lost your database!!)
```bash
$ mongo
> use explorerdb;
> db.dropDatabase();
> db.dropUser("mongo-user")
> exit
```

### explorer install
```bash
cd && \
sudo apt-get install -y libkrb5-dev && \
git clone https://github.com/sugarchain-project/explorer.git explorer && \
cd explorer && npm install --production
```

### explorer settings
> edit `./settings.json`

### explorer test-run (use different terminals)
```bash
npm start # term-1
rm -f ./tmp/index.pid # term-2 : remove pid for sure
node scripts/sync.js index update # term-2 : run twice. take a while... (1~7 days)
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
rm -f tmp/index.pid && \
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
crontab -e
```

```
# run explorer with logfile
@reboot $HOME/explorer/run.sh >> $HOME/run.log 2>&1

# clear logfile (every monday 9:00)
0 9 * * 1       > $HOME/run.log
```

run.sh
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

### (optional) stop and restart
```bash
cd $HOME/explorer/ && forever stop bin/cluster
cd $HOME/explorer/ && forever start bin/cluster
cd $HOME/explorer/ && forever restart bin/cluster
```

### (optional) check forever log
```bash
forever list
tail -f $HOME/.forever/PwHy.log
```

## DNS
setting up for website

### firewall (on AWS, check Security Group/Inbound)
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
website url is `1explorer-testnet.cryptozeny.com`
```bash 
sudo apt-get install -y nginx && \
sudo rm /etc/nginx/sites-enabled/default
```

make file
```bash
URL="1explorer-testnet.cryptozeny.com" && \
sudo nano /etc/nginx/sites-available/$URL
```

paste it
```
server {
    listen 80;
    server_name 1explorer-testnet.cryptozeny.com;

    location / {
        proxy_set_header   X-Forwarded-For $remote_addr;
        proxy_set_header   Host $http_host;
        proxy_pass         "http://127.0.0.1:3001";
    }
}
```

make ln & restart nginx
```bash 
URL="1explorer-testnet.cryptozeny.com" && \
sudo ln -s \
/etc/nginx/sites-available/$URL \
/etc/nginx/sites-enabled/$URL && \
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
sudo service nginx stop && \
sudo service nginx start && \
sudo service nginx restart && \
sudo service nginx reload && \
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
16 8 * * 4 . $HOME/certbot/certbot-auto renew --pre-hook "service nginx stop" --post-hook "service nginx start" --force-renewal >> $HOME/certbot.log 2>&1
```

> REBOOT 

## MISC

### (optional) change website URL  
https://github.com/sugarchain-project/explorer/commit/2d29302470e1164d0aff9001bf2dbdcd486bec71

# LICENSE

Copyright (c) 2019, The Sugarchain developers  
Copyright (c) 2019, cryptozeny  
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
