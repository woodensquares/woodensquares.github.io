+++
type = "post"
title = "pfSense installation"
description = ""
tags = [
    "pfSense",
    "security",
]
date = "2016-01-01T12:31:00-08:00"
modified = "2017-12-03"
categories = [
    "Security",
]
shorttitle = "pfSense installation"
changelog = [ 
    "Initial release - 2016-01-01",
    "New highlighting for commands - 2017-12-03",
]
+++

These instructions can be followed after having X11 up and running as
per [the instructions in the second part of the Debian installation
series]({{< ref "debian-installation-part-2.md" >}}), or at any
time if you are running a different distribution and are just changing
your network environment.

I have first seen the idea of running networking through pfSense
discussed in this series of posts [^1] by Manuel Timita and in this
Linux specific post [^2] by Radovan Brezular, many thanks to both of
them for sharing their experiences and configuration.

I am running my actual physical internet firewall/gateway on
192.168.1.1, and will configure my internal pfsense-based VirtualBox
network with the following topology:

{{<centerimg alt="Networking diagram showing the actual configuration, internet cable modem - firewall at 192.168.1.1 - switch and various physical hosts, example NAS on 192.168.1.3 and a printer on 192.168.1.253, our physical host is at 192.168.1.4 Inside this host we have our virtual network, goes WAN - pfSense - various configured networks, examples here are 172.31.1.1 - DOM0 - 172.31.0/24 - andromeda 172.31.1.2, 172.30.1.1 - DEVEL - 172.30.1.0/24 - devel 172.30.1.2 , 172.30.2.1 - BLOG - 172.30.2.0/24 - blog 172.30.2.2 , 172.30.3.1 - WEB - 172.30.3.0/24 - www 172.30.3.2 - flash 172.30.3.3 - sensitive 172.30.3.4" src="/images/network.png" >}}

In this example 192.168.1.4 is my actual physical box, where we are
installing pfSense and our VMs, the other 192.168.1.x hosts are just an
example of what you could have in your physical network, as well as the
internal pfSense networks that are listed.

In this set-up there is Dom0 network for the bare-metal access to
pfSense, and various virtual networks for specific VMs, here a
development VM, a blogging VM, and several VMs to be used for web
browsing (say a normal browsing one, one with flash available, and
another for more sensitive browsing like bank access etc.)

In order to configure pfSense a browser will be required later, so let's
install iceweasel in our Dom0.

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo aptitude -t jessie-backports install iceweasel
{{< /terminal-command >}}
{{< /terminal >}}

<div id="virtualbox"></div>

VirtualBox installation
-----------------------

If you are not following my installation guide please install whatever
version of VirtualBox your distribution supports, otherwise let's grab
it from jessie-backports, since it now includes VirtualBox 5.x, of
course you can also just download it from the official site if you
prefer running the latest available release.

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo aptitude -t jessie-backports install virtualbox
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo adduser luser vboxusers
{{< /terminal-command >}}
{{< /terminal >}}

note that you will see a message saying the virtualbox service
installation failed, this is normal because the virtualbox modules have
not been compiled yet at that point, the virtualbox service will be
restarted later on, you can make sure by running *systemctl status
virtualbox.service* after the installation completes

<div id="pfsense"></div>

pfSense installation
--------------------

First of all you should grab the latest version of pfSense from the
official distribution page [^3]. The image to get is the *LiveCD with
installer* iso, either the i386 or amd64 isos will work, I will use the
amd64 one.

After downloading the iso make sure you double check the checksum of the
downloaded file, and reboot or shut down dhcpcd and disable your network
insterface so you don't have any networking running or configured.

<div id="pfsensesystemd"></div>

### systemd unit files

Let's now create the unit files we are going to use to run the
networking: in the files below I will use **eno1** as the interface
name, if your interface name is different just substitute it (you can
find the name by running *ip link*) both in the commands below and
inside vboxvm@.service.

First create the VM service at **/etc/systemd/system/vboxvm@.service**

{{< highlight bnf >}}
[Unit]
Description=VBox Virtual Machine %i Service
Requires=systemd-modules-load.service
After=systemd-modules-load.service
Requires=vboxnetwork@eno1.service
After=vboxnetwork@eno1.service
Requires=virtualbox.service
After=virtualbox.service

[Service]
User=luser
Group=vboxusers
ExecStart=/usr/bin/VBoxHeadless -s %i
ExecStop=/usr/bin/VBoxManage controlvm %i savestate

[Install]
WantedBy=multi-user.target
{{< / highlight >}}


this unit depends on the following networking service at
**/etc/systemd/system/vboxnetwork@.service**, on the general systemd
modules and on the virtualbox modules specifically.

{{< highlight bnf >}}
[Unit]
Description=Network connectivity for virtualbox (%i)
Wants=network.target
Before=network.target
BindsTo=sys-subsystem-net-devices-%i.device
After=sys-subsystem-net-devices-%i.device

[Service]
Type=oneshot
RemainAfterExit=yes

ExecStart=/sbin/ip tuntap add mode tap tap1
ExecStart=/sbin/ip addr add 172.31.1.2/24 dev tap1
ExecStart=/sbin/ip link set tap1 up
ExecStart=/sbin/ip link set dev %i up
ExecStart=/sbin/route add default gw 172.31.1.1
ExecStart=/bin/mv /etc/resolv.conf /etc/resolv.conf.vboxnetwork
ExecStart=/bin/sh -c "/bin/echo 'nameserver 172.31.1.1' > /etc/resolv.conf"

