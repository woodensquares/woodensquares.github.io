+++
type = "post"
title = "Kubernetes and Xen, part 6: kubelet and other services"
description = ""
tags = [
    "xen",
    "kubernetes"
]
date = "2017-12-14T09:29:59-08:00"
categories = [
    "Applications",
]
shorttitle = "Kubernetes and Xen - part 6"
changelog = [
    "Initial release - 2017-12-14",
]
+++

In the [previous part of the guide]({{< ref "xen-5.md" >}}) we have shown how
thanks to flannel our docker containers can talk to each other across our
physical nodes. It is now time to actually start looking at the services that
make our cluster a Kubernetes cluster.

# Kubelet

Kubelet is the last service that is directly managed by CoreOS in our
installation, it runs on all the nodes and besides receiving commands from
other Kubernetes components, it will also help bootstrap the cluster by
starting the remaining pieces via manifest files.

https://kubernetes.io/docs/admin/kubelet-authentication-authorization/

Kubelet has its own service definition we will create outright via the
Ignition systemd section:

{{< highlight bnf >}}
    - name: kubelet.service
      enabled: true
      contents: |
        [Service]
        Restart=always
        RestartSec=10
        Environment=KUBELET_IMAGE_TAG=v1.8.4_coreos.0
        ExecStart=/usr/lib/coreos/kubelet-wrapper \
                --require-kubeconfig \
                --kubeconfig=/etc/kubernetes/cfg/kubelet.cfg \
                --register-node=true \
                --allow-privileged=true \
                --cluster-dns=10.199.0.10 \
                --cluster-domain=cluster.local \
                --pod-manifest-path=/etc/kubernetes/manifests \
                --enable-custom-metrics=true \
                --v=2
        [Install]
        WantedBy=multi-user.target
{{< /highlight >}}

as much as kubelet does depend on docker to actually start the containers, you
might want to think carefully about making it a dependency, see [for example
this discussion about
it](https://github.com/coreos/coreos-kubernetes/issues/545).

The options above are fairly straightforward, if you want more detail you can
[look them up
online](https://kubernetes.io/docs/reference/generated/kubelet/), but on a
running system you can simply docker into any hyperkube containers and just
run it with -help, which also helps in case you are not running the latest
release which might differ in terms of available options. For example

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="solar-earth" path="~" >}}
docker ps | grep hyperkube
{{< /terminal-command >}}
{{< terminal-output >}}
c13a0aec80c3        gcr.io/google_containers/hyperkube@sha256:a68d3ebeb5d8a8b4b9697a5370ea1b7ad921c403cd7429c7ac859193901c9ded   "/bin/bash -c '/contr"   8 minutes ago       Up 8 minutes                            k8s_kube-controller-manager_kube-controller-manager-solar-earth_kube-system_c483efd67fc3ec53dba56e58eedf3d5c_3
6f1e40cb5a69        gcr.io/google_containers/hyperkube@sha256:a68d3ebeb5d8a8b4b9697a5370ea1b7ad921c403cd7429c7ac859193901c9ded   "/bin/bash -c '/sched"   8 minutes ago       Up 8 minutes                            k8s_kube-scheduler_kube-scheduler-solar-earth_kube-system_295842a1063467946b49b059a8b55c8b_3
56a425f51ceb        gcr.io/google_containers/hyperkube@sha256:a68d3ebeb5d8a8b4b9697a5370ea1b7ad921c403cd7429c7ac859193901c9ded   "/bin/bash -c '/proxy"   8 minutes ago       Up 8 minutes                            k8s_kube-proxy_kube-proxy-solar-earth_kube-system_279180e8dd21f1066568940ef66762e4_3
d1408774e129        gcr.io/google_containers/hyperkube@sha256:a68d3ebeb5d8a8b4b9697a5370ea1b7ad921c403cd7429c7ac859193901c9ded   "/bin/bash -c '/apise"   8 minutes ago       Up 8 minutes                            k8s_kube-apiserver_kube-apiserver-solar-earth_kube-system_09b4691a8d49eb9038ca56ce4543554a_3
{{< /terminal-output >}}
{{< terminal-command user="root" host="solar-earth" path="~" >}}
docker exec -it c13a0aec80c3 /bin/bash
{{< /terminal-command >}}
{{< terminal-command user="root" host="-" path="~" >}}
/hyperkube kubelet --help
{{< /terminal-command >}}
{{< terminal-output >}}
The kubelet binary is responsible for maintaining a set of containers on a

  particular node. It syncs data from a variety of sources including a
  Kubernetes API server, an etcd cluster, HTTP endpoint or local file. It then
  queries Docker to see what is currently running.  It synchronizes the
  configuration data, with the running set of containers by starting or stopping
  Docker containers.
