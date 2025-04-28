+++
type = "post"
title = "Kubernetes and Xen, part 4: A CoreOS etcd cluster"
description = ""
tags = [
    "xen",
    "kubernetes"
]
date = "2017-12-14T09:29:48-08:00"
categories = [
    "Applications",
]
shorttitle = "Kubernetes and Xen - part 4"
changelog = [
    "Initial release - 2017-12-14",
]
+++

In the [previous part of the guide]({{< ref "xen-3.md" >}}) we have shown how
to create a CoreOS Xen guest, let's now leverage that and create a cluster of
3 CoreOS guests running running [etcd](https://coreos.com/etcd/).

First of all we should create Xen configuration files for the other two nodes,
this is simply a matter of changing a few values

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cat node-1.cfg | sed -e 's/node-1/node-2/g' -e s/31:11,/31:12,/ > node-2.cfg
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cat node-1.cfg | sed -e 's/node-1/node-3/g' -e s/31:11,/31:13,/ > node-3.cfg
{{< /terminal-command >}}
{{< /terminal >}}

afterwards it's time for us to take a look at the ignition configuration for
the nodes, but before doing that let's first take care of the connection
between the etcd daemons.

# TLS certificates

We want our etcd daemons to communicate over an authenticated TLS channel with
each other, this means each node needs to have two sets of certificates for
etcd (one for the server, one to be used as a peer certificate to talk to the
other) and a client certificate to make it easy to test interacting with etcd
via etcdctl.

It is not necessary to have a separate client certificate for each server,
however I find it good practice not to share certificates whenever
possible. Self signed certificate generation is discussed [on this page in the
CoreOS
website](https://coreos.com/os/docs/latest/generate-self-signed-certificates.html).

<div id="cfssl"></div>

Let's first download and install [CFSSL](https://github.com/cloudflare/cfssl),
although there are some pre-built binaries available already, it is quite easy
to set up golang and compile from source. With golang I prefer to install the
standard distribution rather than use the Debian packages as it is more
up-to-date.

First of all check at the [golang download page](https://golang.org/dl/) which
is the current stable version, 1.9.2 at the time of this writing, and download
it (or copy the link and use it as below). I usually install golang in
/usr/local/go-x.y.z and symlink /usr/local/go to it
 
{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cd /usr/local
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/usr/local" >}}
curl -L https://redirector.gvt1.com/edgedl/go/go1.9.2.linux-amd64.tar.gz -s -o - | tar xvfz -
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/usr/local" >}}
mv go go-1.9.2 ; ln -s go-1.9.2 go
{{< /terminal-command >}}
{{< terminal-comment >}}
Don't forget to add /usr/local/go/bin to your PATH if it's not already there,
and to setup your GOPATH and add GOPATH's bin directory to your path also.
{{< /terminal-comment >}}

{{< terminal-command user="root" host="andromeda" path="/usr/local" >}}
mkdir $HOME/go
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/usr/local" >}}
export GOPATH=$HOME/go
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/usr/local" >}}
export PATH=$HOME/go/bin:/usr/local/go/bin:$PATH
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/usr/local" >}}
go version
{{< /terminal-command >}}
{{< terminal-output >}}
go version go1.9.2 linux/amd64
{{< /terminal-output >}}

{{< terminal-command user="root" host="andromeda" path="/usr/local" >}}
go get -u github.com/cloudflare/cfssl/cmd/...
{{< /terminal-command >}}

{{< terminal-comment >}}
If your PATH and GOPATH are set up correctly the next command should work
{{< /terminal-comment >}}

{{< terminal-command user="root" host="andromeda" path="/usr/local" >}}
cfssl version
{{< /terminal-command >}}
{{< terminal-output >}}
Version: 1.2.0
Revision: dev
Runtime: go1.9.2
{{< /terminal-output >}}
{{< /terminal >}}

as discussed in the CoreOS certificates page, we will need two spec files for
our certificate generation, we should also create a directory to store all our
certificates

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/usr/local" >}}
xencd etcd
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
mkdir certs
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cd certs
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd/certs" >}}
vi ca-config.json ; cat ca-config.json
{{< /terminal-command >}}
{{< terminal-output >}}
{
    "signing": {
        "default": {
            "expiry": "43800h"
        },
        "profiles": {
            "server": {
                "expiry": "43800h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "43800h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            },
            "peer": {
                "expiry": "43800h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
        }
    }
}
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd/certs" >}}
vi ca-csr.json ; cat ca-csr.json
{{< /terminal-command >}}
{{< terminal-output >}}
{
    "CN": "ETCD CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "O": "Fun clusters",
            "OU": "The etcd cluster"
        }
    ]
}
{{< /terminal-output >}}
{{< terminal-comment >}}
Obviously feel free to change the values above
{{< /terminal-comment >}}
{{< /terminal >}}

with this set-up we are now ready to create the certificates we need, let's
first do it command by command and then create a bash function to make it
easier to do for multiple nodes.

{{< terminal title="andromeda" >}}
{{< terminal-comment >}}
First create the CA
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd/certs" >}}
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
{{< /terminal-command >}}
{{< terminal-output >}}
2017/12/04 13:07:27 [INFO] generating a new CA key and certificate from CSR
2017/12/04 13:07:27 [INFO] generate received request
2017/12/04 13:07:27 [INFO] received CSR
2017/12/04 13:07:27 [INFO] generating key: rsa-2048
2017/12/04 13:07:27 [INFO] encoded CSR
2017/12/04 13:07:27 [INFO] signed certificate with serial number 371395664172797524463428193829566444461989582320
{{< /terminal-output >}}
{{< terminal-comment >}}
Start with the 'server' profile for our server cert
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd/certs" >}}
echo '{"CN":"etcd-node-1-server","hosts":[""],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server -hostname="192.168.100.11,etcd-node-1" - | cfssljson -bare etcd-node-1-server
{{< /terminal-command >}}
{{< terminal-output >}}
2017/12/04 13:10:43 [INFO] generate received request
2017/12/04 13:10:43 [INFO] received CSR
2017/12/04 13:10:43 [INFO] generating key: rsa-2048
2017/12/04 13:10:44 [INFO] encoded CSR
2017/12/04 13:10:44 [INFO] signed certificate with serial number 711114156779509809672244743349661684421006137401
{{< /terminal-output >}}
{{< terminal-comment >}}
Note that we are now going to use the 'peer' profile
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd/certs" >}}
echo '{"CN":"etcd-node-1-peer","hosts":[""],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=peer -hostname="192.168.100.11,etcd-node-1" - | cfssljson -bare etcd-node-1-peer
{{< /terminal-command >}}
{{< terminal-output >}}
2017/12/04 13:11:04 [INFO] generate received request
2017/12/04 13:11:04 [INFO] received CSR
2017/12/04 13:11:04 [INFO] generating key: rsa-2048
2017/12/04 13:11:04 [INFO] encoded CSR
2017/12/04 13:11:04 [INFO] signed certificate with serial number 28611347093971073034596156201548317440092463213
{{< /terminal-output >}}
{{< terminal-comment >}}
And finally the client profile for the client certificate
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd/certs" >}}
echo '{"CN":"etcd-node-1-client","hosts":[""],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=client - | cfssljson -bare etcd-node-1-client
{{< /terminal-command >}}
{{< terminal-output >}}
2017/12/04 13:11:14 [INFO] generate received request
2017/12/04 13:11:14 [INFO] received CSR
2017/12/04 13:11:14 [INFO] generating key: rsa-2048
2017/12/04 13:11:15 [INFO] encoded CSR
2017/12/04 13:11:15 [INFO] signed certificate with serial number 428167357505177330066797952811634513293217918758
{{< /terminal-output >}}

{{< terminal-comment >}}
these are not needed
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd/certs" >}}
rm *.csr
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd/certs" >}}
ls -la
{{< /terminal-command >}}
{{< terminal-output >}}
total 64
drwxr-xr-x 2 root root 4096 Dec  4 13:11 .
drwxr-xr-x 3 root root 4096 Dec  4 12:59 ..
-rw-r--r-- 1 root root  832 Dec  4 12:59 ca-config.json
-rw-r--r-- 1 root root  223 Dec  4 13:03 ca-csr.json
-rw------- 1 root root 1679 Dec  4 13:07 ca-key.pem
-rw-r--r-- 1 root root 1257 Dec  4 13:07 ca.pem
-rw-r--r-- 1 root root  944 Dec  4 13:11 etcd-node-1-client.csr
-rw------- 1 root root 1675 Dec  4 13:11 etcd-node-1-client-key.pem
-rw-r--r-- 1 root root 1273 Dec  4 13:11 etcd-node-1-client.pem
-rw------- 1 root root 1675 Dec  4 13:11 etcd-node-1-peer-key.pem
-rw-r--r-- 1 root root 1310 Dec  4 13:11 etcd-node-1-peer.pem
-rw------- 1 root root 1675 Dec  4 13:10 etcd-node-1-server-key.pem
-rw-r--r-- 1 root root 1298 Dec  4 13:10 etcd-node-1-server.pem
{{< /terminal-output >}}

{{< terminal-comment >}}
Note that the SAN / Subject Alternative Names property in the certificate has
been set to the node hostname and IP address, this is very important and if
not correct will cause problems later on with etcd refusing to operate due to
certificate validation errors.
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd/certs" >}}
openssl x509 -in etcd-node-1-server.pem -text -noout
{{< /terminal-command >}}
{{< terminal-output >}}
Certificate:
...
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: O = Fun clusters, OU = The etcd cluster, CN = ETCD CA
        Validity
            Not Before: Dec  4 21:06:00 2017 GMT
            Not After : Dec  3 21:06:00 2022 GMT
        Subject: CN = etcd-node-1-server
...
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
...
            X509v3 Subject Alternative Name: 
                DNS:etcd-node-1, IP Address:192.168.100.11
{{< /terminal-output >}}
{{< /terminal >}}

<div id="kgen"></div>

as you have noticed, the commands to create the certificates are very similar,
and so easy to automate, [you can see it here]({{< ref "kgen.md#kgencert" >}}) also
with completion. Note that if you don't provide the IP, the function will be
able to figure it out from the dnsmasq hosts file we created earlier.

Let's now remove the certificates we created and regenerate them using the
script.

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd/certs" >}}
cd ..
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
rm -rf certs
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
kgencert node-1
{{< /terminal-command >}}
{{< terminal-output >}}
2017/12/12 17:03:07 [INFO] generating a new CA key and certificate from CSR
2017/12/12 17:03:07 [INFO] generate received request
2017/12/12 17:03:07 [INFO] received CSR
2017/12/12 17:03:07 [INFO] generating key: rsa-2048
2017/12/12 17:03:07 [INFO] encoded CSR
2017/12/12 17:03:07 [INFO] signed certificate with serial number 583203797657129789344945978835970118719717980298
...
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
kgencert node-2
{{< /terminal-command >}}
{{< terminal-output >}}
...
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
kgencert node-3
{{< /terminal-command >}}
{{< terminal-output >}}
...
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
ls -la certs/
{{< /terminal-command >}}
{{< terminal-output >}}
total 96
drwxr-xr-x 2 root root 4096 Dec 12 17:04 .
drwxr-xr-x 3 root root 4096 Dec 12 17:03 ..
-rw-r--r-- 1 root root  832 Dec 12 17:03 ca-config.json
-rw-r--r-- 1 root root  212 Dec 12 17:03 ca-csr.json
-rw------- 1 root root 1679 Dec 12 17:03 etcd-ca-key.pem
-rw-r--r-- 1 root root 1253 Dec 12 17:03 etcd-ca.pem
-rw------- 1 root root 1679 Dec 12 17:03 etcd-node-1-client-key.pem
-rw-r--r-- 1 root root 1273 Dec 12 17:03 etcd-node-1-client.pem
-rw------- 1 root root 1679 Dec 12 17:03 etcd-node-1-peer-key.pem
-rw-r--r-- 1 root root 1306 Dec 12 17:03 etcd-node-1-peer.pem
-rw------- 1 root root 1675 Dec 12 17:03 etcd-node-1-server-key.pem
-rw-r--r-- 1 root root 1298 Dec 12 17:03 etcd-node-1-server.pem
-rw------- 1 root root 1675 Dec 12 17:04 etcd-node-2-client-key.pem
-rw-r--r-- 1 root root 1273 Dec 12 17:04 etcd-node-2-client.pem
-rw------- 1 root root 1679 Dec 12 17:04 etcd-node-2-peer-key.pem
-rw-r--r-- 1 root root 1306 Dec 12 17:04 etcd-node-2-peer.pem
-rw------- 1 root root 1675 Dec 12 17:04 etcd-node-2-server-key.pem
-rw-r--r-- 1 root root 1298 Dec 12 17:04 etcd-node-2-server.pem
-rw------- 1 root root 1679 Dec 12 17:04 etcd-node-3-client-key.pem
-rw-r--r-- 1 root root 1273 Dec 12 17:04 etcd-node-3-client.pem
-rw------- 1 root root 1679 Dec 12 17:04 etcd-node-3-peer-key.pem
-rw-r--r-- 1 root root 1306 Dec 12 17:04 etcd-node-3-peer.pem
-rw------- 1 root root 1679 Dec 12 17:04 etcd-node-3-server-key.pem
-rw-r--r-- 1 root root 1298 Dec 12 17:04 etcd-node-3-server.pem
{{< /terminal-output >}}
{{< /terminal >}}

# Configuration file generation

With all the certificates now ready we are ready to create Ignition
configuration files containing them. In general you would not want
certificates and keys to be present in deployment files for security reasons,
however given our setup it makes it easiest to include them in the .ct files
directly.

Unfortunately you can't really cut and paste the files directly otherwise they
won't transpile correctly, they have to be indented the correct amount,
therefore we will create [a small python script]({{< ref "kgen.md#kgenct" >}})
to help us do so automatically. Download it and put it in your PATH, say
$XENDIR/bin, so rather than writing directly a **.ct** file, we will be able
to write a **.ct.tmpl** and use the *kgenct* script to preprocess it.

For example a .ct.tmpl equivalent to the .ct file we were using before would
be the following:

{{< highlight bnf "hl_lines=30" >}}
storage:
  files:
    - filesystem: "root"
      path:       "/etc/hostname"
      mode:       0644
      contents:
        inline: etcd-node-1

    - path: /etc/ntp.conf
      filesystem: root
      mode: 0644
      contents:
        inline: |
          server 192.168.100.1
          restrict default nomodify nopeer noquery limited kod
          restrict 127.0.0.1
          restrict [::1]

systemd:
  units:
    - name: systemd-timesyncd.service
      mask: true
    - name: ntpd.service
      enable: true

passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - ssh-rsa -###/root/.ssh/id_rsa.pub
{{< / highlight >}}

highlighted is the only changed line, anything starting with **-###** will be
inserted in that position in the file (after being joined together, if it was
multiple lines originally), while as we'll see later anything starting with
**|###** will instead be inserted leaving the multiple lines separate, but
indenting it correctly.

For example if we had this sample testnode.ct.tmpl file

{{< highlight bnf "hl_lines=7 13" >}}
storage:
  files:
    - filesystem: "root"
      path:       "/etc/ssl/certs/server.pem"
      contents:
        inline: |
          |###certs/etcd-node-1-server.pem

passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - -###/root/.ssh/id_rsa.pub
{{< / highlight >}}

and executed the script we would see the following

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
ls -la /storage/xen/bin/kgenct
{{< /terminal-command >}}
{{< terminal-output >}}
-rwxr-xr-x 1 root root 1183 Dec 12 17:06 /storage/xen/bin/kgenct
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
kgenct -t testnode.ct.tmpl 
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cat testnode.ct
{{< /terminal-command >}}
{{< terminal-output >}}
storage:
  files:
    - filesystem: "root"
      path:       "/etc/ssl/certs/server.pem"
      contents:
        inline: |
          -----BEGIN CERTIFICATE-----
          MIIDnDCCAoSgAwIBAgIUdMuMi7eKOEBYsKXKoLGUoN6oCgswDQYJKoZIhvcNAQEL
.......
          FLDgVOAyGJw2rJ31mTbmAA==
          -----END CERTIFICATE-----
          

passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - ssh-rsa AAAAB3N........
{{< /terminal-output >}}
{{< /terminal >}}

Note the kgen **refresh** target will automatically run kgenct if you have a
.ct.tmpl file for the current node and it is newer than the .ct file (or if
the .ct file does not exist).

# Etcd configuration

We are now ready to actually configure etcd, this is the block we need to add
to our configuration file

{{< highlight bnf >}}
etcd:
  name:                        etcd-node-1
  listen_client_urls:          https://192.168.100.11:2379
  advertise_client_urls:       https://192.168.100.11:2379
  listen_peer_urls:            https://192.168.100.11:2380
  initial_advertise_peer_urls: https://192.168.100.11:2380
  initial_cluster:             etcd-node-1=https://192.168.100.11:2380,etcd-node-2=https://192.168.100.12:2380,etcd-node-3=https://192.168.100.13:2380
  initial_cluster_token:       etcd-token
  initial_cluster_state:       new
{{< / highlight >}}

as you can see we are declaring we are running etcd on our node, etcd-node-1,
and set up the various endpoints we will listen to and advertise to our
peers. We are also saying the initial cluster is our 3-node cluster, and the
endpoint addresses to use.

The actual certificates that etcd will use are going to be defined in a
systemd drop-in via some environmental variables that etcd itself will
reference when starting up

{{< highlight bnf >}}
systemd:
  units:
    - name: etcd-member.service
      enabled: true
      dropins:
        - name: 30-certs.conf
          contents: |
            [Service]
            Environment="ETCD_CERT_FILE=/etc/ssl/certs/etcd/server.pem"
            Environment="ETCD_KEY_FILE=/etc/ssl/certs/etcd/server-key.pem"
            Environment="ETCD_TRUSTED_CA_FILE=/etc/ssl/certs/etcd/ca.pem"
            Environment="ETCD_CLIENT_CERT_AUTH=true"
            Environment="ETCD_PEER_CERT_FILE=/etc/ssl/certs/etcd/peer.pem"
            Environment="ETCD_PEER_KEY_FILE=/etc/ssl/certs/etcd/peer-key.pem"
            Environment="ETCD_PEER_TRUSTED_CA_FILE=/etc/ssl/certs/etcd/ca.pem"
            Environment="ETCD_PEER_CLIENT_CERT_AUTH=true"
{{< /highlight >}}

this will be tied to the etcd service (which is called
etcd-member.service) as a systemd drop-in [as discussed here](https://coreos.com/os/docs/latest/using-systemd-drop-in-units.html)

Note we could also have added the etcd certificates to the configuration
itself [as this page
mentions](https://coreos.com/etcd/docs/latest/platforms/container-linux-systemd.html),
however I thought it would be good to show systemd drop-ins in use as they can
be quite useful in modifying your system by customizing systemd services. This
does depend on your particular transpiler version, as it might not recognize
some of these options.

These environmental variables will tell etcd where the certificates that
should be used for its operation are located. These certificate files will
need to be put in the image, and this can be done simply via ignition
directives just like when we created our own /etc/hostname.

Note that certificates **have** to be stored in */etc/ssl/certs* because other
directories are not made available to etcd via etcdwrapper, you can see this
by [looking at the source available at the time of
writing](https://github.com/coreos/coreos-overlay/blob/18b4fe2fecd3362c8947cd1023d9497a1c783283/app-admin/etcd-wrapper/files/etcd-wrapper#L76),
so if you had put the certificates in your own directory you would be
surprised when etcd started up saying it couldn't find them at that path.

Given all this here is the .ct.tmpl file we will be using for our nodes, the
highlighted lines are the node-specific lines, all other lines are the same
for node-1.ct.tmpl, node-2.ct.tmpl and node-3.ct.tmpl, so when copying the .ct
file to create the other node copies make sure you change node-1 to node-2 / 3
and 192.168.100.1 to .2 / .3 in the lines highlighted here.

{{< highlight bnf "hl_lines=15 37 48 59 70 81 92 111-115" >}}
storage:
  directories:
    - filesystem: "root"
      path:       "/etc/ssl/certs/etcd"
      mode:       0750
      user:
        name:     "etcd"
      group:
        name:     "root"
  files:
    - filesystem: "root"
      path:       "/etc/hostname"
      mode:       0644
      contents:
        inline: etcd-node-1

    - filesystem: "root"
      path:       "/etc/ssl/certs/etcd/ca.pem"
      mode:       0640
      user:
        name:     "etcd"
      group:
        name:     "root"
      contents:
        inline: |
          |###certs/etcd-ca.pem

    - filesystem: "root"
      path:       "/etc/ssl/certs/etcd/server.pem"
      mode:       0640
      user:
        name:     "etcd"
      group:
        name:     "root"
      contents:
        inline: |
          |###certs/etcd-node-1-server.pem

    - filesystem: "root"
      path:       "/etc/ssl/certs/etcd/server-key.pem"
      mode:       0600
      user:
        name:     "etcd"
      group:
        name:     "root"
      contents:
        inline: |
          |###certs/etcd-node-1-server-key.pem

    - filesystem: "root"
      path:       "/etc/ssl/certs/etcd/peer.pem"
      mode:       0640
      user:
        name:     "etcd"
      group:
        name:     "root"
      contents:
        inline: |
          |###certs/etcd-node-1-peer.pem

    - filesystem: "root"
      path:       "/etc/ssl/certs/etcd/peer-key.pem"
      mode:       0600
      user:
        name:     "etcd"
      group:
        name:     "root"
      contents:
        inline: |
          |###certs/etcd-node-1-peer-key.pem

    - filesystem: "root"
      path:       "/etc/ssl/certs/etcd/client.pem"
      mode:       0640
      user:
        name:     "etcd"
      group:
        name:     "root"
      contents:
        inline: |
          |###certs/etcd-node-1-client.pem

    - filesystem: "root"
      path:       "/etc/ssl/certs/etcd/client-key.pem"
      mode:       0600
      user:
        name:     "etcd"
      group:
        name:     "root"
      contents:
        inline: |
          |###certs/etcd-node-1-client-key.pem

    - path: /etc/ntp.conf
      filesystem: root
      mode: 0644
      contents:
        inline: |
          server 192.168.100.1
          restrict default nomodify nopeer noquery limited kod
          restrict 127.0.0.1
          restrict [::1]

passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - -###/root/.ssh/id_rsa.pub

etcd:
  name:                        etcd-node-1
  listen_client_urls:          https://192.168.100.11:2379
  advertise_client_urls:       https://192.168.100.11:2379
  listen_peer_urls:            https://192.168.100.11:2380
  initial_advertise_peer_urls: https://192.168.100.11:2380
  initial_cluster:             etcd-node-1=https://192.168.100.11:2380,etcd-node-2=https://192.168.100.12:2380,etcd-node-3=https://192.168.100.13:2380
  initial_cluster_token:       etcd-token
  initial_cluster_state:       new

systemd:
  units:
    - name: systemd-timesyncd.service
      mask: true
    - name: ntpd.service
      enable: true
    - name: etcd-member.service
      enabled: true
      dropins:
        - name: 30-certs.conf
          contents: |
            [Service]
            Environment="ETCD_CERT_FILE=/etc/ssl/certs/etcd/server.pem"
            Environment="ETCD_KEY_FILE=/etc/ssl/certs/etcd/server-key.pem"
            Environment="ETCD_TRUSTED_CA_FILE=/etc/ssl/certs/etcd/ca.pem"
            Environment="ETCD_CLIENT_CERT_AUTH=true"
            Environment="ETCD_PEER_CERT_FILE=/etc/ssl/certs/etcd/peer.pem"
            Environment="ETCD_PEER_KEY_FILE=/etc/ssl/certs/etcd/peer-key.pem"
            Environment="ETCD_PEER_TRUSTED_CA_FILE=/etc/ssl/certs/etcd/ca.pem"
            Environment="ETCD_PEER_CLIENT_CERT_AUTH=true"
{{< / highlight >}}

Note if you would like to use a specific version of etcd you can add to the
drop-in above a line like **Environment="ETCD_IMAGE_TAG=v3.2.11"** for
example, you can see the [available tags here](https://github.com/coreos/etcd/releases/)

after having created the three **.ct.tmpl** files with the respective node
values, we can simply *refresh* the nodes and start them up. We will also
recreate all the certificates just to show a completely-from-scratch start.


{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
rm -rf certs
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
kgencert node-1 ; kgencert node-2 ; kgencert node-3
{{< /terminal-command >}}
{{< terminal-comment >}}
since certs have been regenerated, need to touch the .tmpl files to cause the .ct files to be overwritten
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
touch *tmpl
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
kgen refresh node-1 ; kgen refresh node-2 ; kgen refresh node-3
{{< /terminal-command >}}
{{< terminal-output >}}
grub.cfg set to:set linux_append="coreos.config.url=http://192.168.100.1/etcd/node-1.json"
Removed /etc/machine-id for systemd units refresh
Creating the transpile file from the template node-1.ct.tmpl
Transpiling node-1.ct and adding it to nginx
Creating coreos/first_boot
grub.cfg set to:set linux_append="coreos.config.url=http://192.168.100.1/etcd/node-2.json"
Removed /etc/machine-id for systemd units refresh
Creating the transpile file from the template node-2.ct.tmpl
Transpiling node-2.ct and adding it to nginx
Creating coreos/first_boot
grub.cfg set to:set linux_append="coreos.config.url=http://192.168.100.1/etcd/node-3.json"
Removed /etc/machine-id for systemd units refresh
Creating the transpile file from the template node-3.ct.tmpl
Transpiling node-3.ct and adding it to nginx
Creating coreos/first_boot
{{< /terminal-output >}}
{{< terminal-comment >}}
Time to create our nodes now!
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
xl create node-1.cfg & xl create node-2.cfg & xl create node-3.cfg &
{{< /terminal-command >}}
{{< terminal-output >}}
[1] 18724
[2] 18725
[3] 18726
Parsing config from node-1.cfg
Parsing config from node-3.cfg
Parsing config from node-2.cfg
{{< /terminal-output >}}

{{< terminal-comment >}}
After a while we can ssh to verify our cluster is up and running
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
ssh core@192.168.100.11
{{< /terminal-command >}}
{{< terminal-command user="core" host="etcd-node-1" path="~" >}}
sudo -i
{{< /terminal-command >}}
{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
systemctl status etcd-member.service
{{< /terminal-command >}}
{{< terminal-comment >}}
Note this might take a little bit as it has to download images
{{< /terminal-comment >}}
{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
systemctl status etcd-member.service
{{< /terminal-command >}}
{{< terminal-output >}}
● etcd-member.service - etcd (System Application Container)
   Loaded: loaded (/usr/lib/systemd/system/etcd-member.service; enabled; vendor preset: enabled)
  Drop-In: /etc/systemd/system/etcd-member.service.d
           └─20-clct-etcd-member.conf, 30-certs.conf
   Active: activating (start) since Wed 2017-12-13 01:48:21 UTC; 1min 10s ago
     Docs: https://github.com/coreos/etcd
  Process: 678 ExecStartPre=/usr/bin/rkt rm --uuid-file=/var/lib/coreos/etcd-member-wrapper.uuid (code=exited, status=254)
  Process: 654 ExecStartPre=/usr/bin/mkdir --parents /var/lib/coreos (code=exited, status=0/SUCCESS)
 Main PID: 730 (rkt)
    Tasks: 8 (limit: 32768)
   Memory: 142.7M
      CPU: 2.151s
   CGroup: /system.slice/etcd-member.service
           └─730 /usr/bin/rkt run --uuid-file-save=/var/lib/coreos/etcd-member-wrapper.uuid --trust-keys-from-https --mount volume=coreos-systemd-dir,target=/run/systemd/system --volume coreos-systemd-dir,ki

Dec 13 01:49:11 etcd-node-1 etcd-wrapper[730]: Downloading signature:  0 B/473 B
Dec 13 01:49:11 etcd-node-1 etcd-wrapper[730]: Downloading signature:  473 B/473 B
Dec 13 01:49:11 etcd-node-1 etcd-wrapper[730]: Downloading signature:  473 B/473 B
Dec 13 01:49:11 etcd-node-1 etcd-wrapper[730]: Downloading ACI:  0 B/12.9 MB
Dec 13 01:49:11 etcd-node-1 etcd-wrapper[730]: Downloading ACI:  8.19 KB/12.9 MB
Dec 13 01:49:12 etcd-node-1 etcd-wrapper[730]: Downloading ACI:  1.9 MB/12.9 MB
Dec 13 01:49:13 etcd-node-1 etcd-wrapper[730]: Downloading ACI:  8.63 MB/12.9 MB
Dec 13 01:49:14 etcd-node-1 etcd-wrapper[730]: Downloading ACI:  12.9 MB/12.9 MB
Dec 13 01:49:16 etcd-node-1 etcd-wrapper[730]: image: signature verified:
Dec 13 01:49:16 etcd-node-1 etcd-wrapper[730]:   Quay.io ACI Converter (ACI conversion signing key) <support@quay.io>
{{< /terminal-output >}}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
systemctl status etcd-member.service
{{< /terminal-command >}}
{{< terminal-output >}}
● etcd-member.service - etcd (System Application Container)
   Loaded: loaded (/usr/lib/systemd/system/etcd-member.service; enabled; vendor preset: enabled)
  Drop-In: /etc/systemd/system/etcd-member.service.d
           └─20-clct-etcd-member.conf, 30-certs.conf
   Active: active (running) since Wed 2017-12-13 01:49:39 UTC; 2min 27s ago
     Docs: https://github.com/coreos/etcd
  Process: 678 ExecStartPre=/usr/bin/rkt rm --uuid-file=/var/lib/coreos/etcd-member-wrapper.uuid (code=exited, status=254)
  Process: 654 ExecStartPre=/usr/bin/mkdir --parents /var/lib/coreos (code=exited, status=0/SUCCESS)
 Main PID: 730 (etcd)
    Tasks: 8 (limit: 32768)
   Memory: 131.0M
      CPU: 3.059s
   CGroup: /system.slice/etcd-member.service
           └─730 /usr/local/bin/etcd --name=etcd-node-1 --listen-peer-urls=https://192.168.100.11:2380 --listen-client-urls=https://192.168.100.11:2379 --initial-advertise-peer-urls=https://192.168.100.11:23

Dec 13 01:49:39 etcd-node-1 systemd[1]: Started etcd (System Application Container).
Dec 13 01:49:39 etcd-node-1 etcd-wrapper[730]: 2017-12-13 01:49:39.514001 I | embed: ready to serve client requests
Dec 13 01:49:39 etcd-node-1 etcd-wrapper[730]: 2017-12-13 01:49:39.514544 I | embed: serving client requests on 192.168.100.11:2379
Dec 13 01:49:40 etcd-node-1 etcd-wrapper[730]: 2017-12-13 01:49:40.030318 I | rafthttp: peer 521d9cc310c2aecb became active
Dec 13 01:49:40 etcd-node-1 etcd-wrapper[730]: 2017-12-13 01:49:40.030722 I | rafthttp: established a TCP streaming connection with peer 521d9cc310c2aecb (stream Message reader)
Dec 13 01:49:40 etcd-node-1 etcd-wrapper[730]: 2017-12-13 01:49:40.041760 I | rafthttp: established a TCP streaming connection with peer 521d9cc310c2aecb (stream MsgApp v2 writer)
Dec 13 01:49:40 etcd-node-1 etcd-wrapper[730]: 2017-12-13 01:49:40.048895 I | rafthttp: established a TCP streaming connection with peer 521d9cc310c2aecb (stream MsgApp v2 reader)
Dec 13 01:49:40 etcd-node-1 etcd-wrapper[730]: 2017-12-13 01:49:40.073238 I | rafthttp: established a TCP streaming connection with peer 521d9cc310c2aecb (stream Message writer)
Dec 13 01:49:40 etcd-node-1 etcd-wrapper[730]: 2017-12-13 01:49:40.179703 N | etcdserver/membership: set the initial cluster version to 3.1
Dec 13 01:49:40 etcd-node-1 etcd-wrapper[730]: 2017-12-13 01:49:40.180121 I | etcdserver/api: enabled capabilities for version 3.1
{{< /terminal-output >}}
{{< terminal-comment >}}
if there had been any certificate issues you would have seen messages like
{{< /terminal-comment >}}
{{< terminal-output >}}
Dec 04 23:53:46 etcd-node-1 etcd-wrapper[754]: 2017-12-04 23:53:46.171283 I | raft: 7c35e6112f639de0 received MsgVoteResp from 7c35e6112f639de0 at term 9
Dec 04 23:53:46 etcd-node-1 etcd-wrapper[754]: 2017-12-04 23:53:46.171556 I | raft: 7c35e6112f639de0 [logterm: 1, index: 3] sent MsgVote request to 521d9cc310c2aecb at term 9
Dec 04 23:53:46 etcd-node-1 etcd-wrapper[754]: 2017-12-04 23:53:46.171826 I | raft: 7c35e6112f639de0 [logterm: 1, index: 3] sent MsgVote request to aef3e78ed8950e34 at term 9
Dec 04 23:53:46 etcd-node-1 etcd-wrapper[754]: 2017-12-04 23:53:46.219826 W | rafthttp: health check for peer 521d9cc310c2aecb could not connect: x509: cannot validate certificate for 192.168.100.13 because 
Dec 04 23:53:46 etcd-node-1 etcd-wrapper[754]: 2017-12-04 23:53:46.227869 W | rafthttp: health check for peer aef3e78ed8950e34 could not connect: x509: cannot validate certificate for 192.168.100.12 because 
Dec 04 23:53:47 etcd-node-1 etcd-wrapper[754]: 2017-12-04 23:53:47.970704 I | raft: 7c35e6112f639de0 is starting a new election at term 9
{{< /terminal-output >}}
{{< /terminal >}}

in order to debug any certificate issues, you can use openssl to try to
establish a connection to the other node's etcd directly

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
openssl s_client -cert /etc/ssl/certs/etcd/client.pem -key /etc/ssl/certs/etcd/client-key.pem -CAfile /etc/ssl/certs/etcd/ca.pem -connect 192.168.100.13:2380
{{< /terminal-command >}}
{{< /terminal >}}

if there are any certificate issues openssl should let you know.

# Using etcd

Let's now make sure our etcd cluster is up and running correctly, and that we
can run some commands on it. Note with the configuration above we are not
listening on 127.0.0.1, and we have to use certificates to connect, so it
makes things easier to create a couple of aliases that set the parameters for
us.

{{< terminal title="andromeda" >}}
{{< terminal-comment >}}
As you can see by default it tries 127.0.0.1 and fails
{{< /terminal-comment >}}
{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
etcdctl cluster-health
{{< /terminal-command >}}
{{< terminal-output >}}
cluster may be unhealthy: failed to list members
Error:  client: etcd cluster is unavailable or misconfigured; error #0: dial tcp 127.0.0.1:2379: getsockopt: connection refused
; error #1: dial tcp 127.0.0.1:4001: getsockopt: connection refused

error #0: dial tcp 127.0.0.1:2379: getsockopt: connection refused
error #1: dial tcp 127.0.0.1:4001: getsockopt: connection refused
{{< /terminal-output >}}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
export ETCDADDR=https://$(hostname):2379
{{< /terminal-command >}}
{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
alias et="ETCDCTL_ENDPOINTS=$ETCDADDR etcdctl --ca-file=/etc/ssl/certs/etcd/ca.pem --cert-file=/etc/ssl/certs/etcd/client.pem --key-file=/etc/ssl/certs/etcd/client-key.pem"
{{< /terminal-command >}}
{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
et cluster-health
{{< /terminal-command >}}
{{< terminal-comment >}}
Note it might take a little while for your cluster to get healthy depending on
download speed and so on
{{< /terminal-comment >}}
{{< terminal-output >}}
member 521d9cc310c2aecb is healthy: got healthy result from https://192.168.100.13:2379
member 7c35e6112f639de0 is healthy: got healthy result from https://192.168.100.11:2379
member aef3e78ed8950e34 is healthy: got healthy result from https://192.168.100.12:2379
cluster is healthy
{{< /terminal-output >}}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
alias etcurl="curl -k --cacert /etc/ssl/certs/etcd/ca.pem --key /etc/ssl/certs/etcd/client-key.pem --cert /etc/ssl/certs/etcd/client.pem"
{{< /terminal-command >}}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
etcurl $ETCDADDR/version
{{< /terminal-command >}}

{"etcdserver":"3.1.10","etcdcluster":"3.1.0"}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
et set /message Hello
{{< /terminal-command >}}
{{< terminal-output >}}
Hello
{{< /terminal-output >}}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
et get /message
{{< /terminal-command >}}
{{< terminal-output >}}
Hello
{{< /terminal-output >}}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
etcurl $ETCDADDR/v2/keys/message
{{< /terminal-command >}}
{{< terminal-output >}}
{"action":"get","node":{"key":"/message","value":"Hello","modifiedIndex":12,"createdIndex":12}}
{{< /terminal-output >}}

{{< terminal-comment >}}
Now try to access the same key from a different cluster member
{{< /terminal-comment >}}
{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
export ETCDADDR=https://192.168.100.13:2379
{{< /terminal-command >}}
{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
alias et="ETCDCTL_ENDPOINTS=$ETCDADDR etcdctl --ca-file=/etc/ssl/certs/etcd/ca.pem --cert-file=/etc/ssl/certs/etcd/client.pem --key-file=/etc/ssl/certs/etcd/client-key.pem"
{{< /terminal-command >}}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
etcurl $ETCDADDR/v2/keys/message
{{< /terminal-command >}}
{{< terminal-output >}}
{"action":"get","node":{"key":"/message","value":"Hello","modifiedIndex":12,"createdIndex":12}}
{{< /terminal-output >}}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
et rm /message
{{< /terminal-command >}}
{{< terminal-output >}}
PrevNode.Value: Hello
{{< /terminal-output >}}
{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
et ls /
{{< /terminal-command >}}

{{< terminal-comment >}}
Let's now use version 3 of the API so we can run a performance test, note the
parameter certificate names have changed slightly
{{< /terminal-comment >}}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
alias et="ETCDCTL_API=3 ETCDCTL_ENDPOINTS=$ETCDADDR etcdctl --cacert=/etc/ssl/certs/etcd/ca.pem --cert=/etc/ssl/certs/etcd/client.pem --key=/etc/ssl/certs/etcd/client-key.pem"
{{< /terminal-command >}}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
et check perf
{{< /terminal-command >}}
{{< terminal-comment >}}
Assuming your physical box is fast enough
{{< /terminal-comment >}}
{{< terminal-output >}}
 60 / 60 Boooo...oooooooooooooooo! 100.00%1m0s
PASS: Throughput is 150 writes/s
PASS: Slowest request took 0.145293s
PASS: Stddev is 0.021090s
PASS
{{< /terminal-output >}}

{{< terminal-comment >}}
Otherwise it might be something like this
{{< /terminal-comment >}}
{{< terminal-output >}}
 60 / 60 Boooo...oooooooooooooooo! 100.00%1m0s
FAIL: Throughput too low: 37 writes/s
Slowest request took too long: 2.187643s
Stddev too high: 0.304261s
FAIL
{{< /terminal-output >}}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
et member list
{{< /terminal-command >}}
{{< terminal-output >}}
521d9cc310c2aecb, started, etcd-node-3, https://192.168.100.13:2380, https://192.168.100.13:2379
7c35e6112f639de0, started, etcd-node-1, https://192.168.100.11:2380, https://192.168.100.11:2379
aef3e78ed8950e34, started, etcd-node-2, https://192.168.100.12:2380, https://192.168.100.12:2379
{{< /terminal-output >}}

{{< terminal-comment >}}
The documentation says you can use etcdctl endpoint --cluster to get the whole cluster status,
but that did not work for me in the stable version, let's then specify our IP
addresses instead.
{{< /terminal-comment >}}

{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
et -w table endpoint --endpoints=192.168.100.11:2379,192.168.100.12:2379,192.168.100.13:2379 status
{{< /terminal-command >}}
{{< terminal-output >}}
+---------------------+------------------+---------+---------+-----------+-----------+------------+
|      ENDPOINT       |        ID        | VERSION | DB SIZE | IS LEADER | RAFT TERM | RAFT INDEX |
+---------------------+------------------+---------+---------+-----------+-----------+------------+
| 192.168.100.11:2379 | 7c35e6112f639de0 |  3.1.10 |   22 MB |      true |       105 |       9034 |
| 192.168.100.12:2379 | aef3e78ed8950e34 |  3.1.10 |   22 MB |     false |       105 |       9034 |
| 192.168.100.13:2379 | 521d9cc310c2aecb |  3.1.10 |   22 MB |     false |       105 |       9034 |
+---------------------+------------------+---------+---------+-----------+-----------+------------+
{{< /terminal-output >}}


{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
logout
{{< /terminal-command >}}
{{< terminal-command user="core" host="etcd-node-1" path="~" >}}
logout
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
xl shutdown etcd-node-1 & xl shutdown etcd-node-2 & xl shutdown etcd-node-3 &
{{< /terminal-command >}}
{{< terminal-output >}}
[1] 18062
[2] 18063
[3] 18064
Shutting down domain 8
Shutting down domain 7
Shutting down domain 9
[1]   Done                    xl shutdown etcd-node-1
[2]-  Done                    xl shutdown etcd-node-2
[3]+  Done                    xl shutdown etcd-node-3
{{< /terminal-output >}}
{{< /terminal >}}

# Clarifications on the etcd configuration

First of all, note how the configuration we gave to Ignition above ended up
into the node's etcd systemctl unit, you can see this by printing out the unit
file from the console inside the node

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
systemctl cat etcd-member.service
{{< /terminal-command >}}
{{< terminal-output >}}
# /usr/lib/systemd/system/etcd-member.service
[Unit]
Description=etcd (System Application Container)
Documentation=https://github.com/coreos/etcd
Wants=network.target
Conflicts=etcd.service
Conflicts=etcd2.service

[Service]
Type=notify
Restart=on-failure
RestartSec=10s
TimeoutStartSec=0
LimitNOFILE=40000

Environment="ETCD_IMAGE_TAG=v3.1.10"
Environment="ETCD_NAME=%m"
Environment="ETCD_USER=etcd"
Environment="ETCD_DATA_DIR=/var/lib/etcd"
Environment="RKT_RUN_ARGS=--uuid-file-save=/var/lib/coreos/etcd-member-wrapper.uuid"

ExecStartPre=/usr/bin/mkdir --parents /var/lib/coreos
ExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/lib/coreos/etcd-member-wrapper.uuid
ExecStart=/usr/lib/coreos/etcd-wrapper $ETCD_OPTS
ExecStop=-/usr/bin/rkt stop --uuid-file=/var/lib/coreos/etcd-member-wrapper.uuid

[Install]
WantedBy=multi-user.target

# /etc/systemd/system/etcd-member.service.d/20-clct-etcd-member.conf
[Service]
ExecStart=
ExecStart=/usr/lib/coreos/etcd-wrapper $ETCD_OPTS \
  --name="etcd-node-1" \
  --listen-peer-urls="https://192.168.100.11:2380" \
  --listen-client-urls="https://192.168.100.11:2379" \
  --initial-advertise-peer-urls="https://192.168.100.11:2380" \
  --initial-cluster="etcd-node-1=https://192.168.100.11:2380,etcd-node-2=https://192.168.100.12:2380,etcd-node-3=https://192.168.100.13:2380" \
  --initial-cluster-state="new" \
  --initial-cluster-token="etcd-token" \
  --advertise-client-urls="https://192.168.100.11:2379"
# /etc/systemd/system/etcd-member.service.d/30-certs.conf
[Service]
Environment="ETCD_CERT_FILE=/etc/ssl/certs/etcd/server.pem"
Environment="ETCD_KEY_FILE=/etc/ssl/certs/etcd/server-key.pem"
Environment="ETCD_TRUSTED_CA_FILE=/etc/ssl/certs/etcd/ca.pem"
Environment="ETCD_CLIENT_CERT_AUTH=true"
Environment="ETCD_PEER_CERT_FILE=/etc/ssl/certs/etcd/peer.pem"
Environment="ETCD_PEER_KEY_FILE=/etc/ssl/certs/etcd/peer-key.pem"
Environment="ETCD_PEER_TRUSTED_CA_FILE=/etc/ssl/certs/etcd/ca.pem"
Environment="ETCD_PEER_CLIENT_CERT_AUTH=true"
{{< /terminal-output >}}
{{< /terminal >}}

as you can see the built-in etcd systemd unit is extended by two additional
.conf files created by Ignition, one with the startup command and one with the
certificates to be used via the drop-in we created.

Let's now continue to [the next part of the guide]({{< ref "xen-5.md" >}})


