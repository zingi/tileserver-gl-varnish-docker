FROM debian:stretch-20200130

# install system dependenciesn, nvm, node 6.17.1 and tileserver-gl
RUN apt-get update && apt-get install curl gnupg apt-transport-https -y && \
    apt-get install libcairo2-dev libjpeg62-turbo-dev libpango1.0-dev libgif-dev build-essential g++ -y && \
    apt-get install python -y && \
    apt-get install libegl1-mesa libgles2-mesa -y && \
    apt-get install xvfb x11-utils -y && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.2/install.sh | bash && \
    . /root/.bashrc && \
    nvm install v6.17.1 && \
    npm config set user 0 && \
    npm install -g tileserver-gl

# install more modern node version and pm2 process manager
RUN . /root/.bashrc && \
    nvm install v12.14.1 && \
    nvm alias default v12.14.1 && \
    npm install pm2 -g

# install varnish
RUN curl -s https://packagecloud.io/install/repositories/varnishcache/varnish63/script.deb.sh | bash && \
    apt-get install varnish -y

# add pm2 config
ADD ./ecosystem.config.js /root/ecosystem.config.js
# add script to start tileserver
ADD ./runTileserver.sh /usr/local/bin/runTileserver
# add script to start varnish
ADD ./runVarnish.sh /usr/local/bin/runVarnish
# add varnish configuration
ADD ./default.vcl /etc/varnish/default.vcl
ADD ./docker-entry.sh /usr/local/bin/docker-entry

# add backend-api code
ADD ./backend-api /usr/src/backend-api
WORKDIR /usr/src/backend-api
RUN . /root/.bashrc && \
    nvm use v12.14.1 && \
    npm i --production /usr/src/backend-api


WORKDIR /root
ENTRYPOINT [ "docker-entry" ]