Usage:
  kubelet [flags]

Available Flags:
      --address ip                                               The IP address for the Kubelet to serve on (set to 0.0.0.0 for all interfaces) (default 0.0.0.0)
      --allow-privileged                                         If true, allow containers to request privileged mode.
      --allow-verification-with-non-compliant-keys               Allow a SignatureVerifier to use keys which are technically non-compliant with RFC6962.
...
{{< / terminal-output >}}

{{< /terminal >}}

The options above tell the kubelet first of all to use a kubeconfig file (note
that require-kubeconfig [might be
needed](https://github.com/kubernetes/kubernetes/issues/36745) to actually
have the file take effect if you are running 1.7.x) to configure talking to
the apiserver (when it comes up of course, it isn't running yet). This file
looks like this

{{< highlight bnf >}}
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/ssl/ca.pem
    server: https://192.168.100.20:8443
  name: etcd.local
contexts:
- context:
    cluster: etcd.local
    user: kubelet
  name: etcd.local
current-context: etcd.local
kind: Config
preferences: {}
users:
- name: kubelet
  user:
    as-user-extra: {}
    client-certificate: /etc/kubernetes/ssl/kubelet-client.pem
    client-key: /etc/kubernetes/ssl/kubelet-client-key.pem
    token: a0513e58701641f699f020cd4c5b3ad3
{{< / highlight >}}

as you can see it simply tells kubectl what CA/certs to use, and the Xen guest
address where the apiserver will be listening to, this is .20 as it will be
running on the master. This file is the same in structure on all the nodes,
but every node will have its own certificate, key and token which will be used
to authenticate on the API server.

Other options are as follows:

   * **--allow-privileged**: allows the container to request privileged mode
   * **--cluster-dns=10.199.0.10**: when we'll start kube-dns later on, it
     will listen on this cluster address
   * **--cluster-domain=cluster.local**: just an internal domain for our
     cluster, will be also usable for resolution
   * **--enable-custom-metrics=true**: not using it yet, but will allow for
        custom metrics
   * **--pod-manifest-path=/etc/kubernetes/manifests**: this is where we will
     put the manifest files for the containers we want kubelet to launch when
     it starts up (apiserver, kube-proxy, ...)
   * **--register-node=true**: this will cause our node to be registered in the
     API server when it comes up (this is usually true already by default)
   * **--v=2**: verbose level, if you are debugging this can be bumped up, up
     to you what level you prefer to have by default.

as you can see it is fairly straightforward. You might also want to create
custom certificates for kubelet to serve its own API [as described
here](https://kubernetes.io/docs/admin/kubelet-authentication-authorization/)
and have kubelet clients (say, the apiserver) use them, however I have run
into issues with kubelet still creating its own CA (which meant the API server
was not able to talk to it successfully), I might revisit this later on, but
this is what I am seeing with that configuration.

{{< highlight bnf >}}
# In the apiserver options add
    --kubelet-certificate-authority=/etc/kubernetes/ssl/ca.pem
    --kubelet-client-certificate=/etc/kubernetes/ssl/kubelet-client.pem
    --kubelet-client-key=/etc/kubernetes/ssl/kubelet-client-key.pem

# In the kubelet options add
    --tls-cert-file=/etc/kubernetes/ssl/kubelet.pem \
    --tls-private-key-file=/etc/kubernetes/ssl/kubelet-key.pem \
    --client-ca-file=/etc/kubernetes/ssl/ca.pem \

# Command and error
$ kubectl exec -i --tty busybox -- nslookup nodejs-app-svc.default.svc.cluster.local
Error from server: error dialing backend: x509: certificate signed by unknown authority

# Logfile error on the master
I1207 21:27:18.698380       5 pathrecorder.go:247] kube-aggregator: "/api/v1/namespaces/default/pods/busybox/exec" satisfied by prefix /api/
I1207 21:27:18.698467       5 handler.go:150] kube-apiserver: POST "/api/v1/namespaces/default/pods/busybox/exec" satisfied by gorestful with webservice /api/v1
E1207 21:27:18.705053       5 status.go:62] apiserver received an error that is not an metav1.Status: error dialing backend: x509: certificate signed by unknown authority
{{< /highlight >}}

