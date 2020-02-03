#!/bin/bash

#
# inspired by:
# https://github.com/maptiler/tileserver-gl/blob/8e1071aad038b960767f1910d6ea86974496b2e4/run.sh
#

. /root/.bashrc

_term() {
        echo "Caught signal, stopping gracefully"
        kill -TERM "$child" 2>/dev/null
}

trap _term SIGTERM
trap _term SIGINT

xvfbMaxStartWaitTime=5
displayNumber=99
screenNumber=0

# Delete files if they were not cleaned by last run
rm -rf /tmp/.X11-unix /tmp/.X${displayNumber}-lock ~/xvfb.pid

echo "Starting Xvfb on display ${displayNumber}"
start-stop-daemon --start --pidfile ~/xvfb.pid --make-pidfile --background --exec /usr/bin/Xvfb -- :${displayNumber} -screen ${screenNumber} 1024x768x24  -ac +extension GLX +render -noreset

# Wait to be able to connect to the port. This will exit if it cannot in 15 minutes.
timeout ${xvfbMaxStartWaitTime} bash -c "while  ! xdpyinfo -display :${displayNumber} >/dev/null; do sleep 0.5; done"
if [ $? -ne 0 ]; then
  echo "Could not connect to display ${displayNumber} in ${xvfbMaxStartWaitTime} seconds time."
  exit 1
fi

export DISPLAY=:${displayNumber}.${screenNumber}

echo
cd /data
nvm use v6.17.1
tileserver-gl -p 80 "$@" &
child=$!
wait "$child"

start-stop-daemon --stop --retry 5 --pidfile ~/xvfb.pid # stop xvfb when exiting
rm ~/xvfb.pid