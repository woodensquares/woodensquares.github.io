+++
type = "post"
title = "Kubernetes and Xen, part 2: initial Xen setup"
description = ""
tags = [
    "xen",
    "kubernetes"
]
date = "2017-12-14T09:29:36-08:00"
categories = [
    "Applications",
]
shorttitle = "Kubernetes and Xen - part 2"
changelog = [ 
    "Initial release - 2017-12-14",
]
+++

In the [previous part of the guide]({{< ref "xen-1.md" >}}) we have completed
our basic system installation, and we are now ready to move into actually
configuring Xen.

After rebooting we can verify that our bridge is correctly configured and that
we are actually in Xen with Dom0 using only 512 megs and 1 CPU.

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
brctl show
{{< /terminal-command >}}
{{< terminal-output >}}
bridge name	bridge id		STP enabled	interfaces
virbr1		8000.00163ed10be7	yes		virbr1-dummy
xenbr0		8000.b4b52fe06860	no		eno1
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
ip addr
{{< /terminal-command >}}
{{< terminal-output >}}
....

2: eno1: ..........
    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
3: xenbr0: .........
    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
    inet xxx.xxx.xxx.xxx/24 brd xxx.xxx.xxx.255 scope global xenbr0
       valid_lft forever preferred_lft forever
    inet6 xxxx::xxxx:xxxx:xxxx:xxxx/64 scope link 
       valid_lft forever preferred_lft forever

...

5: virbr1-dummy: ..........
    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
