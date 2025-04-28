+++
type = "post"
title = "Kubernetes and Xen, part 5: Flanneld"
description = ""
tags = [
    "xen",
    "kubernetes"
]
date = "2017-12-14T09:29:53-08:00"
categories = [
    "Applications",
]
shorttitle = "Kubernetes and Xen - part 5"
changelog = [
    "Initial release - 2017-12-14",
]
+++

In the [previous part of the guide]({{< ref "xen-4.md" >}}) we have created an
actual working etcd cluster, building on the lessons learned there we will now
create the actual Kubernetes installation.

# Network layout

Before continuing, let's clarify what network layout we want to achieve for
our cluster. There are several networks in our configuration and it's
important to keep that in mind to understand what's going on.

## Physical network

This is the network that you use to access your Dom0 installation from other
computers on your network, for all the following pages you will see that my
Dom0 is accessible as 192.168.1.45, my home network is 192.168.1.xxx. This is
on your physical network interface in your Dom0 (typically eth0, eno1 in my
case).

## Xen network

This is the network that all your Xen guests, our Kubernetes nodes from now
on, communicate on, it's what dnsmasq will give IP addresses to all your
guests from, for our etcd and Kubernetes clusters this is 192.168.100.0/24, we
will have clusters take 10 address blocks in this from 10-19 to 90-99, and our
failsafe on 192.168.100.254 as you've seen previously.

## Flannel network

This is the overlay network over the various pod networks that flannel will
enable us to use to communicate among pods in different Xen guests, this for
us will be 

## Cluster service network

This is the network where services will be exposed on our cluster if we decide
to do so, it will be 10.199.0.0/16

# What type of Kubernetes cluster we'll be building

There are many online resources discussing how Kubernetes is laid out from an
operational standpoint, I will not reiterate the information available there
and from now on you are expected to be somewhat familiar with how Kubernetes
operates in general. 

In general we want to have a certain set of containers run on our Kubernetes
master (apiserver, scheduler, controller manager), which in our case is going
to be on 199.168.100.x0, a certain set of containers running on our etcd
cluster (etcd primarily), which will be part of the Kubernetes cluster, and a
set of containers running everywhere for the cluster to function (flannel,
kube-proxy, kubelet)

In our configuration all the containers will communicate with each other using
TLS, every one of them will have their own set of certificates, and there will
be three certificate authorities in the system: one for etcd, one for all
internal Kubernetes services, and not strictly related one that we'll use to
give certificates to any applications/pods we want to expose as nodeports.