given this I am leaving those options now for the time being and just let
kubelet create its own self signed certificates.

# Kube-proxy

With kubelet up and running we can now start creating manifests for the
Kubernetes containers we want to be always running in our system. The first
order of business is to be able to route requests over the cluster network
(10.199.0.0/16 in our case) and to do this we need to use kube-proxy.

Here is the yaml file we will be putting in the manifests subdirectory we just
told kubelet to use (note this is exactly the same for all nodes, as
kube-proxy needs to be running everywhere)

{{< highlight bnf "hl_lines=16-23 38" >}}
apiVersion: v1
kind: Pod
metadata:
  annotations:
    scheduler.alpha.kubernetes.io/critical-pod: ""
  creationTimestamp: null
  labels:
    k8s-app: kube-proxy
    tier: node
  name: kube-proxy
  namespace: kube-system
spec:
  containers:
  - name: kube-proxy
    image: gcr.io/google_containers/hyperkube:v1.8.4
    command:
    - /bin/bash
    - -c
    - "/proxy
    --kubeconfig=/etc/kubernetes/cfg/kube-proxy.cfg
    --proxy-mode=iptables
    --cluster-cidr=172.16.0.0/16
    --v=2 2>&1 | /usr/bin/tee /var/log/kubernetes/kube-proxy.log"
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /var/log/kubernetes
      name: varlog
    - mountPath: /etc/kubernetes/cfg
      name: config-kubernetes
      readOnly: true
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  hostNetwork: true
  volumes:
  - hostPath:
      path: /var/log/kubernetes
    name: varlog
  - hostPath:
      path: /etc/kubernetes/cfg
    name: config-kubernetes
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
{{< /highlight >}}

I have highlighted the important lines above, first of all notice we want the
container to use the **host network**, this is because we are asking
kube-proxy to work in *iptables* mode, where we want it to create iptables
rule in our node's iptables, **not** in the container's docker interface
iptables (otherwise it would not work).

