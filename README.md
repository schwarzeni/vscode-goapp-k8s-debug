# Debug 部署至 K8S 中的 Golang 程序

**自用模板**

现在研二了，论文开题的大概范围是需要围绕 Kubernetes & KubeEdge 做一些二次开发，这就涉及到编写应用以容器的形式部署至 Pod 中与 Kubernetes 进行交互。

那么问题来了，如果运行在容器中的应用出现问题了，同时s仅仅凭借打印的日志无法定位问题怎么办？如果这个容器是需要从集群内部访问 K8S 组件，那么我就无法将应用运行在外部使用 IDE 调试。

程序主要使用 Golang 开发，而 dlv 提供了远程调试的功能，最近研究了一下，如果使用 VSCode + dlv 调试运行在 Kubernetes 集群中的容器。

## 开发环境

- Ubuntu Server 16.04
- VSCode 1.49.1
- Golang 1.14.4 linux/amd64
- Kubernetes 1.17.0
- dlv 1.4.1

我的 Kubernetes 只有一个节点，所以如果有多个节点，那么需要在部署的时候配了 tag 使 Pod 被调度到开发环境所在的节点上，这里就不介绍了。如果 Pod 运行在当前节点上就可以直接通过 127.0.0.1:2345 来访问 dlv 了。

---

## 代码结构

```txt
.
├── debug
│   ├── debug-pod.yaml
│   ├── Dockerfile
│   ├── post-debug.sh
│   └── pre-debug.sh
├── go.mod
├── go.sum
├── main.go
└── .vscode
    ├── launch.json
    └── tasks.json
```

main.go 就是需要调试的程序，内容如下

```go
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
```

这里的两个文件 `tokenFile` 和 `rootCAFile` 是只有在 Kubernetes 内部才能访问到的，那两个环境变量 `KUBERNETES_SERVICE_HOST` 和 `KUBERNETES_SERVICE_PORT` 也是。同时使用到了一个第三方库。

---

## 思路

### 调试前

在调试前，需要将相关的程序内容打包成镜像，然后以 Pod 的形式部署到 Kubernetes 集群里，之后启动 dlv 服务。`debug/pre-debug.sh` 中就是执行这些步骤的相关代码。下面的两个 while 循环是为了等待 dlv 编译并启动项目。

```bash
#!/bin/bash

go mod vendor
cp /root/gopkg/bin/dlv ./ # 这里是将本地的 dlv 程序拷贝到项目中
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
```

debug/Dockerfile 如下

```Dockerfile
FROM golang:1.14
EXPOSE 2345

WORKDIR /go/src/app
COPY . .

ENTRYPOINT ["./dlv", "debug", "--headless", "--listen=:2345", "--log", "--api-version=2"]
```

debug/debug-pod.yaml 如下

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-golang-app
  annotations:
    seccomp.security.alpha.kubernetes.io/defaultProfileName: "unconfined"
spec:
  containers:
    - name: my-golang-app
      image: my-golang-app-image:latest
      imagePullPolicy: Never
      ports:
        - containerPort: 2345
          hostPort: 2345
```

---

### 调试后

调试结束后，需要将 Pod 和之前打包的镜像销毁掉，同时清理文件夹 `vendor` 。相关步骤在 `debug/post-debug.sh` 中

```sh
#!/bin/bash

rm -rf vendor
kubectl delete -f debug/debug-pod.yaml
docker ps -a | grep my-golang-app | awk '{print $1}' | xargs docker rm
docker images | grep my-golang-app-image | awk '{print $3}' | xargs docker rmi
```

---

### vscode 相关配置

.vscode/launch.json 用于配置执行调试的主逻辑

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Launch remote",
      "type": "go",
      "request": "attach",
      "mode": "remote",
      "remotePath": "/go/src/app",
      "cwd": "${workspaceFolder}",
      "port": 2345,
      "host": "127.0.0.1",
      "preLaunchTask": "pre-debug",
      "postDebugTask": "post-debug",
      "showLog": true
    }
  ]
}
```

.vscode/tasks.json 用于配置预执行任务 `pre-debug` 和后执行任务 `post-debug`

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "pre-debug",
      "type": "process",
      "command": "./debug/pre-debug.sh",
    },
    {
      "label": "post-debug",
      "type": "process",
      "command": "./debug/post-debug.sh"
    }
  ]
}
```

---

## 一些问题

- 无法在 vscode 中获取调试代码 fmt/log 的输出。另外执行如下执行获得日志

```bash
kubectl get pods | grep my-golang-app | awk '{print $1}' | xargs kubectl logs -f
```

- 无法远程调试 `dlv test` ，主要问题是无法打断点，目前无解决方案