Kubernetes will also be set up [with
RBAC](https://kubernetes.io/docs/admin/authorization/rbac/) enabled, and we
will be creating tokens corresponding to accounts as needed.

# How to follow this guide

In general I am not a fan of "skipping to the end" when it comes to books and
guides, however I don't think it would be that useful to show bringing up one
pod/daemon at a time, since all you would see most of the time would be just
error messages about how say kubelet is not able to register itself to the API
server and so on. Given this I think it would be a good idea to show things in
an actual running cluster, so please [follow the instructions on the final
page of the series]({{< ref "xen-final.md" >}}), set the cluster up and come
back here afterwards for a step-by-step analysis of how things are put
together.

# Flanneld

Our pods need to be able to talk to each other across different physical
nodes, [there are many different ways to set up a network in
Kubernetes](https://kubernetes.io/docs/getting-started-guides/scratch/#network)
but for our installation we will be using
[Flannel](https://github.com/coreos/flannel). As discussed above our Flannel
network will be 172.16.0.0/16.

Let's now ssh to our master for example and look at what the flanneld unit
looks like

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
ssh core@192.168.100.20
{{< /terminal-command >}}
{{< terminal-command user="core" host="solar-earth" path="~" >}}
sudo -i
{{< /terminal-command >}}
{{< terminal-command user="root" host="solar-earth" path="~" >}}
systemctl cat flanneld.service
{{< /terminal-command >}}
{{< terminal-output >}}
# /usr/lib/systemd/system/flanneld.service
[Unit]
Description=flannel - Network fabric for containers (System Application Container)
Documentation=https://github.com/coreos/flannel
After=etcd.service etcd2.service etcd-member.service
Requires=flannel-docker-opts.service

[Service]
Type=notify
Restart=always
RestartSec=10s
TimeoutStartSec=300
LimitNOFILE=40000
LimitNPROC=1048576

Environment="FLANNEL_IMAGE_TAG=v0.8.0"
Environment="FLANNEL_OPTS=--ip-masq=true"
Environment="RKT_RUN_ARGS=--uuid-file-save=/var/lib/coreos/flannel-wrapper.uuid"
EnvironmentFile=-/run/flannel/options.env

ExecStartPre=/sbin/modprobe ip_tables
ExecStartPre=/usr/bin/mkdir --parents /var/lib/coreos /run/flannel
ExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/lib/coreos/flannel-wrapper.uuid
ExecStart=/usr/lib/coreos/flannel-wrapper $FLANNEL_OPTS
ExecStop=-/usr/bin/rkt stop --uuid-file=/var/lib/coreos/flannel-wrapper.uuid

[Install]
WantedBy=multi-user.target

# /etc/systemd/system/flanneld.service.d/20-clct-flannel.conf
[Service]
ExecStart=
ExecStart=/usr/lib/coreos/flannel-wrapper $FLANNEL_OPTS
# /etc/systemd/system/flanneld.service.d/40-Fix-environment.conf
[Service]
ExecStartPre=/usr/bin/ln -sf /etc/flannel/environment /run/flannel/options.env
{{< /terminal-output >}}
{{< /terminal >}}

These files are created by the following lines in our ignition template

{{< highlight bnf >}}
# in the storage section

    - path: /etc/flannel/environment
      filesystem: root
      mode: 0644
      contents:
        inline: |
          FLANNELD_IFACE=192.168.100.20
          FLANNELD_ETCD_ENDPOINTS=https://192.168.100.21:2379,https://192.168.100.22:2379,https://192.168.100.23:2379
          FLANNELD_ETCD_CERTFILE=/etc/ssl/certs/etcd/client.pem
          FLANNELD_ETCD_KEYFILE=/etc/ssl/certs/etcd/client-key.pem
          FLANNELD_ETCD_CAFILE=/etc/ssl/certs/etcd/ca.pem

# elsewhere in the file
flannel: ~

# in the systemd section
    - name: flanneld.service
      enabled: true
      dropins:
        - name: 40-Fix-environment.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/ln -sf /etc/flannel/environment /run/flannel/options.env
{{< / highlight >}}

when flannel starts up, it will query the specified etcd servers for a
configuration file (note that currently flannel uses etcd v2). This
configuration file will tell flannel what overlay network to create. The
address of the servers to query is taken from the options.env file above,
which is symlinked to our configuration as part of the flannel unit startup.

By default of course there is nothing in etcd, the above ignition template is
the master's, but on the etcd members of our cluster the systemd section looks different

{{< highlight bnf "hl_lines=2 7-15 34">}}
# In the storage section
    - path: /etc/flannel/etcd.cfg
      filesystem: root
      mode: 0644
      contents:
        inline: |
          {
              "Network": "172.16.0.0/16",
              "SubnetLen": 24,
              "Backend": {
                  "Type": "vxlan",
                  "VNI": 1,
                  "Port": 8472
              }
          }

# In the systemd section
    - name: flanneld.service
      enabled: true
      dropins:
        - name: 40-Fix-environment.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/ln -sf /etc/flannel/environment /run/flannel/options.env
        - name: 50-network-config.conf
          contents: |
            [Unit]
            Requires=etcd-member.service
            [Service]
            Environment=ETCDCTL_CA_FILE=/etc/ssl/certs/etcd/ca.pem
            Environment=ETCDCTL_CERT_FILE=/etc/ssl/certs/etcd/client.pem
            Environment=ETCDCTL_KEY_FILE=/etc/ssl/certs/etcd/client-key.pem
            Environment=ETCDCTL_ENDPOINTS=https://192.168.100.21:2379,https://192.168.100.22:2379,https://192.168.100.23:2379
            ExecStartPre=/bin/bash -c '/usr/bin/etcdctl set /coreos.com/network/config < /etc/flannel/etcd.cfg'
{{< / highlight >}}

as you can see, the flannel systemd unit on our etcd nodes will wait for etcd
to become available, and then will insert the flannel configuration contained
in the /etc/flannel/etcd.cfg file, which will then become accessible from all
our nodes in the cluster. Since the value being inserted is the same in all
the etcd nodes, it doesn't really matter if all our etcd servers do insert
this, also considering this is after all just a development environment.

Once flanneld gets the configuration from etcd, it will create a local
interface, and save what it has done in some additional files in /run/flannel/
that for example docker will need.

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="solar-earth" path="~" >}}
ip addr
{{< /terminal-command >}}
{{< terminal-output >}}
...
3: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default 
    link/ether 56:bf:0a:4e:84:d5 brd ff:ff:ff:ff:ff:ff
    inet 172.16.32.0/32 scope global flannel.1
       valid_lft forever preferred_lft forever
    inet6 fe80::54bf:aff:fe4e:84d5/64 scope link 
       valid_lft forever preferred_lft forever
...
{{< /terminal-output >}}
{{< terminal-command user="root" host="solar-earth" path="~" >}}
cat /run/flannel/flannel_docker_opts.env
{{< /terminal-command >}}
{{< terminal-output >}}
DOCKER_OPT_BIP="--bip=172.16.32.1/24"
DOCKER_OPT_IPMASQ="--ip-masq=false"
DOCKER_OPT_MTU="--mtu=1450"
{{< /terminal-output >}}
{{< /terminal >}}

for example on this node flannel has taken the 172.16.32.1 / 24 network, the
options in that file will be used by docker when it starts up afterwards.

# Docker

In order for docker to operate correctly, it needs to wait for the flannel
network to become available, this is why we have the following in our Ignition
template

{{< highlight bnf "hl_lines=8-9">}}
# In the systemd section
    - name: docker.service
      enabled: true
      dropins:
        - name: 50-opts.conf
          contents: |
            [Unit]
            Requires=flanneld.service
            After=flanneld.service
{{< / highlight >}}

once flannel is up, docker will also start and create its own interface
grabbing the next address in the local flannel network

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="solar-earth" path="~" >}}
ip addr
{{< /terminal-command >}}
{{< terminal-output >}}
...
4: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP group default 
    link/ether 02:42:c3:57:00:61 brd ff:ff:ff:ff:ff:ff
    inet 172.16.32.1/24 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:c3ff:fe57:61/64 scope link 
       valid_lft forever preferred_lft forever
