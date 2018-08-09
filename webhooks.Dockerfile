FROM openresty/openresty:alpine-fat

EXPOSE 80

WORKDIR /srv/app

ARG DEPS_NATIVE="curl-dev openssl-dev git"
ARG DEPS_OPM="yangm97/lua-telegram-bot-api"
ARG DEPS_ROCKS="luasec luasocket redis-lua serpent Lua-cURL"

RUN mkdir logs && \
    apk add --no-cache $DEPS_NATIVE && \
    opm install $DEPS_OPM && \
    for ROCK in $DEPS_ROCKS; do luarocks install $ROCK; done

ENTRYPOINT nginx -p `pwd` -c conf/conf.conf

COPY . .
