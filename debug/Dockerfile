FROM golang:1.14
EXPOSE 2345

WORKDIR /go/src/app
COPY . .

ENTRYPOINT ["./dlv", "debug", "--headless", "--listen=:2345", "--log", "--api-version=2"]