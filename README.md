# Demo: APL on Kubeless Serverless platform #
Kubeless is a serverless open source platform, see www.kubeless.io .

APL is **A** **P**rogramming **L**anguage, where central datatype is the multidimensional array. In this demo we use Dyalog 17.0 APL interpreter (Linux version), see www.dyalog.com .

APL Kubeless runtime (see fork of Kubless https://github.com/mvranic/kubeless) is based on JSON Server https://github.com/Dyalog/JSONServer. JSON Server used in APL Kubeless runtime is extended in a fork at https://github.com/mvranic/JSONServer .

**Note:**
Dyalog APL 17.0 distribution is needed to run this demo. Look on www.dyalog.com for options on how to download installation. 

Demo is executed on minikube Kubernetes cluster (see https://github.com/kubernetes/minikube ) which is running local PC with Windows 10. Commands in demo are executed in a PowerShell session.  

**curl** and **ab** (Apache Benchmark) tools are used from Linux Subsystem (which can be installed on Windows 10).   

## Clone Kubeless code and binaries ## 
Use custom folder where the code will be cloned from GitHub like (e.g. c:\kubeless-demo). Further this folder will be called **Kubeless working folder**.

Kubeless serverless framework supports various programming languages, but APL is not by supported. Therefore, Kubeless serverless framework had to be extended, to implement APL runtime to run APL code.

To clone forked Kubeless framework, Kubeless bundles, Kubeless deployment and this demo use:
```
git clone https://github.com/mvranic/kubeless.git
git clone https://github.com/mvranic/kubeless-bundles.git
git clone https://github.com/mvranic/kubeless-apl-deployment.git
git clone https://github.com/mvranic/kubeless-ui.git
git clone https://github.com/mvranic/kubeless-apl-demo.git
```
https://github.com/mvranic/kubeless-bundles is result of    https://github.com/mvranic/kubeless.git build.

Set *$path* to the Kubeless binaries:
```
$currpath = [Environment]::GetEnvironmentVariable("Path",  "User")
$currpath = +";"+ Get-Item -Path ".\").FullName +"\kubeless-bundles\bundles\kubeless_windows-amd64\"
[Environment]::SetEnvironmentVariable("Path", ${currpath}, "User")
exit # Settings are not applied current process. 
```
## Set up minikube ##
In this demo we use Hyper-V for vitalization of minikube. Hyper-V requires to set External Virtual Network Switch (this step is not described here, please google it). In demo new switch is called "Default Switch". Minikube can run also on other types of virtualization, like Oracles Virtual Box and others.

Minikube settings and virtual machine are placed on $Home path. If your $Home is on network drive, set minikube and kubernetes variable to local disk.

```
[Environment]::SetEnvironmentVariable("MINIKUBE_HOME", "C:/Users/${env:UserName}/.minikube", "User")
[Environment]::SetEnvironmentVariable("KUBECONFIG", "C:/Users/mvc/.kube/config", "User")
exit # Setings are not applied current process. 
```

**Note:**

The fastest way to stop, and clean up minikube cluster is:
1. Turn-off and delete Minikube VM in Hyper-V manger.
2. Remove folders: 
    * C:/Users/${env:UserName}/.minikube
    * C:/Users/mvc/.kube

## Start minikube ##
To start minikube run:

```
minikube start --vm-driver hyperv --hyperv-virtual-switch "Default Switch" 
```

Enable minikube addons:

```
minikube addons enable metrics-server
minikube addons enable ingress
```

**Metrics server** addon is used for autoscaling.
**ingress** addon is used for creating routes for functions.

Optionally enable **heapster** addon, which is old metrics for autoscaling and used for charts in dashboard.

```
minikube addons enable heapster
```

## Kubernetes dashboard ##
To see the state of Kubernetes cluster can be used dashboard.

Dashboard will use PowerShell sessions, open new session and start the dashboard:
```
start powershell # This will open new PowerShell session.
```
To open dashboard in web browser:
```
minikube dashboard
```

## Setup local Docker registry in minikube ##
To access docker in minikube VM, open new PowerShell session (further on called *docker PowerShell session*) and run: 

```
minikube docker-env | Invoke-Expression
```
after that docker can be accessed:

```
docker images
```

To set up local docker registry in minikube-s docker run:
```
docker run -d -p 5000:5000 --restart=always --name registry-private registry:2
```

Now docker images can be pushed to the local docker registry. 

## Build and push APL Kubeless runtime image ##

Use *docker PowerShell session*.

Change directory to place where https://github.com/mvranic/kubeless.git is cloned.

Change directory to folder where is Kubeless APL runtime defined:
```
cd .\kubeless\docker\runtime\apl
```

Replace .\dyalog-installation\dummy.zip with Dyalog APL 17.0 distribution.

Build and push Kubeless APL runtime docker image:
```
.\Makefile-minikube.ps1
``` 

## Deploy Kubeless framework ##
Change directory to place where https://github.com/mvranic/kubeless-apl-deployment.git is cloned.

Deploy Kubeless framework:
```
.\deployment\deploy-apply.ps1
``` 

## versify deployment ##
To se waht is deployed use:
```
kubectl get pod --all-namespaces
```

**Kubeless with APL is deployed now.**

# Run APL hello world #
Let open some PowerShell to see the status of deployment. Open new PowerShell command for each of command:
``` 
kubectl get deployment -w
``` 
``` 
kubectl get pods -w
``` 
``` 
kubectl get hpa -w
``` 
Change directory to place where https://github.com/mvranic/kubeless-apl-demo.git is cloned.

Change directory to *src* folder: 
``` 
cd src
``` 

**Create kubelles function:**
``` 
kubeless function deploy echo --runtime apl17.0 --from-file test-echo.dyalog  --handler test-echo.echo 
``` 

**Run Kubeless function:**
``` 
kubeless function call echo --data '{"Hallo":"APL"}'
``` 

**Note:** As Istio is not installed liveness probe  is not connected with any circuit-breaker code. Therefore, wait a few seconds from start deployment to be operational. In Kubeless liveness probe is API GET *healthz*, which is deployed to JSON Server in side of APL runtime.

# HTTP Triger #
To ceate HTTP triger:
```
kubeless trigger http create echo --function-name echo
```

See the Ingress setting:
```
kubectl get ing
```
```
NAME      HOSTS                         ADDRESS          PORTS     AGE
hallo     hallo.172.24.206.168.nip.io   172.24.206.168   80        47s
```

Access with curl. But start bash before:
```
bash
```

```
  curl --data '{"Hallo":"APL"}' \
  --header "Host: echo.172.24.206.168.nip.io" \
  --header "Content-Type:application/json" \
  172.24.206.168/echo
```

Use option *-v* to see full request.

# Performance test #
To access ab (Apache benchmark) tool, the bash session is needed:
```
bash
```

The performance test of running 10 clients with 1000 request:
```
ab -H "Host: echo.172.24.206.168.nip.io" \
   -H "Content-Type:application/json" \
   -p ./postdata.json \
   -c 10 -n 1000\
   172.24.206.168/echo 
```

Output of test (a part): 
```
Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.2      0       3
Processing:     1   37  81.9     32    1094
Waiting:        1   37  81.9     32    1093
Total:          2   38  81.9     33    1095

Percentage of the requests served within a certain time (ms)
  50%     33
  66%     36
  75%     38
  80%     39
  90%     42
  95%     46
  98%     48
  99%     50
```

The echo call is average around **4ms**.

# Autoscaling #
Let’s create APL function which uses some CPU.

``` 
kubeless function deploy foo --runtime apl17.0 --from-file test-foo.dyalog  --handler test-foo.foo 
``` 

Run kubeless function:
``` 
kubeless function call foo --data '{"Hallo":"APL"}'
``` 

Update function and set up auto scale:
``` 
kubeless function update foo --runtime apl17.0 --from-file test-foo.dyalog  --handler test-foo.foo --cpu 200m --memory 50M 
kubeless autoscale create foo --min 1 --max 4  --value 50
``` 

To see curent auto scale:
``` 
kubeless autoscale list
``` 

Check if it works:
``` 
kubeless function call foo --data 'Hallo world'
``` 

Start bash:
``` 
bash
``` 

Run 6 clients in parallel in *ab* tool:
 ```
ab -H "Host: foo.172.24.206.168.nip.io" \
   -H "Content-Type:application/json" \
   -p ./postdata.json \
   -c 6 -n 10000 \
   -t 300 \
   172.24.206.168/foo 
```

Monitoring the **hpa** and **pods** the values in the PowerShell window will show that new pods are deployed, and number of replicas are incremented.
``` 
kubectl get pods -w
```
Output:
``` 
NAME                    READY     STATUS    RESTARTS   AGE
echo-566955cb4f-8mvsq   1/1       Running   0          12h
foo-6c444c4c69-q99jr    1/1       Running   0          1m
hallo-9f54d4f4f-dxrkd   1/1       Running   0          15h
foo-6c444c4c69-q99jr   1/1       Running   1         4m
foo-6c444c4c69-h926n   0/1       Pending   0         0s
foo-6c444c4c69-h926n   0/1       Pending   0         0s
foo-6c444c4c69-h926n   0/1       Init:0/1   0         0s
foo-6c444c4c69-h926n   0/1       PodInitializing   0         1s
foo-6c444c4c69-h926n   1/1       Running   0         2s
foo-6c444c4c69-pgpdn   0/1       Pending   0         0s
foo-6c444c4c69-pgpdn   0/1       Pending   0         0s
foo-6c444c4c69-pgpdn   0/1       Init:0/1   0         0s
foo-6c444c4c69-pgpdn   0/1       PodInitializing   0         1s
foo-6c444c4c69-pgpdn   1/1       Running   0         2s
foo-6c444c4c69-h926n   1/1       Terminating   0         8m
foo-6c444c4c69-pgpdn   1/1       Terminating   0         4m
foo-6c444c4c69-pgpdn   0/1       Terminating   0         5m
foo-6c444c4c69-pgpdn   0/1       Terminating   0         5m
foo-6c444c4c69-h926n   0/1       Terminating   0         9m
foo-6c444c4c69-pgpdn   0/1       Terminating   0         5m
foo-6c444c4c69-pgpdn   0/1       Terminating   0         5m
foo-6c444c4c69-h926n   0/1       Terminating   0         9m
foo-6c444c4c69-h926n   0/1       Terminating   0         9m
``` 

``` 
kubectl get hpa -w
``` 

``` 
Output:
NAME      REFERENCE        TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
foo       Deployment/foo   <unknown>/50%   1         4         1          1m
foo       Deployment/foo   0%/50%    1         4         1         2m
foo       Deployment/foo   37%/50%   1         4         1         3m
foo       Deployment/foo   100%/50%   1         4         1         4m
foo       Deployment/foo   100%/50%   1         4         2         4m
foo       Deployment/foo   100%/50%   1         4         2         5m
foo       Deployment/foo   99%/50%   1         4         2         6m
foo       Deployment/foo   99%/50%   1         4         2         6m
foo       Deployment/foo   99%/50%   1         4         2         7m
foo       Deployment/foo   99%/50%   1         4         2         7m
foo       Deployment/foo   59%/50%   1         4         2         8m
foo       Deployment/foo   59%/50%   1         4         3         8m
foo       Deployment/foo   0%/50%    1         4         3         9m
foo       Deployment/foo   0%/50%    1         4         3         9m
``` 

After the *ab* test is finished, the number of replicas and deployed pods will decrement.  

## Pub-Sub example - Kafka trigger ##
Kafka trigger can be used for Pub-Sub event subscription.

At first Kafka support for Kubeless has to be deployed:
``` 
$RELEASE="v1.0.0-beta.0"
kubectl create -f https://github.com/kubeless/kafka-trigger/releases/download/$RELEASE/kafka-zookeeper-$RELEASE.yaml
``` 

Create Kubeless function:
``` 
kubeless function deploy echokafka --runtime apl17.0 --from-file test-echo-kafka.dyalog  --handler test-echo-kafka.echoKafka 
``` 

Run Kubeless function:
``` 
kubeless function call echokafka --data '{"Hallo":"APL"}'
``` 

Create Kafka Trigger:
``` 
kubeless trigger kafka create test-kafka-echo --function-selector created-by=kubeless,function=echokafka --trigger-topic echo-topic
``` 
With this will be created *echo-topic* too.

List available Kafka topics:
``` 
kubeless topic ls
``` 

Publish APL event of Kafka topic (queue):
``` 
kubeless topic publish --topic echo-topic --data "Hello kafka from APL!"
``` 

In order to check if the event is dequeued, list all pods
``` 
kubectl get pods --all-namespaces
NAME                         READY     STATUS    RESTARTS   AGE
echokafka-6d59c65959-47wgs   1/1       Running   0          1m
``` 

and find one with echokafka function.

In Log pods log 
``` 
kubectl logs echokafka-6d59c65959-47wgs
 2018/10/24 @ 12:33:41   HTTP/1.1  200  OK    Content-Type                 appl
                                              Access-Control-Allow-Origin  *
      ication/json; charset=utf-8   "Health check."

 2018/10/24 @ 12:33:57   POST  /  HTTP/1.1   Host             echokafka.default
                                             User-Agent       Go-http-client/1.
                                             Content-Length   21
                                             Content-Type     application/x-www
                                             Event-Id         hIfOGhQ-KwNmHCs
                                             Event-Namespace  kafkatriggers.kub
                                             Event-Time       2018-10-24 12:33:
                                             Event-Type       application/x-www
                                             Accept-Encoding  gzip
      .svc.cluster.local:8080
      1

      -form-urlencoded

      eless.io
      56.5374067 +0000 UTC
      -form-urlencoded

 2018/10/24 @ 12:33:57  Hello kafka from APL!
Org. POST payload:
Hello kafka from APL!
POST payload:
Hello kafka from APL!
Exec:
 payload:  Hello kafka from APL!
 Handler:  HandlerWrapper
 req:  0  SRV00000000.CON00000007  HTTPBody  Hello kafka from APL!
Start handler wrapper for "echokafka".
 **Hello kafka from APL!  2018 10 24 12 33 57 277**
Stop handler wrapper for "echokafka".
End Exec.
 2018/10/24 @ 12:33:57   HTTP/1.1  200  OK    Content-Type                 appl
                                              Access-Control-Allow-Origin  *
      ication/json; charset=utf-8   ["Hello kafka from APL!",[2018,10,24,12,33,

      57,277]]
``` 
should be visible "Hello kafka from APL!" i.e. the event is dequeued from Kafka topic.

In the end trigger can be deleted with:
``` 
kubeless trigger kafka delete test-kafka-halloapl
``` 

## Kubeless UI (still under test) ##
Kubeless UI enables to edit deployed functions. To change APL function should be used GitHub fork https://github.com/mvranic/kubeless-ui.git of https://github.com/kubeless/kubeless-ui.git . 

The Kubeless UI is deployed from *docker PowerShell session*. Change directory to place where https://github.com/mvranic/kubeless-ui.git is cloned. To deploy run:
``` 
.\build-local-images.ps1
``` 

To start Kubeless UI run:
``` 
minikube service ui -n kubeless
``` 

After that deployed function can be changed in Kubeless UI.

## Delete Kubeless function ##
To delete function run:
``` 
kubeless function delete foo
``` 