6: virbr1: ..........
    link/ether 00:16:3e:d1:0b:e7 brd ff:ff:ff:ff:ff:ff
    inet 192.168.100.1/24 brd 192.168.100.255 scope global virbr1
       valid_lft forever preferred_lft forever
    inet6 fe80::216:3eff:fed1:be7/64 scope link 
       valid_lft forever preferred_lft forever
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
xl list
{{< /terminal-command >}}
{{< terminal-output >}}
Name                                        ID   Mem VCPUs	State	Time(s)
Domain-0                                     0   512     1     r-----      11.2
{{< /terminal-output >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
xl info
{{< /terminal-command >}}
{{< terminal-output >}}
...
machine                : x86_64
nr_cpus                : 12
max_cpu_id             : 11
nr_nodes               : 1
...
total_memory           : 16307
free_memory            : 15577
...
{{< /terminal-output >}}
{{< /terminal >}}

At this point we have the needed building blocks, but before starting to boot
our first Xen guest we still need to configure the needed masquerading and
forwarding. Let's first install a package that allows us to persist our
iptables rules

{{< terminal title="andromeda" >}}
{{< terminal-comment >}}
Allow the package to save the existing rules as well as some other
useful miscellaneous packages
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
aptitude -t stretch-backports install iptables-persistent gawk bash-completion genisoimage
{{< /terminal-command >}}
{{< /terminal >}}

and overwrite the generated **/etc/iptables/rules.v4** file with the
following, please change *<your dom0 lan ip>* below to your network IP address
(i.e. the address your dom0 is accessible on when ssh'ing to it from other PCs
on your network)

This iptables configuration comes from [Jamie Nguyen's blog](https://jamielinux.com/docs/libvirt-networking-handbook/custom-nat-based-network.html)
which has a lot more detail and information on how to configure libvirt networking.

{{< highlight bnf >}}
# This format is understood by iptables-restore. See `man iptables-restore`.

*mangle
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o virbr1 -p udp -m udp --dport 68 -j CHECKSUM --checksum-fill
COMMIT


*nat
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -d  <your dom0 lan ip>/32 -p tcp -m tcp --syn --dport 8022 -j DNAT --to-destination 192.168.100.254:22
-A POSTROUTING -s 192.168.100.0/24 -d 224.0.0.0/24 -j RETURN
-A POSTROUTING -s 192.168.100.0/24 -d 255.255.255.255/32 -j RETURN
-A POSTROUTING -s 192.168.100.0/24 ! -d 192.168.100.0/24 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.100.0/24 ! -d 192.168.100.0/24 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.100.0/24 ! -d 192.168.100.0/24 -j MASQUERADE
COMMIT

*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT
-A INPUT -p tcp -m tcp --syn -m conntrack --ctstate NEW --dport 22 -j ACCEPT
-A INPUT -i virbr1 -p udp -m udp -m multiport --dports 53,67 -j ACCEPT
-A INPUT -i virbr1 -p tcp -m tcp -m multiport --dports 53,67 -j ACCEPT
-A INPUT -m conntrack --ctstate INVALID -j DROP
-A INPUT -p tcp -m tcp -j REJECT --reject-with tcp-reset
-A INPUT -j REJECT --reject-with icmp-port-unreachable

-A FORWARD -d 192.168.100.0/24 -o virbr1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.100.0/24 -i virbr1 -j ACCEPT
-A FORWARD -i virbr1 -o virbr1 -j ACCEPT
-A FORWARD -d 192.168.100.254/32 -o virbr1 -p tcp -m tcp --syn -m conntrack --ctstate NEW -m multiport --dports 22 -j ACCEPT
-A FORWARD -d <your dom0 lan ip>/32 -o virbr1 -p tcp -m tcp --syn -m conntrack --ctstate NEW -m multiport --dports 8022 -j ACCEPT
-A FORWARD -i virbr1 -j REJECT --reject-with icmp-port-unreachable
-A FORWARD -o virbr1 -j REJECT --reject-with icmp-port-unreachable
COMMIT
{{< / highlight >}}

the above will set up rules so that your guests will be able to access the
internet, and you will be able to connect to to your Dom-0 on port 8022 and
have it forwarded to the failsafe 192.168.100.254 guest on port 22 (for ssh
access).

We also have to allow the kernel to forward packets for this to work so

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
echo 1 > /proc/sys/net/ipv4/ip_forward
{{< /terminal-command >}}
{{< terminal-comment >}}
To make this permanent uncomment the following lines in /etc/sysctl.conf
{{< /terminal-comment >}}
{{< terminal-comment >}}
net.ipv4.ip_forward=1
{{< /terminal-comment >}}
{{< terminal-comment >}}
net.ipv4.conf.all.forwarding=1
{{< /terminal-comment >}}
{{< /terminal >}}

Once this is done we can start and enable the persisting daemon and check the
hrules have been applied (if you change the file again, you can simply restart
the service to have them reloaded)

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
systemctl start netfilter-persistent
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
systemctl enable netfilter-persistent
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
iptables -t nat -L
{{< /terminal-command >}}
{{< terminal-comment >}}
you should see several rules printed
{{< /terminal-comment >}}
{{< /terminal >}}

# Installing our first Xen guest

Before starting to configure etcd and Kubernetes, it is a good idea to install
a basic Debian guest we can use to easily troubleshoot network or other issues
if needed, this is also explained [at the Xen
site](https://wiki.xen.org/wiki/Debian_Guest_Installation_Using_Debian_Installer).

First of all let's create a place to store all our Xen clients and download
the needed files

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
mkdir -p /storage/xen/guests/failsafe
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="~" >}}
cd !$
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
wget http://cdn.debian.net/debian/dists/stretch/main/installer-amd64/current/images/netboot/xen/debian.cfg
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
wget http://cdn.debian.net/debian/dists/stretch/main/installer-amd64/current/images/netboot/xen/initrd.gz
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
wget http://cdn.debian.net/debian/dists/stretch/main/installer-amd64/current/images/netboot/xen/vmlinuz
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
mv debian.cfg failsafe.cfg
{{< /terminal-command >}}
{{< /terminal >}}

now it's time to create the Xen domain we'll use

{{< terminal title="andromeda" >}}
{{< terminal-comment >}}
Modify failsafe.cfg to set the following parameters
{{< /terminal-comment >}}
{{< terminal-output >}}
kernel = "/storage/xen/guests/failsafe/vmlinuz"
ramdisk = "/storage/xen/guests/failsafe/initrd.gz"
bootloader="pygrub"
extra = "debian-installer/exit/always_halt=true -- quiet console=hvc0"
memory = 512
name = "failsafe"
vif = ['mac=00:16:3e:ee:ee:01, bridge=virbr1, script=vif-bridge']
disk = ['file:/storage/xen/guests/failsafe/disk.img,xvda,w']
{{< /terminal-output >}}
{{< terminal-comment >}}
Create the image file
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
truncate -s 4G disk.img
{{< /terminal-command >}}
{{< terminal-comment >}}
And start it!
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
xl create failsafe.cfg
{{< /terminal-command >}}
{{< terminal-comment >}}
if this does not automatically show the installation screen run
{{< /terminal-comment >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
xl console failsafe
{{< /terminal-command >}}
{{< /terminal >}}

this will start a normal console debian installation process, if everything is
working fine your dhcp address should be picked up automatically, and it
should download the needed files without issues.

If you experience problems always remember you can exit a guest domain by
pressing **Control-]**, you can the *xl destroy failsafe* and try again if
needed.

If there's a network issue you can also change the vif line above and make the
guest connect directly to your physical network interface in bridged mode by
substituting **virbr1** with **xenbr0**, which should very likely work no
matter what.

Now you should remove or comment out the kernel and ramdisk lines, and change
the bootloader to pygrub by editing failsafe.cfg

{{< highlight bnf >}}
# kernel = "/storage/xen/guests/failsafe/vmlinuz"
# ramdisk = "/storage/xen/guests/failsafe/initrd.gz"
bootloader="pygrub"
{{< / highlight >}}

and you can now restart your failsafe and connect to it via

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
xl create failsafe.cfg
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
xl console failsafe
{{< /terminal-command >}}
{{< /terminal >}}

with this if you ever experience issues in your Kubernetes cluster you would
be able to boot up this Debian guest to help with debugging.

# Final preparations

To make things easier when debugging our Xen guests, we are going to make sure
they will always use the same IP address, this can be done simply by adding
the relevant mac/ip pairs in our **/var/lib/dnsmasq/virbr1/hostsfile** file as
follows for example.

<div id="dnshosts"></div>

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
cat /var/lib/dnsmasq/virbr1/hostsfile
{{< /terminal-command >}}
{{< terminal-output >}}
00:16:3e:ee:ee:01,192.168.100.254
00:16:3e:4e:31:10,192.168.100.10
00:16:3e:4e:31:11,192.168.100.11
00:16:3e:4e:31:12,192.168.100.12
...
{{< /terminal-output >}}
{{< /terminal >}}

the way it's structure is quite straightforward: the first host is our
failsafe debugging host, then 10-address blocks follow with the same MAC
prefix and the last MAC digit being the same as the IP address. This will
allow us to control the IP address our nodes get assigned via the MAC address
we specify in the Xen deployment file. The non-failsafe entries in the file
can be easily generated using a bash function like

```bash
function khostsfile {
    local macprefix='00:16:3e:4e:31:'
    local ipprefix='192.168.100.'

    for i in {10..99}
    do
        echo $macprefix$i','$ipprefix$i
    done
}
```

so, after evaluating that function, you could do something like

{{< terminal title="andromeda" >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
echo 00:16:3e:ee:ee:01,192.168.100.254 > hostsfile
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
khostsfile >> hostsfile
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
mv hostsfile /var/lib/dnsmasq/virbr1/
{{< /terminal-command >}}
{{< terminal-command user="root" host="andromeda" path="/storage/xen/guests/failsafe" >}}
systemctl restart dnsmasq@virbr1.service
{{< /terminal-command >}}
{{< /terminal >}}

to generate all the entries.

Given that this is a local development server I would suggest also editing
**/etc/ssh/sshd_config** and enabling the *PermitRootLogin prohibit-password* line,
so you can easily log in from your main workstation as root if needed after
copying over your ssh key.

Of course this and other similar considerations really depend from your
security requirements, but in this series of articles the assumption is that
the Xen/Kubernetes server you are running is a local box on your premises, if
you are installing on a hosted server somewhere you will have to evaluate the
various security trade-offs in terms of access and general server hardening
which are beyond the scope of this post series.

On your main system you could also install sshfs to make it easy to edit files
with a bash function like

```bash
# Mount over sshfs to $HOME/[servername], will map remote root to the local UID/GID
function sfs {
    sudo sshfs -o allow_other,IdentityFile=$HOME/.ssh/id_rsa,uid=$(id -u),gid=$(id -g) root@$1:/ $HOME/$1/
}
```

it is also nice to be able to connect directly to the nodes from the outside,
and to use kubectl from there as well, given this the /etc/iptables/rules.v4
file could be modified as follows with an eye of being able to run several
possible 9-node clusters with masters on .x0. See the 'changes start/end here' 
blocks below.

<div id="iptables"></div>
{{< highlight bnf >}}
*nat
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
# ------------------------------------------------------------------------------------------------------------
# Changes start here
# ------------------------------------------------------------------------------------------------------------
# Nodeport traffic
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn -m multiport --dports 31000:31999 -j DNAT --to-destination 192.168.100.10
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn -m multiport --dports 32000:32999 -j DNAT --to-destination 192.168.100.20
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn -m multiport --dports 33000:33999 -j DNAT --to-destination 192.168.100.30
....
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn -m multiport --dports 39000:39999 -j DNAT --to-destination 192.168.100.90

# Master traffic
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn --dport 8101 -j DNAT --to-destination 192.168.100.10:8443
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn --dport 8102 -j DNAT --to-destination 192.168.100.20:8443
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn --dport 8103 -j DNAT --to-destination 192.168.100.30:8443
....
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn --dport 8109 -j DNAT --to-destination 192.168.100.90:8443

# ssh access
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn --dport 8000 -j DNAT --to-destination 192.168.100.254:22
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn --dport 8010 -j DNAT --to-destination 192.168.100.10:22
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn --dport 8011 -j DNAT --to-destination 192.168.100.11:22
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn --dport 8012 -j DNAT --to-destination 192.168.100.12:22
...
-A PREROUTING -d <your dom0 lan ip>/32 -p tcp -m tcp --syn --dport 8099 -j DNAT --to-destination 192.168.100.99:22
# ------------------------------------------------------------------------------------------------------------
# Changes end here
# ------------------------------------------------------------------------------------------------------------
-A POSTROUTING -s 192.168.100.0/24 -d 224.0.0.0/24 -j RETURN
-A POSTROUTING -s 192.168.100.0/24 -d 255.255.255.255/32 -j RETURN
-A POSTROUTING -s 192.168.100.0/24 ! -d 192.168.100.0/24 -p tcp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.100.0/24 ! -d 192.168.100.0/24 -p udp -j MASQUERADE --to-ports 1024-65535
-A POSTROUTING -s 192.168.100.0/24 ! -d 192.168.100.0/24 -j MASQUERADE
COMMIT

*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT
# ------------------------------------------------------------------------------------------------------------
# Changes start here
# ------------------------------------------------------------------------------------------------------------
# Accept ssh, master and nodeport connections as well as nginx ignition requests
-A INPUT -p tcp -m tcp --syn -m conntrack --ctstate NEW -m multiport --dports 22,80,31000:39999,8443 -j ACCEPT
# Accept DNS (port 53) and DHCP (port 67) and NTPD (port 123) packets from VMs.
-A INPUT -i virbr1 -p udp -m udp -m multiport --dports 53,67,123 -j ACCEPT
-A INPUT -i virbr1 -p tcp -m tcp -m multiport --dports 53,67,123 -j ACCEPT
# ------------------------------------------------------------------------------------------------------------
# Changes end here
# ------------------------------------------------------------------------------------------------------------
-A INPUT -m conntrack --ctstate INVALID -j DROP
-A INPUT -p tcp -m tcp -j REJECT --reject-with tcp-reset
-A INPUT -j REJECT --reject-with icmp-port-unreachable
-A FORWARD -d 192.168.100.0/24 -o virbr1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s 192.168.100.0/24 -i virbr1 -j ACCEPT
-A FORWARD -i virbr1 -o virbr1 -j ACCEPT
# ------------------------------------------------------------------------------------------------------------
# Changes start here
# ------------------------------------------------------------------------------------------------------------
-A FORWARD -d 192.168.100.0/24 -o virbr1 -p tcp -m tcp --syn -m conntrack --ctstate NEW -m multiport --dports 22,80,8443,30000:39999 -j ACCEPT
-A FORWARD -d <your dom0 lan ip>/32 -o virbr1 -p tcp -m tcp --syn -m conntrack --ctstate NEW -m multiport --dports 8000:8099,8101:8109,30000:39999 -j ACCEPT
# ------------------------------------------------------------------------------------------------------------
# Changes end here
# ------------------------------------------------------------------------------------------------------------
-A FORWARD -i virbr1 -j REJECT --reject-with icmp-port-unreachable
-A FORWARD -o virbr1 -j REJECT --reject-with icmp-port-unreachable
COMMIT
{{< / highlight >}}

with these rules it is possible to ssh to your dom0 on 8000-8099 and have it
forwarded directly to cluster nodes' ssh, and to use kubectl pointed at 8101 /
8109 to get information on clusters with masters at .10, .20, .30, ...

The complete file for my Dom0 (LAN ip 192.168.1.45) is [available here for
reference](/code/k8s/rules.v4) and the rest of the series will assume you are
running that file in your own Dom0 (please remember to change 192.168.1.45 to
whatever LAN IP your Dom0 has)

In order to avoid ssh warnings/errors, given that likely a lot of the guest
ssh host keys might change, I have the following in my main computer's
**~/.ssh/config**

{{< highlight bnf >}}
Host andromeda
    LogLevel ERROR
    IdentityFile ~/.ssh/andromeda_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
{{< / highlight >}}

where this identity file is only used to access my guests on this machine, and
similarly inside the root .ssh folder on the andromeda machine I have

{{< highlight bnf >}}
Host 192.168.*.*
    LogLevel ERROR
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
{{< / highlight >}}

to be able to ssh to guests without having to worry about key changes due to
guests being recreated.

Let's now continue to [the next part of the guide]({{< ref "xen-3.md" >}})