You can see for example here that kube-proxy has added several iptables rules
on our host to access the services we are running on the cluster IPs

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="solar-earth" path="~" >}}
iptables -t nat -L
{{< /terminal-command >}}
{{< terminal-output >}}
....
Chain KUBE-SERVICES (2 references)
target     prot opt source               destination         
KUBE-MARK-MASQ  tcp  -- !172.16.0.0/16        10.199.0.1           /* default/kubernetes:https cluster IP */ tcp dpt:https
KUBE-SVC-NPX46M4PTMTKRN6Y  tcp  --  anywhere             10.199.0.1           /* default/kubernetes:https cluster IP */ tcp dpt:https
KUBE-MARK-MASQ  tcp  -- !172.16.0.0/16        10.199.247.78        /* default/hostnames:default cluster IP */ tcp dpt:http
KUBE-SVC-ODX2UBAZM7RQWOIU  tcp  --  anywhere             10.199.247.78        /* default/hostnames:default cluster IP */ tcp dpt:http
KUBE-MARK-MASQ  udp  -- !172.16.0.0/16        10.199.0.10          /* kube-system/kube-dns:dns cluster IP */ udp dpt:domain
KUBE-SVC-TCOU7JCQXEZGVUNU  udp  --  anywhere             10.199.0.10          /* kube-system/kube-dns:dns cluster IP */ udp dpt:domain
KUBE-MARK-MASQ  tcp  -- !172.16.0.0/16        10.199.0.10          /* kube-system/kube-dns:dns-tcp cluster IP */ tcp dpt:domain
KUBE-SVC-ERIFXISQEP7F7OF4  tcp  --  anywhere             10.199.0.10          /* kube-system/kube-dns:dns-tcp cluster IP */ tcp dpt:domain
KUBE-MARK-MASQ  tcp  -- !172.16.0.0/16        10.199.12.23         /* kube-system/kubernetes-dashboard: cluster IP */ tcp dpt:https
KUBE-SVC-XGLOHA7QRQ3V22RZ  tcp  --  anywhere             10.199.12.23         /* kube-system/kubernetes-dashboard: cluster IP */ tcp dpt:https
KUBE-NODEPORTS  all  --  anywhere             anywhere             /* kubernetes service nodeports; NOTE: this must be the last rule in this chain */ ADDRTYPE match dst-type LOCAL
...
{{< / terminal-output >}}
{{< /terminal >}}

the other options in the invocation are as follows, first of all note I am
launching it via /bin/bash -c, this is to have the log available also on the
node in /var/log, you might not necessarily want this but I find it has been
helpful when debugging issues.

Other options are as follows

   * **--kubeconfig=/etc/kubernetes/cfg/kube-proxy.cfg**: same as above, tells
    kube-proxy to use a kubeconfig to talk to the API server, this is pretty
    much the same as the kubelet one, only with different certificates of course
   * **--proxy-mode=iptables**: as discussed, this will tell kube-proxy to
    create iptables rules
   * **--cluster-cidr=172.16.0.0/16**: this is the network we are using for
    our PODs
   * **--v=2**: verbose level as usual

note that possibly in next versions of Kubernetes you might have to write a
configuration file for kube-proxy rather than passing these options directly.

# API server

Now that all the networking is set up, we can start looking at the actual
Kubernetes services, all of these (master, controller manager and scheduler)
will be running only on our master, which is where we'll put the relevant
manifests.

For the API server the manifest looks as follows

{{< highlight bnf >}}
apiVersion: v1
kind: Pod
metadata:
  annotations:
    dns.alpha.kubernetes.io/internal: k8s-api.cluster.local
  creationTimestamp: null
  labels:
    k8s-app: kube-apiserver
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - name: kube-apiserver
    image: gcr.io/google_containers/hyperkube:v1.8.4
    command:
    - /bin/bash
    - -c
    - "/apiserver
    --allow-privileged=true
    --bind-address=0.0.0.0
    --advertise-address=192.168.100.20
    --secure-port=8443
    --insecure-port=0
    --service-cluster-ip-range=10.199.0.0/16
    --anonymous-auth=false
    --authorization-mode=Node,RBAC
    --admission-control=NodeRestriction,NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,DefaultTolerationSeconds,ResourceQuota
    --service-account-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    --runtime-config=api/all=true,batch/v2alpha1=true,rbac.authorization.k8s.io/v1alpha1=true
    --token-auth-file=/etc/kubernetes/auth/known_tokens.csv
    --basic-auth-file=/etc/kubernetes/auth/basic_auth.csv
    --etcd-servers=https://192.168.100.21:2379,https://192.168.100.22:2379,https://192.168.100.23:2379
    --etcd-cafile=/etc/kubernetes/ssl/etcd-ca.pem
    --etcd-certfile=/etc/kubernetes/ssl/etcd-client.pem
    --etcd-keyfile=/etc/kubernetes/ssl/etcd-client-key.pem
    --tls-cert-file=/etc/kubernetes/ssl/apiserver.pem
    --tls-private-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    --client-ca-file=/etc/kubernetes/ssl/ca.pem
    --v=2 2>&1 | /usr/bin/tee /var/log/kubernetes/apiserver.log"
    securityContext:
      privileged: true
    ports:
    - containerPort: 8443
      hostPort: 8443
      name: https
    volumeMounts:
    - mountPath: /var/log/kubernetes
      name: varlog
    - mountPath: /etc/kubernetes/cfg
      name: config-kubernetes
      readOnly: true
    - mountPath: /etc/kubernetes/auth
      name: auth-kubernetes
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  hostNetwork: true
  volumes:
  - hostPath:
      path: /var/log/kubernetes
    name: varlog
  - hostPath:
      path: /etc/kubernetes/cfg
    name: config-kubernetes
  - hostPath:
      path: /etc/kubernetes/auth
    name: auth-kubernetes
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
{{< /highlight >}}

