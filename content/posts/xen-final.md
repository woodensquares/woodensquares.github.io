+++
type = "post"
title = "Kubernetes and Xen: Putting it all together"
description = ""
tags = [
    "xen",
    "kubernetes"
]
date = "2017-12-14T09:30:06-08:00"
categories = [
    "Applications",
]
shorttitle = "Kubernetes and Xen - part 7"
changelog = [
    "Initial release - 2017-12-14",
]
+++

This post is the final post in a series of articles describing how to set up
an RBAC+TLS-enabled bare metal Kubernetes cluster running on Xen, in order to
understand and follow the below instructions you might want to [start from the
beginning]({{< ref "xen-1.md" >}}).

This set of instructions depends on the following

  * You are running this on the Dom0 of a Xen installation configured as
    discussed in previous posts especially in terms of network (virbr1 etc.)
  * the XENDIR environmental variable has been correctly set, here it will be
    assumed to be /storage/xen
  * The xencd alias is available, it is provided in the functions.bashrc file
    below. Typically XENDIR/bin is also added to PATH
  * The specified [CoreOS](https://coreos.com) distribution has been downloaded and put in
    XENDIR/images with the coreos-xxxxxx.bin.bz2 naming convention, this was [discussed
    here]({{< ref "xen-3.md#coreos" >}})
  * No other bash alias/function for kgen, kgencert, etc. as described in previous
    pages of the guide is used, only the functions present in the
    functions.bashrc file listed here are in effect
  * [CFSSL](https://github.com/cloudflare/cfssl) has been installed and is
    available in PATH, this was [discussed here]({{< ref "xen-4.md#cfssl" >}})
  * [Nginx](https://nginx.org/) has been installed and configured to serve
    Ignition requests to our guests, this was [discussed here]({{< ref
    "xen-3.md#nginx" >}})
  * Firewall rules have been set in our Dom-0 to allow communication as
    needed, the rules.v4 file linked below should be used after changing
    192.168.1.45 to whatever the correct IP address is for your Dom0 LAN
    address.
  * The [ct config
    transpiler](https://coreos.com/os/docs/latest/overview-of-ct.html) is
    available in PATH, this was [discussed here]({{< ref
    "xen-3.md#ct" >}})
  * The kgenerate file listed below is put in PATH, and python (2 or 3), which
    it requires, is available.

The cluster we'll create will be named **solar** and will have a master node,
three etcd nodes and two additional non-etcd nodes. It will be using the
.20-.29 address space in our configuration and the individual Xen guest
hostnames will be solar-xxx as described below

{{< highlight bnf >}}
Master:   solar-earth          (192.168.100.20)
Etcd:     solar-mercury        (192.168.100.21)
Etcd:     solar-venus          (192.168.100.22)
Etcd:     solar-mars           (192.168.100.23)
Node:     solar-jupiter        (192.168.100.24)
Node:     solar-saturn         (192.168.100.25)
{{< / highlight >}}

To make things easier in some commands the following environmental variable
should be defined

```bash
KCLUSTER="earth mercury venus mars jupiter saturn"
```

# Distribution files

The needed files for the scripts are linked in the following list, note rules.v4 should be put
in **/etc/iptables/rules.v4** (don't forget to back up the file there and/or
to merge this with it if needed!) and **systemctl restart iptables-persistent** be
rerun afterwards.

<div class="highlight">
<pre class="chroma" tabindex="0">
<code class="language-bnf" data-lang="bnf"><span class="line"><span class="cl"><a href="/code/k8s/rules.v4">rules.v4</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/kgenerate">$XENDIR/bin/kgenerate</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/functions.bashrc">$XENDIR/guests/solar/functions.bashrc</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/yaml/hostnames.yaml">$XENDIR/guests/solar/yaml/hostnames.yaml</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/yaml/kubernetes-dashboard.yaml">$XENDIR/guests/solar/yaml/kubernetes-dashboard.yaml</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/yaml/dns.yaml">$XENDIR/guests/solar/yaml/dns.yaml</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/yaml/busybox.yaml">$XENDIR/guests/solar/yaml/busybox.yaml</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/scheduler.template">$XENDIR/guests/solar/templates/scheduler.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/kube-proxy.template">$XENDIR/guests/solar/templates/kube-proxy.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/etcd.template">$XENDIR/guests/solar/templates/etcd.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/node-other.template">$XENDIR/guests/solar/templates/node-other.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/systemd.template">$XENDIR/guests/solar/templates/systemd.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/flanneld.template">$XENDIR/guests/solar/templates/flanneld.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/profile.template">$XENDIR/guests/solar/templates/profile.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/storage.template">$XENDIR/guests/solar/templates/storage.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/storage-etcd.template">$XENDIR/guests/solar/templates/storage-etcd.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/controller.template">$XENDIR/guests/solar/templates/controller.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/storage-master.template">$XENDIR/guests/solar/templates/storage-master.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/apiserver.template">$XENDIR/guests/solar/templates/apiserver.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/kube-scheduler.template">$XENDIR/guests/solar/templates/kube-scheduler.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/kube-controller-manager.template">$XENDIR/guests/solar/templates/kube-controller-manager.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/node-master.template">$XENDIR/guests/solar/templates/node-master.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/node-etcd.template">$XENDIR/guests/solar/templates/node-etcd.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/proxy.template">$XENDIR/guests/solar/templates/proxy.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/kubelet.template">$XENDIR/guests/solar/templates/kubelet.template</a>
</span></span><span class="line"><span class="cl"><a href="/code/k8s/templates/flannel-setup.template">$XENDIR/guests/solar/templates/flannel-setup.template</a>
</span></span></code></pre></div>

[functions.bashrc]({{< ref "functions-bashrc.md" >}}) and [kgenerate]({{< ref
"kgenerate.md" >}}) are also available as syntax highlighted blog pages if you
want to take a look at what they do more easily. You could also edit
functions.bashrc and add the *export KCLUSTER=* line in there to make it
easier so it's set automatically every time you xencd to a cluster
subdirectory.

Here is a tarfile containing all of the files
[woodensquares-k8s.tar.bz2](/code/k8s/woodensquares-k8s.tar.bz2) in a guests/solar/
subdirectory and kgenerate in a bin/ subdirectory, if you want to use this you
can simply follow the next steps

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
export XENDIR=/storage/xen
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
cd $XENDIR/
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen" >}}
wget http://woodensquares.github.io/code/k8s/woodensquares-k8s.tar.bz2
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen" >}}
tar xvf woodensquares-k8s.tar.bz2
{{< /terminal-command >}}
{{< terminal-output >}}
./
./rules.v4
./bin/
./bin/kgenerate
./guests/
./guests/solar/
./guests/solar/functions.bashrc
./guests/solar/yaml/
./guests/solar/yaml/hostnames.yaml
./guests/solar/yaml/kubernetes-dashboard.yaml
./guests/solar/yaml/dns.yaml
./guests/solar/yaml/busybox.yaml
./guests/solar/templates/
./guests/solar/templates/scheduler.template
./guests/solar/templates/kube-proxy.template
./guests/solar/templates/etcd.template
./guests/solar/templates/node-other.template
./guests/solar/templates/systemd.template
./guests/solar/templates/flanneld.template
./guests/solar/templates/profile.template
./guests/solar/templates/storage.template
./guests/solar/templates/storage-etcd.template
./guests/solar/templates/controller.template
./guests/solar/templates/storage-master.template
./guests/solar/templates/apiserver.template
./guests/solar/templates/kube-scheduler.template
./guests/solar/templates/kube-controller-manager.template
./guests/solar/templates/node-master.template
./guests/solar/templates/node-etcd.template
./guests/solar/templates/proxy.template
./guests/solar/templates/kubelet.template
./guests/solar/templates/flannel-setup.template
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen" >}}
rm woodensquares-k8s.tar.bz2
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen" >}}
ls -la bin/
{{< /terminal-command >}}
{{< terminal-comment >}}
Make sure for example you have removed the old kgenct python script discussed
during the initial posts in this series, only ct and kgenerate are needed.
{{< /terminal-comment >}}
{{< terminal-output >}}
total 5748
drwxr-xr-x 2 root root    4096 Dec 12 17:06 .
drwxr-xr-x 7 root root    4096 Dec 12 16:41 ..
-rwxr-xr-x 1 root root 5871900 Sep 25 16:55 ct
-rwxr-xr-x 1 root root    1183 Dec 12 17:06 kgenerate
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen" >}}
cd $XENDIR/guests/solar
{{< /terminal-command >}}

{{< terminal-comment >}}
If you haven't done this yet
{{< /terminal-comment >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
aptitude install iptables-persistent
{{< /terminal-command >}}

{{< terminal-comment >}}
Otherwise you might want to back up your current rules
{{< /terminal-comment >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
cp /etc/iptables/rules.v4 /etc/iptables/rules.v4.presolar
{{< /terminal-command >}}

{{< terminal-comment >}}
Before copying the file don't forget to change 192.168.1.45 to your Dom0 LAN IP
{{< /terminal-comment >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
mv rules.v4 /etc/iptables/
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
systemctl restart netfilter-persistent
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
find .
{{< /terminal-command >}}
{{< terminal-output >}}
./functions.bashrc
./yaml/...
./templates/....
{{< /terminal-output >}}
{{< terminal-comment >}}
Let's run the xencd alias to source the functions
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
. functions.bashrc
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
xencd solar
{{< /terminal-command >}}

{{< terminal-comment >}}
You should have created this file already during the etcd steps, but this has
more IPs available so it might be useful to switch to it
{{< /terminal-comment >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
mv /var/lib/dnsmasq/virbr1/hostsfile /var/lib/dnsmasq/virbr1/hostsfile.presolar
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
echo 00:16:3e:ee:ee:01,192.168.100.254 > hostsfile
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
khostsfile >> hostsfile
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
mv hostsfile /var/lib/dnsmasq/virbr1
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
{{< /terminal-command >}}
{{< /terminal >}}


# Cluster creation

Let's now actually create the cluster

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
export KCLUSTER="earth mercury venus mars jupiter saturn"
{{< /terminal-command >}}
{{< terminal-comment >}}
create images with an extra 6GB of free space for the root
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kcreateimgs 1520.9.0 6144 $KCLUSTER
{{< /terminal-command >}}
{{< terminal-output >}}
Expanding /storage/xen/images/coreos-1520.9.0.bin.bz2 to earth.img
Adding 6144 megabytes to earth.img
6144+0 records in
6144+0 records out
6442450944 bytes (6.4 GB, 6.0 GiB) copied, xx.xxxx s, yyy MB/s
Expanding /storage/xen/images/coreos-1520.9.0.bin.bz2 to mercury.img
Adding 6144 megabytes to mercury.img
...
{{< /terminal-output >}}

{{< terminal-comment >}}
Generate all the Xen cfg files, this
will start IPs from .20 in terms of lease
master gets 2vcpu and an extra 512 of RAM in general
 1gb seems the minimum for RAM, but 1.5 is better esp. if running dashboard
{{< /terminal-comment >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kcreatecfg 20 $KCLUSTER
{{< /terminal-command >}}

{{< terminal-output >}}
Creating earth.cfg, will become 192.168.100.20 with mac 00:16:3e:4e:31:20
Creating mercury.cfg, will become 192.168.100.21 with mac 00:16:3e:4e:31:21
Creating venus.cfg, will become 192.168.100.22 with mac 00:16:3e:4e:31:22
Creating mars.cfg, will become 192.168.100.23 with mac 00:16:3e:4e:31:23
Creating jupiter.cfg, will become 192.168.100.24 with mac 00:16:3e:4e:31:24
Creating saturn.cfg, will become 192.168.100.25 with mac 00:16:3e:4e:31:25

The cluster was created with master: vcpu=2, mem=2048 nodes: vcpu=1 mem=1536
{{< /terminal-output >}}

{{< terminal-comment >}}
Generate all the certificates for all our nodes
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kgencert *.cfg
{{< /terminal-command >}}

{{< terminal-output >}}
Generating the etcd ca
Generating the Kubernetes ca
Generating the etcd server certificate for earth
Generating the etcd peer certificate for earth
Generating the etcd client certificate for earth
Generating the Kubernetes apiserver server certificate for earth
Generating the Kubernetes kubelet server certificate for earth
Generating the Kubernetes kubelet client certificate for earth
Generating the Kubernetes controller manager client certificate for earth
Generating the Kubernetes scheduler client certificate for earth
Generating the Kubernetes proxy client certificate for earth
Generating the Kubernetes admin client certificate for earth
........
{{< /terminal-output >}}
{{< /terminal >}}

As an aside, note that we are running on CoreOS-provided images, and the
Kubernetes distribution available there might be slightly behind the official
distribution, this is expecially noticeable in the HyperKube container used to
set-up kubelet, kube-proxy and so on.

For example at the time of writing the current Kubernetes version is 1.8.5,
but the latest available hyperkube is 1.8.4, when choosing the tag to use here
please make sure it does exist by checking https://quay.io/repository/coreos/hyperkube?tag=latest&tab=tags


{{< terminal title="andromeda" >}}
{{< terminal-comment >}}
Generate all the ignition templates as well as needed additional files
this will use kubernetes 1.8.4
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kgenerate -e 3 -k v1.8.4 -c $KCLUSTER
{{< /terminal-command >}}
{{< terminal-output >}}
Created templates for a cluster with:
Master:   solar-earth          (192.168.100.20)
Etcd:     solar-mercury        (192.168.100.21)
Etcd:     solar-venus          (192.168.100.22)
Etcd:     solar-mars           (192.168.100.23)
Node:     solar-jupiter        (192.168.100.24)
Node:     solar-saturn         (192.168.100.25)
{{< /terminal-output >}}

{{< terminal-comment >}}
Install the ignition files in nginx and set up the guests
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kgen refresh $KCLUSTER
{{< /terminal-command >}}
{{< terminal-output >}}
grub.cfg set to:set linux_append="coreos.config.url=http://192.168.100.1/solar/earth.json"
Removed /etc/machine-id for systemd units refresh
Transpiling earth.ct and adding it to nginx
Creating coreos/first_boot
grub.cfg set to:set linux_append="coreos.config.url=http://192.168.100.1/solar/mercury.json"
Removed /etc/machine-id for systemd units refresh
Transpiling mercury.ct and adding it to nginx
Creating coreos/first_boot
grub.cfg set to:set linux_append="coreos.config.url=http://192.168.100.1/solar/venus.json"
Removed /etc/machine-id for systemd units refresh
Transpiling venus.ct and adding it to nginx
Creating coreos/first_boot
grub.cfg set to:set linux_append="coreos.config.url=http://192.168.100.1/solar/mars.json"
Removed /etc/machine-id for systemd units refresh
Transpiling mars.ct and adding it to nginx
Creating coreos/first_boot
grub.cfg set to:set linux_append="coreos.config.url=http://192.168.100.1/solar/jupiter.json"
Removed /etc/machine-id for systemd units refresh
Transpiling jupiter.ct and adding it to nginx
Creating coreos/first_boot
grub.cfg set to:set linux_append="coreos.config.url=http://192.168.100.1/solar/saturn.json"
Removed /etc/machine-id for systemd units refresh
Transpiling saturn.ct and adding it to nginx
Creating coreos/first_boot
{{< /terminal-output >}}
{{< terminal-comment >}}
Everything is ready for the cluster to start
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kup $KCLUSTER
{{< /terminal-command >}}
{{< terminal-output >}}
[1] 6492
[2] 6493
[3] 6496
[4] 6501
[5] 6502
[6] 6520
Parsing config from venus.cfg
Parsing config from mercury.cfg
Parsing config from earth.cfg
Parsing config from mars.cfg
Parsing config from jupiter.cfg
Parsing config from saturn.cfg
{{< /terminal-output >}}
{{< /terminal >}}

The first boot of the cluster will take a while because docker has to download
images after it's up, check with the console, can ssh in and journalctl -f
there will be errors for a while while etcd starts up and everything is
settled

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
ssh core@192.168.100.20
{{< /terminal-command >}}
{{< terminal-command user="core" host="solar-earth" path="~" >}}
journalctl -f
{{< /terminal-command >}}
{{< terminal-output >}}
Dec 09 21:29:54 solar-earth kubelet-wrapper[761]: Downloading ACI:  24.6 MB/245 MB
Dec 09 21:29:55 solar-earth flannel-wrapper[902]: Downloading signature:  0 B/473 B
Dec 09 21:29:55 solar-earth flannel-wrapper[902]: Downloading signature:  473 B/473 B
Dec 09 21:29:55 solar-earth kubelet-wrapper[761]: Downloading ACI:  26 MB/245 MB
Dec 09 21:29:56 solar-earth flannel-wrapper[902]: Downloading ACI:  0 B/18 MB
Dec 09 21:29:56 solar-earth flannel-wrapper[902]: Downloading ACI:  8.19 KB/18 MB
Dec 09 21:29:56 solar-earth kubelet-wrapper[761]: Downloading ACI:  27.4 MB/245 MB
Dec 09 21:29:57 solar-earth flannel-wrapper[902]: Downloading ACI:  1.38 MB/18 MB
Dec 09 21:29:57 solar-earth kubelet-wrapper[761]: Downloading ACI:  28.5 MB/245 MB
...
{{< /terminal-output >}}
{{< /terminal >}}

after the download is done can also docker ps to verify containers are
starting

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
docker ps
{{< /terminal-command >}}
{{< terminal-output >}}
CONTAINER ID        IMAGE                                                                                                        COMMAND                  CREATED             STATUS              PORTS               NAMES
58f9ec71708c        gcr.io/google_containers/hyperkube@sha256:a68d3ebeb5d8a8b4b9697a5370ea1b7ad921c403cd7429c7ac859193901c9ded   "/bin/bash -c '/contr"   15 seconds ago      Up 14 seconds                           k8s_kube-controller-manager_kube-controller-manager-solar-earth_kube-system_c483efd67fc3ec53dba56e58eedf3d5c_0
345ce236abd1        gcr.io/google_containers/hyperkube@sha256:a68d3ebeb5d8a8b4b9697a5370ea1b7ad921c403cd7429c7ac859193901c9ded   "/bin/bash -c '/proxy"   18 seconds ago      Up 17 seconds                           k8s_kube-proxy_kube-proxy-solar-earth_kube-system_279180e8dd21f1066568940ef66762e4_0
608df8c0fb68        gcr.io/google_containers/hyperkube@sha256:a68d3ebeb5d8a8b4b9697a5370ea1b7ad921c403cd7429c7ac859193901c9ded   "/bin/bash -c '/sched"   19 seconds ago      Up 19 seconds                           k8s_kube-scheduler_kube-scheduler-solar-earth_kube-system_295842a1063467946b49b059a8b55c8b_0
0db9eaa574c8        gcr.io/google_containers/hyperkube@sha256:a68d3ebeb5d8a8b4b9697a5370ea1b7ad921c403cd7429c7ac859193901c9ded   "/bin/bash -c '/apise"   22 seconds ago      Up 22 seconds                           k8s_kube-apiserver_kube-apiserver-solar-earth_kube-system_09b4691a8d49eb9038ca56ce4543554a_0
a48be2806005        gcr.io/google_containers/pause-amd64:3.0                                                                     "/pause"                 51 seconds ago      Up 47 seconds                           k8s_POD_kube-proxy-solar-earth_kube-system_279180e8dd21f1066568940ef66762e4_0
57edc7794024        gcr.io/google_containers/pause-amd64:3.0                                                                     "/pause"                 51 seconds ago      Up 46 seconds                           k8s_POD_kube-controller-manager-solar-earth_kube-system_c483efd67fc3ec53dba56e58eedf3d5c_0
b7585fc1c322        gcr.io/google_containers/pause-amd64:3.0                                                                     "/pause"                 51 seconds ago      Up 47 seconds                           k8s_POD_kube-scheduler-solar-earth_kube-system_295842a1063467946b49b059a8b55c8b_0
cd1ea45ef2ed        gcr.io/google_containers/pause-amd64:3.0                                                                     "/pause"                 51 seconds ago      Up 48 seconds                           k8s_POD_kube-apiserver-solar-earth_kube-system_09b4691a8d49eb9038ca56ce4543554a_0
{{< /terminal-output >}}
{{< /terminal >}}

You can also tail the kubernetes logs in **/var/log/kubernetes/*log** after
the containers are up to make sure especially the apiserver is settled, this
might take a few minutes depending on the speed of your computer and disks.

# Accessing the cluster

The cluster is now available, so we can execute commands against it, if you
don't have kubectl available it's time to get it

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.8.4/bin/linux/amd64/kubectl
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
chmod a+x kubectl
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
mv kubectl $XENDIR/bin
{{< /terminal-command >}}
{{< /terminal >}}

we can now set the configuration for our cluster, with certificates and so on,
via the **kubeconfig** bash function

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kubeconfig $KCLUSTER
{{< /terminal-command >}}
{{< terminal-output >}}
Cluster "solar" set.
User "admin" set.
Context "solar" created.
Switched to context "solar".
{{< /terminal-output >}}
{{< terminal-comment >}}
Now verify it works
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kubectl version
{{< /terminal-command >}}
{{< terminal-output >}}
Client Version: version.Info{Major:"1", Minor:"8", GitVersion:"v1.8.4", GitCommit:"9befc2b8928a9426501d3bf62f72849d5cbcd5a3", GitTreeState:"clean", BuildDate:"2017-11-20T05:28:34Z", GoVersion:"go1.8.3", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"8", GitVersion:"v1.8.4", GitCommit:"9befc2b8928a9426501d3bf62f72849d5cbcd5a3", GitTreeState:"clean", BuildDate:"2017-11-20T05:17:43Z", GoVersion:"go1.8.3", Compiler:"gc", Platform:"linux/amd64"}
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kubectl get svc
{{< /terminal-command >}}
{{< terminal-output >}}
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.199.0.1   <none>        443/TCP   2m
{{< /terminal-output >}}
{{< /terminal >}}

# Creating some deployments

Let's now start kube-dns, to have dns available in our cluster, as well as
busybox and hostnames as [discussed in the Kubernetes debugging page
here](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-service/)
to verify everything works

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kubectl apply -f ./yaml/dns.yaml
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kubectl apply -f ./yaml/hostnames.yaml
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kubectl apply -f ./yaml/busybox.yaml
{{< /terminal-command >}}
{{< terminal-comment >}}
wait for the pods to be up then
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kubectl exec -i --tty busybox -- /bin/sh
{{< /terminal-command >}}
{{< terminal-command user="root" host="busybox" path="/" >}}
nslookup hostnames
{{< /terminal-command >}}
{{< terminal-output >}}
Server:    10.199.0.10
Address 1: 10.199.0.10 kube-dns.kube-system.svc.cluster.local

Name:      hostnames
Address 1: 10.199.4.203 hostnames.default.svc.cluster.local
{{< /terminal-output >}}
{{< /terminal >}}

For a more complicated deployment let's now install the [Kubernetes
dashboard](https://github.com/kubernetes/dashboard), in order to use it we
should give it some certificates to be able to access it over SSL, so we have
to create them as well as store them in Kubernetes as a secret.

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
knodeportcert dashboard
{{< /terminal-command >}}
{{< terminal-output >}}
Generating a nodeport certificate for 'dashboard' with IPs set to 10.199.0.1,192.168.1.45,192.168.100.1
{{< /terminal-output >}}
{{< terminal-comment >}}
Note the IPs chosen, if they don't look right you might need to update the
function, in that case let me know. Certs will be in ./dashboard-certs, we
need to rename them
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
mv dashboard-certs/solar-nodeport-dashboard.pem dashboard-certs/dashboard.crt
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
mv dashboard-certs/solar-nodeport-dashboard-key.pem dashboard-certs/dashboard.key
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kubectl create secret generic kubernetes-dashboard-certs --from-file=./dashboard-certs -n kube-system
{{< /terminal-command >}}
{{< terminal-output >}}
secret "kubernetes-dashboard-certs" created
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
rm -rf dashboard-certs
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
{{< /terminal-command >}}
{{< /terminal >}}

The provided yaml file is the [same as this
file](https://raw.githubusercontent.com/kubernetes/dashboard/v1.8.0/src/deploy/recommended/kubernetes-dashboard.yaml)
with the small change of making the deployment a nodeport on our 32000 port.

We can now start the deployment and take a couple of extra steps to verify it
works accessing it from our main development workstation (where we likely have
our browser)

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kubectl apply -f ./yaml/kubernetes-dashboard.yaml
{{< /terminal-command >}}
{{< terminal-comment >}}
We need to get the token from our configuration to be able to log into the dashboard
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kubectl config view --flatten --minify | awk -F ' ' '/token:/ { print $2 }'
{{< /terminal-command >}}
{{< terminal-output >}}
6b2a827e83d9466e909a3b2a5818bdea
{{< /terminal-output >}}

{{< terminal-comment >}}
the kubectl config view --flatten --minify output can be saved so we can
transfer it
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/solar" >}}
kubectl config view --flatten --minify > solar
{{< /terminal-command >}}
{{< /terminal >}}

On our main host, we can now copy this file and use it after making sure we
change the IP address of the cluster to the LAN IP of our Xen box,
(192.168.1.45 here but of course different in your case) and the port to the
port on the Xen box that will be forwarded to the master 8443 port for API
access.

{{< terminal title="andromeda" >}}
{{< terminal-command user="user" host="somewhere" path="~" >}}
scp root@192.168.1.45:/storage/xen/guests/solar/solar ~/.kube/
{{< /terminal-command >}}
{{< terminal-command user="user" host="somewhere" path="~" >}}
export KUBECONFIG=~/.kube/solar
{{< /terminal-command >}}
{{< terminal-command user="user" host="somewhere" path="~" >}}
kubectl config set-cluster solar --server=https://192.168.1.45:8102/
{{< /terminal-command >}}
{{< terminal-output >}}
Cluster "solar" set.
{{< /terminal-output >}}
{{< terminal-command user="user" host="somewhere" path="~" >}}
kubectl -n kube-system get svc
{{< /terminal-command >}}
{{< terminal-output >}}
NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)         AGE
kube-dns               ClusterIP   10.199.0.10    <none>        53/UDP,53/TCP   6m
kubernetes-dashboard   NodePort    10.199.12.23   <none>        443:32000/TCP   3m
{{< /terminal-output >}}
{{< /terminal >}}

You should now be able to go on your browser and go to
https://[your-lan-ip]:32000/ and log in with the master token identified above
to access the dashboard.

Have fun with your new Kubernetes cluster! If you have reached this page as
part of the guide, you might need to [go back to step 5]({{< ref
"xen-5.md#flanneld" >}}) to understand how the cluster is put together.

To shut down the cluster you can just run **kdown $KCLUSTER**.




