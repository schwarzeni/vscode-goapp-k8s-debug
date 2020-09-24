#!/bin/bash

rm -rf vendor
kubectl delete -f debug/debug-pod.yaml
docker ps -a | grep my-golang-app | awk '{print $1}' | xargs docker rm
docker images | grep my-golang-app-image | awk '{print $3}' | xargs docker rmi