+++
type = "post"
title = "Kubernetes and Xen, part 3: A CoreOS Xen guest"
description = ""
tags = [
    "xen",
    "kubernetes"
]
date = "2017-12-14T09:29:42-08:00"
categories = [
    "Applications",
]
shorttitle = "Kubernetes and Xen - part 3"
changelog = [
    "Initial release - 2017-12-14",
]
+++

In the [previous part of the guide]({{< ref "xen-2.md" >}}) we have completed
our basic Xen-related configuration, and we are now ready to move into
actually configuring our Kubernetes cluster. Let's start by creating a
[CoreOS](https://coreos.com) guest and showing how to configure it.

As an aside it would be possible to write scripts that would create guests and
their configuration with minimal assistance. However this blog series is
intended to be very low in "magic" so although I will make use of a couple of
scripts, they will be targeted mostly to automating "boring" tasks and should
not hide any necessary steps.

In order to navigate efficiently among multiple different guests and guest
clusters, I find it very helpful to parametrize scripts as much as possible
via environmental variables. Setting the variables themselves can be done
automatically via software like [smartcd](https://github.com/cxreg/smartcd) or
[ondir](https://github.com/alecthomas/ondir) however I personally prefer to
simply have aliases that set up the relevant environment as I will show.

First of all I would include in your bash profile something like the following

```bash
export XENDIR=/storage/xen
export PATH=$XENDIR/bin:$PATH
```

which is where we will store all our Xen files, in the previous part of the
guide I had already used this directory for our failsafe installation which
will be at $XENDIR/guests/failsafe.

Your bashrc could also have something like

```bash
xencd () 
{ 
    if [[ -z $XENDIR ]]; then
        echo XENDIR must be set;
        return 1;
    fi;
    if [[ ! -d "$XENDIR/guests/$1" ]]; then
        echo "$XENDIR/guests/$1" does not exist!;
        return 1;
    fi;
    cd "$XENDIR/guests/$1" || return;
    if [[ -f ./functions.bashrc ]]; then
        . ./functions.bashrc;
    fi
}

function _xencd()
{
    local curdir
    _init_completion || return

    curdir=$(pwd)
    cd "$XENDIR/guests" && _filedir -d
    cd "$curdir" || return
}
complete -o nospace -F _xencd xencd
```

which will put you into the relevant guest directory, with tab-completion, and
source the relevant shell functions file there if it exists. The Kubernetes
functions file I am using is [available here](/code/k8s/functions.bashrc), note it
contains a lot of code that will be discussed in future parts of this guide.

<div id="coreos"></div>

# Downloading CoreOS

It is now time to download the CoreOS image, if you are following the guide I
suggest using the same version I am using, as CoreOS is under very active
development and things might change quickly. The releases are available [at
this page](https://coreos.com/releases/), currently the stable channel is at
1520.9.0 so this is what we will be downloading. Assuming this is the first
image we download, let's also download the CoreOS signing key

{{< terminal title="andromeda" >}}

{{< terminal-command user="root" host="andromeda" path="~" >}}
mkdir $XENDIR/images
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="~" >}}
cd $XENDIR/images
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/images" >}}
wget https://stable.release.core-os.net/amd64-usr/1520.9.0/coreos_production_xen_image.bin.bz2
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/images" >}}
wget https://coreos.com/security/image-signing-key/CoreOS_Image_Signing_Key.asc
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/images" >}}
gpg --import --keyid-format LONG CoreOS_Image_Signing_Key.asc
{{< /terminal-command >}}

{{< terminal-comment >}}
it is up to you if you want to trust it, see later for more, if you do want to
trust it you would do the following
{{< /terminal-comment >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/images" >}}
gpg --edit-key CoreOS trust
{{< /terminal-command >}}
{{< terminal-output >}}
...
Please decide how far you trust this user to correctly verify other users' keys
(by looking at passports, checking fingerprints from different sources, etc.)

  1 = I don't know or won't say
  2 = I do NOT trust
  3 = I trust marginally
  4 = I trust fully
  5 = I trust ultimately
  m = back to the main menu

Your decision? 5
Do you really want to set this key to ultimate trust? (y/N) y
...
{{< /terminal-output >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/images" >}}
wget https://stable.release.core-os.net/amd64-usr/1520.9.0/coreos_production_xen_image.bin.bz2.sig
{{< /terminal-command >}}


{{< terminal-comment >}}
if you have trusted the key
{{< /terminal-comment >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/images" >}}
gpg --verify coreos_production_xen_image.bin.bz2.sig
{{< /terminal-command >}}

{{< terminal-output >}}
gpg: assuming signed data in 'coreos_production_xen_image.bin.bz2'
gpg: Signature made Thu 30 Nov 2017 03:44:57 AM PST
gpg:                using RSA key 8826AD9569F575AD3F5643E7DE2F8F87EF4B4ED9
gpg: checking the trustdb
gpg: marginals needed: 3  completes needed: 1  trust model: pgp
gpg: depth: 0  valid:   1  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 1u
gpg: Good signature from "CoreOS Buildbot (Offical Builds) <buildbot@coreos.com>" [ultimate]
{{< /terminal-output >}}


{{< terminal-comment >}}
if you have not, it will still verify, but will warn you the key is not trusted
{{< /terminal-comment >}}

{{< terminal-output >}}
gpg: assuming signed data in 'coreos_production_xen_image.bin.bz2'
gpg: Signature made Thu 30 Nov 2017 03:44:57 AM PST
gpg:                using RSA key 8826AD9569F575AD3F5643E7DE2F8F87EF4B4ED9
gpg: checking the trustdb
gpg: no ultimately trusted keys found
gpg: Good signature from "CoreOS Buildbot (Offical Builds) <buildbot@coreos.com>" [unknown]
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: 0412 7D0B FABE C887 1FFB  2CCE 50E0 8855 93D2 DCB4
     Subkey fingerprint: 8826 AD95 69F5 75AD 3F56  43E7 DE2F 8F87 EF4B 4ED9
{{< /terminal-output >}}

{{< terminal-comment >}}
let's now rename the image to something easier to use
{{< /terminal-comment >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/images" >}}
mv coreos_production_xen_image.bin.bz2 coreos-1520.9.0.bin.bz2
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/images" >}}
mv coreos_production_xen_image.bin.bz2.sig coreos-1520.9.0.bin.bz2.sig
{{< /terminal-command >}}
{{< /terminal >}}

note you should always keep the distribution images compressed (don't bzip -d
it) to save space as it contains a lot of free space in the root partition.

# Setting up the cluster

Let's now start setting up the cluster, first let's create a directory for it,
and uncompress the images we will use. The cluster will have 3 nodes, each of
which will be running a copy of etcd, that will communicate over TLS with the
others. We will call this cluster **etcd**

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/images" >}}
mkdir $XENDIR/guests/etcd
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/images" >}}
xencd etcd
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
bzcat $XENDIR/images/coreos-1520.9.0.bin.bz2 > node-1.img
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
bzcat $XENDIR/images/coreos-1520.9.0.bin.bz2 > node-2.img
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
bzcat $XENDIR/images/coreos-1520.9.0.bin.bz2 > node-3.img
{{< /terminal-command >}}
{{< /terminal >}}

The images will have root filesystems with about 2 gigs free by default, if
you needed more you can always append some free space using dd, with something
like **dd if=/dev/zero bs=1048576 count=2048 >> image.img** to add another two
gigabytes but the default space is enough for just trying etcd out. CoreOS
will automatically make use of this space because when it starts up it will
notice there is more free space and extend the root filesystem further.

Before we proceed we should take a look at what the filesystem layout is in
these images.

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
parted node-1.img unit b print
{{< /terminal-command >}}
{{< terminal-output >}}
Model:  (file)
Disk /storage/xen/guests/etcd/node-1.img: 4756340736B
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags: pmbr_boot

Number  Start        End          Size         File system  Name        Flags
 1      2097152B     136314879B   134217728B   fat16        EFI-SYSTEM  boot, legacy_boot, esp
 2      136314880B   138412031B   2097152B                  BIOS-BOOT   bios_grub
 3      138412032B   1212153855B  1073741824B  ext2         USR-A
 4      1212153856B  2285895679B  1073741824B               USR-B
 6      2285895680B  2420113407B  134217728B   ext4         OEM
 7      2420113408B  2487222271B  67108864B                 OEM-CONFIG
 9      2487222272B  4754243583B  2267021312B  ext4         ROOT
{{< /terminal-output >}}
{{< /terminal >}}

the CoreOS disk layout is [explained more at the CoreOS site
here](https://coreos.com/os/docs/latest/sdk-disk-partitions.html), the main
reason we care about it, is because of how CoreOS configurations are done.

In the [CoreOS boot
process](https://coreos.com/ignition/docs/latest/boot-process.html), at first
boot [Ignition](https://coreos.com/ignition/docs/latest/) will run in order to
configure the image. Ignition is not supposed to be something you rerun all
the time, assuming you have a valid ignition deployment file, you would simply
make it available to the image and it will set it up however you like it (add
files, systemd units, ...).

Although
[Ignition](https://coreos.com/ignition/docs/latest/getting-started.html) is
the current recommended configuration strategy, at this point in time stable
does seem to still support
[cloud-config](https://coreos.com/os/docs/latest/cloud-config.html) as a
format, with that one could create a [config
drive](https://coreos.com/os/docs/latest/config-drive.html) to pass the files
to the configurator, but again, operating with an nginx server seems a lot
easier than having to create iso image and pass them to the guest.

The location of the ignition configuration can be specified in several ways,
typically if you are running on a cloud provider there will be
provider-specific ways you could set it up, you could also use PXE
etc. however in order to make things easy to modify we will instead expose the
deployment file to Ignition over HTTP from a local nginx server. In order to
do this we'll have to pass a kernel boot parameter to ignition telling it the
URI to go to, and since we're booting this image with pygrub in Xen the
easiest way to do that is to create a grub.cfg file in the **OEM** partition
above, with an append line containing the location.

Additionally, since we will be doing some development and familiarization with
CoreOS, we do not want to have to recreate the image every time we want to
make a change, in order to do cause Ignition to run again on an already
configured image, as described above we have to create a special
coreos/first_boot file in the **EFI-SYSTEM** partition as well as removing
/etc/machine-id in the **ROOT** partition to cause systemd to refresh the
enabled units.

<div id="nginx"></div>

## Nginx setup

Let's first of all set-up nginx to serve our Ignition configuration files on
our internal guest network, this is just a matter of installing it and
creating the file below

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
aptitude -t stretch-backports install nginx
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cd /etc/nginx/sites-available
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/etc/nginx/sites-available" >}}
vi xen
{{< /terminal-command >}}
{{< terminal-comment >}}
Create this file with the following contents
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/etc/nginx/sites-available" >}}
cat xen
{{< /terminal-command >}}
{{< terminal-output >}}
server {
	listen 192.168.100.1:80 default_server;
	root /storage/xen/nginx/;
	index index.html index.htm index.nginx-debian.html;
	server_name _;
	location / {
		try_files $uri $uri/ =404;
	}
}
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/etc/nginx/sites-available" >}}
cd /etc/nginx/sites-enabled
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/etc/nginx/sites-available" >}}
rm -f default
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/etc/nginx/sites-available" >}}
ln -s /etc/nginx/sites-available/xen
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/etc/nginx/sites-available" >}}
ls -la
{{< /terminal-command >}}
{{< terminal-output >}}
total 8
drwxr-xr-x 2 root root 4096 Dec  1 11:12 .
drwxr-xr-x 8 root root 4096 Nov 30 16:27 ..
lrwxrwxrwx 1 root root   30 Dec  1 11:12 xen -> /etc/nginx/sites-available/xen
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/etc/nginx/sites-available" >}}
systemctl restart nginx.service
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/etc/nginx/sites-available" >}}
xencd etcd
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}{{< /terminal-command >}}
{{< /terminal >}}

in order for it to be accessible from our guests we have to tweak the iptables
configuration at /etc/iptables/rules.v4. We have to make sure the following
lines include port 80 in the *filter block

{{< highlight bnf >}}
# From
-A INPUT -p tcp -m tcp --syn -m conntrack --ctstate NEW --dport 22 -j ACCEPT
# To
-A INPUT -p tcp -m tcp --syn -m conntrack --ctstate NEW -m multiport --dports 22,80 -j ACCEPT

# and From
-A FORWARD -d 192.168.100.0/24 -o virbr1 -p tcp -m tcp --syn -m conntrack --ctstate NEW -m multiport --dports 22,8080 -j ACCEPT
# to
-A FORWARD -d 192.168.100.0/24 -o virbr1 -p tcp -m tcp --syn -m conntrack --ctstate NEW -m multiport --dports 22,80,8080 -j ACCEPT
{{< / highlight >}}

remember to **systemctl restart netfilter-persistent** the persistence daemon
after updating the rules.

## Grub

We now should be changing grub in our images, in order to do this we will be
mounting the OEM partition and creating the grub.cfg file

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
mkdir $XENDIR/mnt
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
mount -o loop,offset=2285895680,sizelimit=134217728 node-1.img /storage/xen/mnt/
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
echo set linux_append=\"coreos.config.url=http://192.168.100.1/etcd/node-1.json\" > /storage/xen/mnt/grub.cfg
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
umount $XENDIR/mnt
{{< /terminal-command >}}
{{< /terminal >}}

the numbers used in the mount line are taken from the parted output, note the
OEM partition start and size.

{{< highlight bash "hl_lines=6" >}}
Number  Start        End          Size         File system  Name        Flags
 1      2097152B     136314879B   134217728B   fat16        EFI-SYSTEM  boot, legacy_boot, esp
 2      136314880B   138412031B   2097152B                  BIOS-BOOT   bios_grub
 3      138412032B   1212153855B  1073741824B  ext2         USR-A
 4      1212153856B  2285895679B  1073741824B               USR-B
 6      2285895680B  2420113407B  134217728B   ext4         OEM
 7      2420113408B  2487222271B  67108864B                 OEM-CONFIG
 9      2487222272B  4754243583B  2267021312B  ext4         ROOT
{{< / highlight >}}

<div id="ct"></div>

## Ignition

we now need to create the node-1.json file for ignition to use, rather than
writing it directly [we can use
the config transpiler](https://coreos.com/os/docs/latest/overview-of-ct.html) and compile
it from a [much easier to use syntax as shown in these examples](https://coreos.com/os/docs/latest/clc-examples.html).

After checking the above page the current release is 0.5.0, so let's download
it and install it in our binaries directory and make sure we have it in PATH

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
mkdir -p $XENDIR/bin
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cd $XENDIR/bin
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/bin" >}}
wget https://github.com/coreos/container-linux-config-transpiler/releases/download/v0.5.0/ct-v0.5.0-x86_64-unknown-linux-gnu
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/bin" >}}
mv ct-v0.5.0-x86_64-unknown-linux-gnu ct
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/bin" >}}
chmod a+x ct
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/bin" >}}
xencd etcd
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
ct -version
{{< /terminal-command >}}
{{< terminal-output >}}
ct v0.5.0
{{< /terminal-output >}}
{{< /terminal >}}

Let's now create an extremely simple Ignition configuration file that will
allow us to log-in into our system by having the image accept our main ssh
identity and set the correct hostname.

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
vi node-1.ct
{{< /terminal-command >}}
{{< terminal-comment >}}
As usual create this file with these contents, note make sure there is no
extra newline at the end of the file
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cat node-1.ct
{{< /terminal-command >}}
{{< terminal-output >}}
storage:
  files:
    - filesystem: "root"
      path:       "/etc/hostname"
      mode:       0644
      contents:
        inline: etcd-node-1

passwd:
  users:
    - name: core
      ssh_authorized_keys:
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
echo -n '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;- ' >> node-1.ct
{{< /terminal-command >}}
{{< terminal-comment >}}
This assumes you do have an ssh key set up, otherwise you can generate it with
      ssh-keygen -t rsa
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cat ~/.ssh/id_rsa.pub >> node-1.ct
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cat node-1.ct
{{< /terminal-command >}}
{{< terminal-output >}}
storage:
  files:
    - filesystem: "root"
      path:       "/etc/hostname"
      mode:       0644
      contents:
        inline: etcd-node-1

passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - ssh-rsa AAAAB3N.........
{{< /terminal-output >}}
{{< /terminal >}}

This file now needs to be compiled and stored in the nginx directory with the
correct name for Ignition to find it at the URI we specified in grub.cfg,
let's do so and boot our failsafe guest to verify that nginx is working
correctly.

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
mkdir -p $XENDIR/nginx/etcd
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
ct -in-file node-1.ct -out-file $XENDIR/nginx/etcd/node-1.json
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
xencd failsafe
{{< /terminal-command >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
xl create failsafe.cfg ; xl console failsafe
{{< /terminal-command >}}

{{< terminal-output >}}
Parsing config from failsafe.cfg
[    0.032064] dmi: Firmware registration failed.
[    1.070189] dmi-sysfs: dmi entry is absent.
/dev/xvda1: clean, 32201/229376 files, 262334/917248 blocks

Debian GNU/Linux 9 failsafe hvc0

failsafe login: root
Password:
Last login: Fri Dec  1 11:25:24 PST 2017 on hvc0
Linux failsafe 4.9.0-4-amd64 #1 SMP Debian 4.9.51-1 (2017-09-28) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
{{< /terminal-output >}}
{{< terminal-command user="root" host="failsafe" path="~" >}}
apt-get install curl
{{< /terminal-command >}}
{{< terminal-command user="root" host="failsafe" path="~" >}}
curl http://192.168.100.1/etcd/node-1.json
{{< /terminal-command >}}
{{< terminal-output >}}
{"ignition":{"config":{},"timeouts":{},"version":"2.1.0"},"networkd":{},"passwd":{"users":[{"name":"core","sshAuthorizedKeys":["ssh-rsa AAAAB3......"]}]},"storage":{"files":[{"filesystem":"root","group":{},"path":"/etc/hostname","user":{},"contents":{"source":"data:,etcd-node-1","verification":{}},"mode":420}]},"systemd":{}}
{{< /terminal-output >}}
{{< terminal-command user="root" host="failsafe" path="~" >}}
{{< /terminal-command >}}
{{< terminal-comment >}}
At this point exit the console with Ctrl-]
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
xl shutdown failsafe
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
xencd etcd
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}{{< /terminal-command >}}
{{< /terminal >}}

remember if you need to debug it, you can always pretty-print the transpiled
file by piping it to **python -mjson.tool** if needed.

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cat $XENDIR/nginx/etcd/node-1.json | python -mjson.tool
{{< /terminal-command >}}
{{< terminal-output >}}
{
    "ignition": {
        "config": {},
        "timeouts": {},
        "version": "2.1.0"
    },
    "networkd": {},
    "passwd": {
        "users": [
            {
                "name": "core",
                "sshAuthorizedKeys": [
                    "ssh-rsa AAAAB3......"
                ]
            }
        ]
    },
    "storage": {
        "files": [
            {
                "contents": {
                    "source": "data:,etcd-node-1",
                    "verification": {}
                },
                "filesystem": "root",
                "group": {},
                "mode": 420,
                "path": "/etc/hostname",
                "user": {}
            }
        ]
    },
    "systemd": {}
}
{{< /terminal-output >}}
{{< /terminal >}}

## Xen configuration

The last piece of the puzzle needed to boot the guest is the Xen configuration
file, which is quite simple

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
vi node-1.cfg
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cat node-1.cfg
{{< /terminal-command >}}
{{< terminal-output >}}
bootloader = "pygrub"
name = "etcd-node-1"
memory = "1024"
vcpus = 1
vif = [ 'mac=00:16:3e:4e:31:11,model=rtl8139,bridge=virbr1' ]
disk = [ '/storage/xen/guests/etcd/node-1.img,raw,xvda' ]
{{< /terminal-output >}}
{{< /terminal >}}

note the MAC address will cause the guest to get the 192.168.100.11 address
given the dnsmasq hosts file we [created previously]({{< ref "xen-2.md#dnshosts" >}})

## Booting CoreOS for the first time

We are now ready to boot! if everything has gone well the image will contact
our nginx server to get the ignition configuration, and execute it which will
cause our chosen hostname to be taken, as well as will allow us to ssh into
CoreOS

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
xl create node-1.cfg ; xl console etcd-node-1
{{< /terminal-command >}}
{{< terminal-comment >}}
Likely the boot process will pause shortly here which will show you Ignition is working
{{< /terminal-comment >}}
{{< terminal-output >}}
...........
[    3.585099] ignition[352]: Ignition v0.17.2
[    3.680945] systemd-networkd[255]: eth0: Gained IPv6LL
[   ***] (2 of 2) A start job is running for Ignition (disks) (9s / no limit)[   11.230424] systemd-networkd[255]: eth0: DHCPv4 address 192.168.100.11/24 via 192.168.100.1
[  OK  ] Started Ignition (disks).
[  OK  ] Reached target Local File Systems (Pre).
[  OK  ] Reached target Local File Systems.
...........

This is etcd-node-1 (Linux x86_64 4.13.16-coreos-r1) 00:44:57
SSH host key: SHA256:IYkLOcKQdl3VXogZcAtAxsH+HcRciEwlYuFdf5CeObo (ED25519)
SSH host key: SHA256:Lv0lXW2uUowgguDzS4d4PkCw/1NVUsUWwA/tlUuoJX0 (ECDSA)
SSH host key: SHA256:av1Gw1vs7uRnpBTYGls/DQJ2h6ZvD717RtkQzzQhfe4 (DSA)
SSH host key: SHA256:dwYyc9jTCROeJCmiVAUYn1JPM6FCkTdJk1E3BDX9ck0 (RSA)
eth0: 192.168.100.11 fe80::216:3eff:fe4e:3111

etcd-node-1 login: 

{{< /terminal-output >}}
{{< terminal-comment >}}
Exit the console with Ctrl-] as usual, as you can't log-in directly here
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
ssh core@192.168.100.11
{{< /terminal-command >}}
{{< terminal-output >}}
Container Linux by CoreOS stable (1520.9.0)
{{< /terminal-output >}}
{{< terminal-command user="core" host="etcd-node-1" path="~" >}}
sudo systemctl poweroff
{{< /terminal-command >}}
{{< terminal-output >}}
Connection to 192.168.100.11 closed by remote host.
Connection to 192.168.100.11 closed.
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}{{< /terminal-command >}}
{{< /terminal >}}

## Running Ignition a second time

Let's now modify our coreos image to talk to our dom-0 for ntp purposes and to
use ntpd instead of timesyncd [as discussed
here](https://coreos.com/os/docs/latest/configuring-date-and-timezone.html),
in order to do this first we have to make sure our /etc/iptables/rules.v4
iptables configuration in *filter allows port 123

{{< highlight bnf >}}
# ------------------------------------------------------------------------------------------------------------
# From
# ------------------------------------------------------------------------------------------------------------
-A INPUT -i virbr1 -p udp -m udp -m multiport --dports 53,67 -j ACCEPT
-A INPUT -i virbr1 -p tcp -m tcp -m multiport --dports 53,67 -j ACCEPT
# ------------------------------------------------------------------------------------------------------------
# To
# ------------------------------------------------------------------------------------------------------------
-A INPUT -i virbr1 -p udp -m udp -m multiport --dports 53,67,123 -j ACCEPT
-A INPUT -i virbr1 -p tcp -m tcp -m multiport --dports 53,67,123 -j ACCEPT
{{< / highlight >}}

Afterwards we should install ntp in our dom-0, and change the **.tc** ignition
configuration to use it

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
aptitude -t stretch-backports install ntp
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
vi /etc/ntp.conf
{{< /terminal-command >}}
{{< terminal-comment >}}
Uncomment the broadcast line, and make it: broadcast 192.168.100.255
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cat /etc/ntp.conf | tail -8
{{< /terminal-command >}}
{{< terminal-output >}}
# If you want to provide time to your local subnet, change the next line.
# (Again, the address is an example only.)
broadcast 192.168.100.255

# If you want to listen to time broadcasts on your local subnet, de-comment the
# next lines.  Please do this only if you trust everybody on the network!
#disable auth
#broadcastclient
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
systemctl restart ntp
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
vi node-1.ct
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
cat node-1.ct
{{< /terminal-command >}}
{{< terminal-comment >}}
Note the additional file, ntp.conf and the systemd units change
{{< /terminal-comment >}}
{{< terminal-output >}}
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
...
{{< /terminal-output >}}
{{< /terminal >}}

After this is done we should: transpile the .ct file and put it on nginx,
remove /etc/machine-id in the image and create /boot/first_boot in the image
to make sure Ignition runs again.

<div id="kgen"></div>

In order to make this more straightforward I wrote a [bash function you can
put in your bashrc]({{< ref "kgen.md" >}}) that automates the image-related
operations (mounting/unmounting and file changes).

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
kgen refresh node-1
{{< /terminal-command >}}
{{< terminal-output >}}
grub.cfg set to:set linux_append="coreos.config.url=http://192.168.100.1/etcd/node-1.json"
Removed /etc/machine-id for systemd units refresh
Transpiling node-1.ct and adding it to nginx
Creating coreos/first_boot
{{< /terminal-output >}}

{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
xl create node-1.cfg ; xl console etcd-node-1
{{< /terminal-command >}}
{{< terminal-comment >}}
You will likely see this, which will confirm ignition has run again
{{< /terminal-comment >}}
{{< terminal-output >}}
...........
[    3.585099] ignition[352]: Ignition v0.17.2
[    3.680945] systemd-networkd[255]: eth0: Gained IPv6LL
[   ***] (2 of 2) A start job is running for Ignition (disks) (9s / no limit)[   11.230424] systemd-networkd[255]: eth0: DHCPv4 address 192.168.100.11/24 via 192.168.100.1
[  OK  ] Started Ignition (disks).
[  OK  ] Reached target Local File Systems (Pre).
[  OK  ] Reached target Local File Systems.
...........
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
ssh core@192.168.100.11
{{< /terminal-command >}}
{{< terminal-comment >}}
note that timesyncd is not running, but ntpd is, and check that we are synced with Dom0
{{< /terminal-comment >}}
{{< terminal-command user="core" host="etcd-node-1" path="~" >}}
systemctl status systemd-timesyncd ntpd
{{< /terminal-command >}}
{{< terminal-output >}}
● systemd-timesyncd.service
   Loaded: masked (/dev/null; bad)
   Active: inactive (dead)

● ntpd.service - Network Time Service
   Loaded: loaded (/usr/lib/systemd/system/ntpd.service; enabled; vendor preset: enabled)
   Active: active (running) since Sun 2017-12-03 23:08:33 UTC; 1min 2s ago
 Main PID: 810 (ntpd)
    Tasks: 2 (limit: 32768)
   Memory: 1.5M
      CPU: 10ms
   CGroup: /system.slice/ntpd.service
           ├─810 /usr/sbin/ntpd -g -n -f /var/lib/ntp/ntp.drift -u ntp:ntp
           └─812 /usr/sbin/ntpd -g -n -f /var/lib/ntp/ntp.drift -u ntp:ntp

Dec 03 23:08:33 etcd-node-1 ntpd[810]: Listen normally on 2 lo 127.0.0.1:123
....
{{< /terminal-output >}}
{{< terminal-command user="core" host="etcd-node-1" path="~" >}}
sudo -i
{{< /terminal-command >}}
{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
ntpdate -q 192.168.100.1
{{< /terminal-command >}}
{{< terminal-output >}}
server 192.168.100.1, stratum 3, offset 0.041362, delay 0.02573
 3 Dec 23:10:41 ntpdate[827]: adjust time server 192.168.100.1 offset 0.041362 sec
{{< /terminal-output >}}
{{< terminal-command user="root" host="etcd-node-1" path="~" >}}
systemctl poweroff
{{< /terminal-command >}}
{{< terminal-output >}}
Connection to 192.168.100.11 closed by remote host.
Connection to 192.168.100.11 closed.
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/etcd" >}}
{{< /terminal-command >}}
{{< /terminal >}}

Let's now continue to [the next part of the guide]({{< ref "xen-4.md" >}})
