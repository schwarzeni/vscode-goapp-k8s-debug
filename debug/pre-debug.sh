#!/bin/bash

go mod vendor
cp /root/gopkg/bin/dlv ./
docker build -t my-golang-app-image -f debug/Dockerfile .
rm dlv
kubectl apply -f debug/debug-pod.yaml

while :
do
  status=$(kubectl get pods | grep my-golang-app | awk '{print $3}')
  if [ "$status"  = "Running" ]; then
   break
  fi
  sleep .5
done

while :
do
  line_num=$(kubectl get pods | grep my-golang-app | awk '{print $1}' | xargs kubectl logs | wc -l)
  if (( $line_num > 1 )); then
    break
  fi
  sleep .5
done

# kubectl get pods | grep my-golang-app | awk '{print $1}' | xargs kubectl logs -f
