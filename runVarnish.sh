#!/bin/bash

#
# replace env-variables in varnish config with value
# https://stackoverflow.com/a/21062584/9135945
#
envs=`printenv`
for env in $envs
do
    IFS== read name value <<< "$env"
    sed -i "s|\${${name}}|${value}|g" /etc/varnish/default.vcl
done

varnishd -a :8080 -f /etc/varnish/default.vcl