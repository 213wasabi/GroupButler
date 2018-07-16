FROM golang:alpine as healthchecker-builder
COPY healthchecker /go/src/healthchecker
RUN cd bin && go build healthchecker

FROM openresty/openresty:alpine-fat
EXPOSE 80
WORKDIR /srv/app

HEALTHCHECK --interval=3s --timeout=3s CMD ["healthchecker"] || exit 1
ENTRYPOINT nginx -p `pwd` -c conf/conf.conf

ARG DEPS_OPM="yangm97/lua-telegram-bot-api"

RUN mkdir logs && \
    opm install $DEPS_OPM

COPY --from=healthchecker-builder /go/bin/healthchecker /usr/local/bin
COPY . .