...
{{< /terminal-output >}}
{{< /terminal >}}

if you exec inside a docker container that is not using host networking (in
this case for example let's take the kubernetes controller container), you
will see that docker has given it an address on the flannel network as well.

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="solar-earth" path="~" >}}
docker exec -it a1268ccc1337 /bin/bash
{{< /terminal-command >}}
{{< terminal-command user="root" host="-" path="~" >}}
ip addr
{{< /terminal-command >}}
{{< terminal-output >}}
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
5: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP group default 
    link/ether 02:42:ac:10:20:02 brd ff:ff:ff:ff:ff:ff
    inet 172.16.32.2/24 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:acff:fe10:2002/64 scope link 
       valid_lft forever preferred_lft forever
{{< /terminal-output >}}
{{< /terminal >}}

if now you for example ssh on a different node and enter a different
container, you will see you can ping this address no problem. Let's first find
out where our busybox pod is and ssh there

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="solar-saturn" path="/storage/xen/guests/solar" >}}
kubectl describe pod busybox
{{< /terminal-command >}}
{{< terminal-output >}}
Name:         busybox
Namespace:    default
Node:         solar-saturn/192.168.100.25
Start Time:   Sun, 10 Dec 2017 14:59:15 -0800
Labels:       <none>
.....
Status:       Running
IP:           172.16.94.2
Containers:
.........
{{< /terminal-output >}}
{{< terminal-comment >}}
It is on saturn, which is 192.168.100.25
{{< /terminal-comment >}}
{{< terminal-command user="root" host="solar-saturn" path="/storage/xen/guests/solar" >}}
ssh core@192.168.100.25
{{< /terminal-command >}}
{{< terminal-command user="core" host="solar-saturn" path="~" >}}
sudo -i
{{< /terminal-command >}}
{{< terminal-command user="root" host="solar-saturn" path="~" >}}
docker ps | awk '{ if ($2 == "busybox") { print $1 } }'
{{< /terminal-command >}}
{{< terminal-output >}}
7d639fb1f33c
{{< /terminal-output >}}
{{< terminal-command user="root" host="solar-saturn" path="/storage/xen/guests/solar" >}}
docker exec -it 7d639fb1f33c /bin/sh
{{< /terminal-command >}}
{{< terminal-command user="root" host="-" path="~" >}}
ip addr
{{< /terminal-command >}}
{{< terminal-output >}}
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
5: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1450 qdisc noqueue 
    link/ether 02:42:ac:10:5e:02 brd ff:ff:ff:ff:ff:ff
    inet 172.16.94.2/24 scope global eth0
       valid_lft forever preferred_lft forever
{{< /terminal-output >}}
{{< terminal-comment >}}
as you can see this is the same IP kubectl describe gave us
{{< /terminal-comment >}}
{{< terminal-command user="root" host="-" path="~" >}}
ping 172.16.32.2
{{< /terminal-command >}}
{{< terminal-output >}}
PING 172.16.32.2 (172.16.32.2): 56 data bytes
64 bytes from 172.16.32.2: seq=0 ttl=62 time=0.589 ms
64 bytes from 172.16.32.2: seq=1 ttl=62 time=0.404 ms
64 bytes from 172.16.32.2: seq=2 ttl=62 time=0.371 ms
^C
--- 172.16.32.2 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.371/0.454/0.589 ms
{{< /terminal-output >}}
{{< terminal-comment >}}
and we can ping the docker container on solar-earth no problem over the
flannel network.
{{< /terminal-comment >}}
{{< /terminal >}}

of course we could have directly executed the shell on busyboxy via kubectl
like **kubectl exec -i --tty busybox -- /bin/sh** but seeing it from the
bare-metal side makes it easier to understand what's going on.

Let's now continue to [the next part of the guide]({{< ref "xen-6.md" >}})


