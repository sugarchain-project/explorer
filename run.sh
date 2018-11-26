#!/bin/bash

#start explorer
forever start bin/cluster

#update
while true;
do 
    touch tmp/index.pid
    rm -f ./tmp/index.pid 
    node scripts/sync.js index update
    node scripts/sync.js market
    node scripts/peers.js
    echo "***** sleep 15 seconds *****"
    sleep 15.0
done
