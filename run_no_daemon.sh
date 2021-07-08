#!/bin/bash

# coind daemon
#$HOME/sugarchain-0.16.3/bin/sugarchaind -server=1 -rpcuser=rpcuser -rpcpassword=rpcpassword -txindex -daemon -prunedebuglogfile # -uacommnet=explorer

# waiting for daemon
#echo "***** sleep 1 hour for daemon *****"
#sleep 1h

# start explorer
cd $HOME/explorer/
touch ./tmp/index.pid
rm -f ./tmp/index.pid
$HOME/.nvm/v0.10.28/bin/forever start ./bin/cluster

# waiting for explorer
echo "***** sleep 5 minutes for explorer *****"
sleep 5m

# update
while true;
do
    cd $HOME/explorer/
    touch ./tmp/index.pid
    rm -f ./tmp/index.pid
    rm -f ./tmp/delete.me
    node ./scripts/sync.js index update
    node scripts/sync.js market
    node ./scripts/peers.js
    echo "***** sleep 5 seconds for while_loop *****"
    sleep 5.0
done
