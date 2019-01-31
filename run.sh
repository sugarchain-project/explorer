#!/bin/bash

#start explorer
forever start bin/cluster

#update
while true;
do 
    touch tmp/index.pid
    rm -f ./tmp/index.pid 
    node scripts/sync.js index update
    # node scripts/sync.js market
    node scripts/peers.js
    echo "***** sleep 5 seconds *****"
    sleep 5.0
done
