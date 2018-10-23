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
kubeless function deploy hallo --runtime apl17.0 --from-file test.dyalog  --handler test.hallo 
``` 

**Run kubeless function:**
``` 
kubeless function call hallo --data 'Hallo world'
``` 

**Note:** As Istio is not installed livlenes probe is not connected with any cisrtut breake code. Therefore some half of minute is needed from is created to be operatinoal.


# HTTP Triger#



## Autoscaling ##
Update function and set up autoscale:
``` 
kubeless function update hallo --runtime apl17.0 --from-file test.dyalog  --handler test.hallo --cpu 200m --memory 50M 
kubeless autoscale create hallo --min 1 --max 4  --value 50
``` 

To see curent auto scale:
``` 
kubeless autoscale list
``` 

Check if it works:
``` 
kubeless function call hallo --data 'Hallo world'
``` 

Start 4 powershell session in the directory to place where is cloned 
https://github.com/mvranic/kubeless-apl-demo.git .

Start 
``` 
./loop.ps1
``` 
which just runs function call.

In the minute the values in the powershell window with 
``` 
kubectl get pods -w
kubectl get hpa -w
``` 
will show that new pods are deployed and number of replcas are incremented.

Stop the loop scriot in the powershlle windows. Aftre that the pods will be terminated and number of replicas is decremted to 1.

## Perfomance ##
To measure perfomance, the HTTP triger should be used. Therefore deployed function service is exposed:

``` 
kubectl expose deployment hallo --type=NodePort --name=my-hallo
``` 

Get service IP and port:

``` 
kubectl get services my-hallo
``` 

Switch to Linux subssytem and to run *curl* and *ab* (Appache banchmark)  tools.
``` 
bash
``` 

Try to acccess to expoesde service on hallo function:
``` 
curl -L --data '"Hallo apl"' \
  --header "Content-Type:application/json" \
  localhost:8001/api/v1/namespaces/default/services/hallo:http-function-port/proxy/
``` 

Install ab tool if it is not present.
``` 
apt-get update
apt-get install apache2-utils
``` 

Run perfomance test:
``` 
ab -T "application/json" -p ./postdata.txt -c 20 -n 1000 localhost:8001/api/v1/namespaces/default/services/hallo:http-function-port/
``` 

Cleanup of exposed service:
```
kubectl delete services my-hallo
```

## Pub-Sub example - Kafka ##

## Delete function ##
To delete function run:
``` 
kubeless function delete hallo
``` 