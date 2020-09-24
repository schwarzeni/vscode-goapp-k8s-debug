package main

import (
	"fmt"
	"io/ioutil"
	"os"

	"github.com/google/uuid"
)

const (
	tokenFile  = "/var/run/secrets/kubernetes.io/serviceaccount/token"
	rootCAFile = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
)

func main() {
	fmt.Println("Hello world: " + uuid.New().String())
	host, port := os.Getenv("KUBERNETES_SERVICE_HOST"), os.Getenv("KUBERNETES_SERVICE_PORT")
	fmt.Println(host, port)
	readFile(tokenFile)
	readFile(rootCAFile)
	for {
	}
}

func readFile(path string) {
	data, err := ioutil.ReadFile(path)
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Println(string(data))
}
