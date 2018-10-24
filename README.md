# Demo: APL on Kubeless platform #
Kubeless is serverless opensource platform see www.kubeless.io .

APL is programming language, where central datatype is the multidimensional array. In demo is used Dyalog 17.0 APL interpreter (Linux version) see www.dyalog.com/ .

**Note:**
Dyalog APL 17.0 distribution is needed. Look on www.dyalog.com/ for one. 

Demo is executed on minikube Kubernetes cluster (see https://github.com/kubernetes/minikube ) which was running local PC with Windows 10 i.e. commands are executed in PowerShell.  

**curl** and **ab** (Apache Banchmart) tools are used from Linux Subsystem (which might be installed on Windows 10).   

## Set up minikube ##
In this demo is used Hyper-V for vitalization of minikube. For Hyper-V is needed to set External Virtual Network Switch (this step is not described here, please google it). In demo new switch is called "Default Switch". Minikube can run also on other types of virtualization.

Minikube settings and virtual machine are placed on $Home path. If your $Home is on network drive, set minikube and kubernetes variable to local disk.   

```
[Environment]::SetEnvironmentVariable("MINIKUBE_HOME", "C:/Users/${env:UserName}/.minikube", "User")
[Environment]::SetEnvironmentVariable("KUBECONFIG", "C:/Users/mvc/.kube/config", "User")
exit # Setings are not applied current process. 
```

**Note:**

The fastes wahy to stop, and clean up minikube cluster is:
1. Turn-off and delete minikube VM in Hyper-V manger.
2. Remove folders: 
    * C:/Users/${env:UserName}/.minikube
    * C:/Users/mvc/.kube

## Clone kubeless code and binairies ## 
Use custum folder where the code will be cloned from github like (e.g c:\kubeless-demo). Further this folder is called **kubeless working folder**.

To clone forked kubeless framework, boundles use and this demo use:
```
git clone https://github.com/mvranic/kubeless.git
git clone https://github.com/mvranic/kubeless-bundles.git
git clone https://github.com/mvranic/kubeless-apl-demo.git
git clone https://github.com/mvranic/kubeless-apl-deployment.git
```
https://github.com/mvranic/kubeless-bundles is result of    https://github.com/mvranic/kubeless.git build.

Set $path to the kubeless binires

```
$currpath = [Environment]::GetEnvironmentVariable("Path",  "User")
$currpath = +";"+ Get-Item -Path ".\").FullName +"\kubeless-bundles\bundles\kubeless_windows-amd64\"
[Environment]::SetEnvironmentVariable("Path", ${currpath}, "User")
exit # Setings are not applied current process. 
```

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
**ingress** addon is used for create routes for functions.

Optional can be enabled **heapster** which is old metrics for autoscaling and used for charts in dashboard.

```
minikube addons enable heapster
```

## Kubernetes dashboard ##
To see the state of Kubernetes cluster can be used dashboard.

Dashboard will use PowerShell sessions, open new session and start the dashboard:
```
start powershell # This will opne new PowerShell session.
```
```
minikube dashboard
```

## Setup local Docker registry in minikube ##
To access docker in minikube VM, open new PowerShell session (further called *docker PowerShell session*) and run: 

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

Change directory to place where is cloned https://github.com/mvranic/kubeless.git .

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
Change directory to place where is cloned https://github.com/mvranic/kubeless-apl-deployment.git .

Deploy kubeless:
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
Let open some PowerShell to see the status of deployment. Open new powerhell command for each of command:
``` 
kubectl get deployment -w
``` 
``` 
kubectl get pods -w
``` 
``` 
kubectl get hpa -w
``` 
Change directory to place where is cloned 
https://github.com/mvranic/kubeless-apl-demo.git .

Change directory to *src* folder: 
``` 
cd src
``` 

**Create kubelles function:**
``` 
kubeless function deploy echo --runtime apl17.0 --from-file test-echo.dyalog  --handler test-echo.echo 
``` 

**Run kubeless function:**
``` 
kubeless function call echo --data '{"Hallo":"APL"}'
``` 

**Note:** As Istio is not installed livens probe is not connected with any circuit-breaker code. Therefore, a few seconds from start deployment to be operational.

# HTTP Triger#
To ceate HTTP triger:
```
kubeless trigger http create echo --function-name echo
```

See theingress setting:
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

Outpu of test (part): 
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

## Autoscaling ##
Let create APL function which uses some CPU.

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

In the minute the values in the PowerShell window with 
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
foo       Deployment/foo   0%/50%    1         4         3         10m
foo       Deployment/foo   0%/50%    1         4         3         10m
foo       Deployment/foo   0%/50%    1         4         3         11m
foo       Deployment/foo   0%/50%    1         4         3         11m
foo       Deployment/foo   0%/50%    1         4         3         12m
foo       Deployment/foo   0%/50%    1         4         3         12m
foo       Deployment/foo   0%/50%    1         4         3         13m
foo       Deployment/foo   0%/50%    1         4         1         13m
``` 

will show that new pods are deployed, and number of replicas are incremented.

After the *ab* test is finished, the number of replicas and deployed pods will decrement.  

## Pub-Sub example - Kafka trigger ##
Kafka triiger can be used for Pub-Sub event subscription.

At first hast to be deployed Kafka support for Kubeless in an PowerShell session:
``` 
$RELEASE="v1.0.0-beta.0"
kubectl create -f https://github.com/kubeless/kafka-trigger/releases/download/$RELEASE/kafka-zookeeper-$RELEASE.yaml
``` 

Create kubeless function:
``` 
kubeless function deploy echokafka --runtime apl17.0 --from-file test-echo-kafka.dyalog  --handler test-echo-kafka.echokafka 
``` 

Run kubeless function:
``` 
kubeless function call echo --data '{"Hallo":"APL"}'


Create Kafka Trigger:
``` 
kubeless trigger kafka create test-kafka-echo --function-selector created-by=kubeless,function=echokafka --trigger-topic echo-topic
``` 

Create Kafka  topic:
``` 
kubeless topic create echo-topic
``` 

List valable Kafka T topic:
``` 
kubeless topic ls
``` 

Publish APL event of Kafka topic (queue):
``` 
kubeless topic publish --topic echo-topic --data "Hello kafka from APL!"
``` 

In order to check if the event is dequeded, list all pods
``` 
kubectl get pods --all-namespaces
``` 
and find one with echokafka function.

In Log pods log 
``` 
kubectl logs halloapl-<XYZ>
``` 
should be visiable "Hello kafka from APL!" i.e. the event is dequeded from Kfaka topic.

On the end trigger can be deleted with:
``` 
kubeless trigger kafka delete test-kafka-halloapl
``` 

## Delete Kubeless function ##
To delete function run:
``` 
kubeless function delete foo
``` 