As you can see there are a lot of parameters here, let's break them down in
groups:

## Etcd parameters

These are the parameters that tell our apiserver how to contact the etcd
cluster we have set up, these are quite straightforward

{{< highlight bnf >}}
    --etcd-servers=https://192.168.100.21:2379,https://192.168.100.22:2379,https://192.168.100.23:2379
    --etcd-cafile=/etc/kubernetes/ssl/etcd-ca.pem
    --etcd-certfile=/etc/kubernetes/ssl/etcd-client.pem
    --etcd-keyfile=/etc/kubernetes/ssl/etcd-client-key.pem
{{< /highlight >}}

note that unlike flannel, the API server uses etcdv3, so if you ever wanted to
completely reset your Kubernetes installation via removing all of the
keys/values (say, by starting only the etcd nodes of your cluster, and not the
master, and running *etcdctl del /registry --prefix*), you would have to use
that API version. Note the templates will set up the correct environment
variables for you to use etcdctl, you just have to export **ETCDCTL_API** set
to 2 or 3 before running etcdctl to choose.

## Connection-related parameters

these set up how our clients are going to connect to us

{{< highlight bnf >}}
    --bind-address=0.0.0.0
    --advertise-address=192.168.100.20
    --secure-port=8443
    --insecure-port=0
    --anonymous-auth=false
    --token-auth-file=/etc/kubernetes/auth/known_tokens.csv
    --basic-auth-file=/etc/kubernetes/auth/basic_auth.csv
    --tls-cert-file=/etc/kubernetes/ssl/apiserver.pem
    --tls-private-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    --client-ca-file=/etc/kubernetes/ssl/ca.pem
{{< /highlight >}}

let's look at them individually

   * **--bind-address**: this will bind us to all our interfaces
   * **--advertise-address**: here we are advertising the address of our Xen
     node directly, if you had multiple api-servers you might want to revisit
     this.
   * **--secure-port**: the port we are choosing to serve on, as discussed in
     the iptables rules we are using 8443 for our masters
   * **--insecure-port**: setting 0 disables it entirely
   * **--anonymous-auth**: do not want this on
   * **--token-auth-file**: the file containing the tokens (see later)
   * **--basic-auth-file**: the file containing basic auth logins (see later)
   * **--tls-cert-file**: the cert we are using to serve
   * **--tls-private-key-file**: its private key
   * **--client-ca-file**: the CA

It is to be noted that the server certificate file here should have several
IPs in its SAN line, this is because the API server is going to be accessed
over several different IPs, both from within the cluster, from your local Xen
node, as well as from other computers on your LAN, for example my api server
certificate has the following SAN line

{{< highlight bnf >}}
   DNS:solar-earth, 
   IP Address:10.199.0.1, 
   IP Address:192.168.100.20, 
   IP Address:192.168.1.45, 
   IP Address:192.168.100.1
{{< /highlight >}}

as discussed 192.168.1.45 is my local LAN address the Xen box answers to.

## Other parameters

