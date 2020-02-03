FROM debian:stretch-20200130

# install curl for being able to install nvm
# install libcairo2-dev libjpeg62-turbo-dev libpango1.0-dev libgif-dev build-essential g++ 
#           for being able to install node package canvas
# install python for node-gyp
# install libegl1 libgles2 to get required shared libraries for tileserver-gl
# install xvfb for tileserver-gl
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

# install pm2 process manager
RUN . /root/.bashrc && \
    nvm install v12.14.1 && \
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


WORKDIR /root

CMD [ "tail", "-f", "/dev/null" ]