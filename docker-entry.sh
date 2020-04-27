#!/bin/bash

. /root/.bashrc
nvm use v14.0.0

# start tileserver and backend-api
pm2 -s start /root/ecosystem.config.js

# start varnish cache
runVarnish

# keep container running
tail -f /dev/null