ExecStart=/bin/mv /etc/resolv.conf.vboxnetwork /etc/resolv.conf
ExecStop=/sbin/ip link set dev %i down
ExecStop=/sbin/route del default gw 172.31.1.1
ExecStop=/sbin/ip addr flush dev tap1
ExecStop=/sbin/ip link set dev tap1 down
ExecStop=/sbin/ip tuntap del mode tap tap1

[Install]
WantedBy=multi-user.target
{{< / highlight >}}

the networking service, which depends on our network interface, will
bring up our virtual tap interface and bridge it to our physical
adapter, it will also backup resolv.conf just in case and set it up so
it is redirected to our future pfSense installation, which will be
serving DNS as well.

The VM service can be used to run arbitrary headless VMs at boot and
save them at shutdown, it will be used to start up our pfSense virtual
machine after the networking service is started.

Let's now enable the network service and start it to prepare for the
actual pfSense virtual machine installation

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo systemctl enable vboxnetwork@eno1.service
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo systemctl start vboxnetwork@eno1.service
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
ip link
{{< /terminal-command >}}
{{< terminal-output >}}
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: enp9s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
3: eno1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
4: tap1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 500
    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
{{< /terminal-output >}}
{{< /terminal >}}

if everything worked correctly you should now see your tap1 device as
well as your normal network interface(s) listed if you run *ip link*

### pfSense virtual machine

It is now time to create a VM for pfSense in virtualbox, here are some
screenshots with the relevant settings, note I have plenty of RAM in my
desktop so I went with one gigabytes of ram for it, but it should work
just fine with 512 megs, or even 256 in a pinch although in that case
you might have to be a bit more careful with the pfSense options you
choose.

The VDI disk size to use is also up to you, the more space the more
logfiles you will be able to store, as well as possibly having more
storage for any extra packages you install (say, a squid proxy, which
can definitely use the extra space if you select disk-based caching)

The machine should be created with as many network interfaces you need
for your particular environment, I like having a lot of choices when it
comes to locking down specific VMs so I created my Virtualbox pfSense
installation with the ICH9 chipset and 16 nics.

First of all set up the basics

{{< centerimg alt="From now on these are virtualbox installation screenshots from the create a new vm perspective, in the initial dialog, pfSense is selected as the name, type is BSD / FreeBSD 64bit" src="/images/vbox1.png" >}}

{{< centerimg alt="in the memory size dialog 1024MB ram is selected" src="/images/vbox2.png" >}}

{{< centerimg alt="in the hard disk dialog create a virtual hard disk now is selected" src="/images/vbox3.png" >}}

{{< centerimg alt="in the hard disk file type vdi is selected" src="/images/vbox4.png" >}}

{{< centerimg alt="in the storage on physical hard disk dialog fixed size is selected" src="/images/vbox5.png" >}}

{{< centerimg alt="in the hard disk dialog 2 GB is selected for its size" src="/images/vbox6.png" >}}

Now configure the chipset and other information, set up the initial two
network interfaces to bridged and connected to your real NIC and to the
TAP interface we created earlier

{{< centerimg alt="in the system virtualbox system configuration tab, motherboard tab inside it, base memory is set to 1024MB, in the boot order floppy is deselected, optical is selected and next, hard disk is selected and next, network is deselected. The chipset type is set to ICH9, mouse type is PS/2, enable EFI and hardware clock in UTC time are deselected" src="/images/vbox7.png" >}}

{{< centerimg alt="in the storage virtualbox configuration tab, pfsense.vdi is the main image, the pfSense liveCD is in the CD controller" src="/images/vbox8.png" >}}

{{< centerimg alt="in the virtualbox audio configuration tab, enable audio is deselected" src="/images/vbox9.png" >}}

{{< centerimg alt="in the virtualbox network configuration tab, inside it the adapter 1 tab is selected, the adapter is attached to a bridged adapter, name is eno1, the adapter type is virtio-net promiscuous deny, an installation dependent mac address and a cable is connected." src="/images/vbox10.png" >}}

{{< centerimg alt="in the virtualbox network configuration tab, inside it the adapter 2 tab is selected, the adapter is attached to a bridged adapter, name is tap1, the adapter type is virtio-net promiscuous deny, an installation dependent mac address and a cable is connected." src="/images/vbox11.png" >}}

{{< centerimg alt="in the virtualbox USB configuration tab, enable USB controller is deselected" src="/images/vbox12.png" >}}

the other network interfaces instead will be created on the command
line, since the VirtualBox GUI does not allow to specify more than 4
NICs. All of them should be set to run on internal networks and of type
virtio.

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
for i in `seq 3 16`; do vboxmanage modifyvm pfSense --nic$i intnet; done
{{< /terminal-command >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
for i in `seq 3 16`; do vboxmanage modifyvm pfSense --nictype$i virtio; done
{{< /terminal-command >}}
{{< /terminal >}}

After this is done let's start up the VM and [actually install pfSense
in the next part of the tutorial]({{< ref "pfsense-installation-2.md" >}}).

[^1]: [http://timita.org/wordpress/2011/07/29/protect-your-windows-laptop-with-pfsense-and-virtualbox-part-1-preamble/](http://timita.org/wordpress/2011/07/29/protect-your-windows-laptop-with-pfsense-and-virtualbox-part-1-preamble/)

[^2]: [http://brezular.com/2015/01/18/pfsense-virtualbox-appliance-as-personal-firewall-on-linux/](http://brezular.com/2015/01/18/pfsense-virtualbox-appliance-as-personal-firewall-on-linux/)

[^3]: [https://www.pfsense.org/download/mirror.php?section=downloads#mirrors](https://www.pfsense.org/download/mirror.php?section=downloads#mirrors)

