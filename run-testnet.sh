#!/bin/bash

# coind daemon
$HOME/sugarchain-0.16.3/bin/sugarchaind -server=1 -rpcuser=rpcuser -rpcpassword=rpcpassword -txindex -daemon -testnet -uacommnet=explorer-testnet
$HOME/sugarchain-v0.16.3/src/sugarchaind -server=1 -rpcuser=rpcuser -rpcpassword=rpcpassword -txindex -daemon -testnet -uacommnet=explorer-testnet

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
    rm -f ./tmp/delete.me
    node ./scripts/sync.js index update
    # node scripts/sync.js market
    node ./scripts/peers.js
    echo "***** sleep 5 seconds *****"
    sleep 5.0
done
