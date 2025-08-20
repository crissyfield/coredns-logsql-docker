ARG GO_VERSION=1.24

# Build
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine AS build
SHELL [ "/bin/sh", "-ec" ]

RUN apk add --no-cache git libcap-setcap

WORKDIR /build

RUN git clone https://github.com/coredns/coredns.git . && \
    git submodule init && \
    git submodule add https://github.com/crissyfield/logsql plugin/logsql

RUN sed -i '/^log:log$/a logsql:logsql' plugin.cfg && \
    go generate coredns.go && \
    go get && \
    go mod tidy && \
    go build -v -ldflags="-s -w -X github.com/coredns/coredns/coremain.GitCommit=$(git describe --dirty --always)" -o coredns && \
    setcap cap_net_bind_service=+ep /build/coredns

# Deploy
FROM debian:12-slim

RUN export DEBCONF_NONINTERACTIVE_SEEN=true \
           DEBIAN_FRONTEND=noninteractive \
           DEBIAN_PRIORITY=critical \
           TERM=linux ; \
    apt-get -qq update && \
    apt-get -qq --no-install-recommends install ca-certificates && \
    apt-get clean

COPY --from=build /build/coredns /coredns

WORKDIR /
# USER nonroot:nonroot
EXPOSE 53 53/udp

ENTRYPOINT ["/coredns"]