The other parameters are as follows

   * **--allow-privileged**: same as for kube-proxy, allow the api server
     access our node's interfaces directly
   * **--service-cluster-ip-range**: the cluster network we decided on
   * **--authorization-mode**: Node and RBAC for us
   * **--admission-control**: this is really up to you, here is a sample
   * **--service-account-key-file**: used by the API server to sign bearer
     tokens
   * **--runtime-config**: this is also really up to you, there is [some
   discussion here for
   example](https://github.com/kubernetes/website/issues/2979) about possible
   values to add

# Controller-manager

The controller manager has a fairly straightforward configuration, only the
highlighted lines below contain settings we haven't seen before


{{< highlight bnf "hl_lines=15 20 24">}}
apiVersion: v1
kind: Pod
metadata:
  name: kube-controller-manager
  namespace: kube-system
spec:
  containers:
  - name: kube-controller-manager
    image: gcr.io/google_containers/hyperkube:v1.8.4
    command:
    - /bin/bash
    - -c
    - "/controller-manager
    --kubeconfig=/etc/kubernetes/cfg/kube-controller-manager.cfg
    --allocate-node-cidrs=true
    --cluster-cidr=172.16.0.0/16
    --cluster-name=cluster.local
    --service-cluster-ip-range=10.199.0.0/16
    --root-ca-file=/etc/kubernetes/ssl/ca.pem
    --configure-cloud-routes=false
    --service-account-private-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    --cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem
    --cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem
    --use-service-account-credentials=true
    --v=2 2>&1 | /usr/bin/tee /var/log/kubernetes/kube-controller-manager.log"
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /var/log/kubernetes
      name: varlog
    - mountPath: /etc/kubernetes/cfg
      name: config-kubernetes
      readOnly: true
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /var/log/kubernetes
    name: varlog
  - hostPath:
      path: /etc/kubernetes/cfg
    name: config-kubernetes
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
{{< /highlight >}}

the options are

   * **--allocate-node-cidrs**: since we are on our bare-metal installation
     this is not needed
   * **--configure-cloud-routes**: same as above
   * **--use-service-account-credentials**: we currently have only one
     controller, this is really up to you

# Scheduler

The final service we are going to run is the scheduler, which as you can see
basically has no options outside of the configuration to use to connect to the
API server

{{< highlight bnf >}}
apiVersion: v1
kind: Pod
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  containers:
  - name: kube-scheduler
    image: gcr.io/google_containers/hyperkube:v1.8.4
    command:
    - /bin/bash
    - -c
    - "/scheduler
    --kubeconfig=/etc/kubernetes/cfg/kube-scheduler.cfg
    --v=2 2>&1 | /usr/bin/tee /var/log/kubernetes/kube-scheduler.log"
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /var/log/kubernetes
      name: varlog
    - mountPath: /etc/kubernetes/cfg
      name: config-kubernetes
      readOnly: true
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /var/log/kubernetes
    name: varlog
  - hostPath:
      path: /etc/kubernetes/cfg
    name: config-kubernetes
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
{{< /highlight >}}

# Authentication, tokens and certificates

As discussed a few times in this series of posts, we have set up Kubernetes to
work with RBAC turned on, this [is discussed in more detail on the official
documentation here](https://kubernetes.io/docs/admin/authorization/rbac/) but
basically our requests come in as specified users, which have roles associated
to them.

Identifying and authenticating users is done by the API server in two
different ways, one via the CN and O we put in our certificates (for example
the client certificate you are using in kubectl to connect to the master is
for the "admin" user which is set to the "system:masters" group), and the
other via tokens we generate when we set things up (this is how you have
authenticated to the dashboard)

This is a bit of a belt-and-suspenders approach, however I figured it wouldn't
hurt to use both certificate credentials and tokens. For example the generated
tokens file the admin server loads up is as follows 

{{< highlight bnf >}}
a0513e58701641f699f020cd4c5b3ad3,system:node:solar-earth,system:node:solar-earth,system:nodes
5299ad7c757e43c1878930d4c2c5df6e,system:kube-proxy,system:kube-proxy,system:node-proxier
df7fd45844854ea49cb423fd57a4f78e,system:node:solar-mercury,system:node:solar-mercury,system:nodes
217cecbad2ba446dbddf923ac7c2d805,system:kube-proxy,system:kube-proxy,system:node-proxier
1cb574ea1cc54342b6204aa57b771901,system:node:solar-venus,system:node:solar-venus,system:nodes
446bf9f521ea43aeacb7bbe1dbf6c6c1,system:kube-proxy,system:kube-proxy,system:node-proxier
ef50bc922dff40d9ba46aac693a79608,system:node:solar-mars,system:node:solar-mars,system:nodes
8981e36cf5784fcf8ba1f30d79883338,system:kube-proxy,system:kube-proxy,system:node-proxier
d7963e15a8a844caa1034384f07d7903,system:node:solar-jupiter,system:node:solar-jupiter,system:nodes
1430305a59b84dd897ee3fe559b8a6b3,system:kube-proxy,system:kube-proxy,system:node-proxier
5474bef8106445698aac88941845b9d2,system:node:solar-saturn,system:node:solar-saturn,system:nodes
e6ad978dd5c749a3892a20a5c9536c57,system:kube-proxy,system:kube-proxy,system:node-proxier
31830467b6b7464e8b77220b38fa8e24,system:kube-controller-manager,system:kube-controller-manager,system:kube-controller-manager
d9234b8409c547e99a66242c38029d99,system:kube-scheduler,system:kube-scheduler,system:kube-scheduler
64f824dbf7844496ba371fe8e4b1de11,admin,admin,system:masters
{{< /highlight >}}

as you can see it has tokens for all the node proxies and kubelets (kubelets
need to authenticate as system:node:[nodename] and be part of the system:nodes
group), as well as tokens for the master services and the superuser client
certificate we are using in kubectl

You can explore the roles and users defined in your cluster by using kubectl
and executing commands like **get clusterrole** **get clusterrolebindings**
**get serviceaccounts**, passing **-o yaml** to the command will display the
actual contents of the specified resource.

# Other services

As you've seen in the previous walkthrough, you can now install additional
services in your cluster as usual, in the walkthrough besides some debugging
tools like busybox and hostnames, we set up kube-dns and the dashboard, but of
course there are a lot more things you could be running. In future posts I
will likely describe how to set up an ingress controller and deploy your own
REST services in the cluster.

# And we are done!

This has been a long article series, you can now take another look at [the
"putting it all together" post]({{< ref "xen-final.md" >}}) and explore the
various template files used to generate the ignition configuration files, as
well as of course ssh'ing into your cluster nodes and taking a closer look at
what's going on.

Have fun and of course please [let me know](/pages/about.html) if you spot any
issues/errors in the information I have presented. As you've seen there are a
lot of moving parts in a Kubernetes installation so it is quite easy to get
things wrong, but when you get them wrong and have to fix them is when you
actually learn about what's really going on, which is of course quite helpful
and why despite the easy availability of cloud resources it is nice to be able
to try running things locally on bare-metal whenever possible.

# Thanks

This series would not have been possible without the large amount of
documentation available [on the Kubernetes
website](https://kubernetes.io/docs/home/) it is sometimes hard to find what
you need, but it usually is there.

I have also benefitted from looking at other people's Kubernetes set ups, each
with their own specific trade offs (RBAC on/off, kubeadm or not, bare metal or
cloud, ...) and targeted to other versions of Kubernetes. Here they are in no
particular order

  * https://github.com/kelseyhightower/kubernetes-the-hard-way
  * https://icicimov.github.io/blog/kubernetes/Kubernetes-cluster-step-by-step/
  * https://andrewmichaelsmith.com/2016/05/my-kubernetes-setup/
  * https://blog.alexellis.io/kubernetes-in-10-minutes/
  * https://nixaid.com/deploying-kubernetes-cluster-from-scratch/
  * http://www.yet.org/2016/06/tectonic/
  * https://mihok.today/2016/07/22/setting-up-a-custom-kubernetes-cluster-on-ubuntu-14-04-1/
  * http://khmel.org/?p=1080



