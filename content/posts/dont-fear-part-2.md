+++
type = "post"
title = "Don't fear the command line, a running system"
description = ""
tags = [
    "debian",
]
date = "2025-04-27T14:31:12-06:00"
categories = [
    "Debian",
]
shorttitle = "DFTCL 2 - a running system"
changelog = [ 
    "Initial release - 2025-04-27",
]
+++

{{< toc >}}

At the [end of the minimal installation instructions]({{< ref
"dont-fear-part-1.md#reboot" >}}) we
ended up with a bare-bones Debian installation, where we can now login
as root with the password that was entered [as part of the
installation]({{< ref "debian-installation-part-1.md#rootpassword" >}}).

## Networking setup

Networking is definitely the most environment dependent thing, so you will likely
have to adapt this section to your setup. First of all let's make sure that
all your interfaces are up and running, for simplicity I will also assume that
you have a wired connection at least to start with

```terminal { title="Debian host" }
!!luser!!host!!~!!sudo -i
!# You might have to confirm with 'yes' that you do understand what sudo is
!!root!!host!!~!!ip addr
  1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
      link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
      inet 127.0.0.1/8 scope host lo
         valid_lft forever preferred_lft forever
  2: enp6s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
      link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
      inet 192.168.1.162/24 brd 192.168.1.255 scope global noprefixroute enp6s0
         valid_lft forever preferred_lft forever
  3: wlp5s0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
      link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
```

if you just care about wired networking, you can simply **systemctl enable dhcpcd.service** and
**systemctl start dhcpcd.service** at this point (if it was not already running) and that's about it.
If you instead want to use wireless networking, hopefully you have [installed the wifi packages
as discussed in the previous step]({{< ref "dont-fear-part-1.md#wifi-packages" >}}) so you can follow
the next steps.

As you can see from the output of *ip addr* above, in this case the WIFI interface is *wlp5s0*, you can also
see this by running **iwconfig** and verifying you can see the access points you might be interested in
by running **iwlist**

```terminal { title="Debian host" }
!!root!!host!!~!!iwconfig
  lo        no wireless extensions.
   
  enp6s0    no wireless extensions.
   
  wlp5s0    IEEE 802.11  ESSID:off/any
            Mode:Managed  Access Point: Not-Associated   Tx-Power=-2147483648 dBm
            Retry short limit:7   RTS thr:off   Fragment thr:off
            Encryption key:off
            Power Management:on
!!root!!host!!~!!iwlist wlp5s0 scan
  wlp5s0    Scan completed :
!.
```

Assuming now that you have your wireless password, you can connect to your access
point by doing the following steps, which will enable dhcpcd to automatically
use wpa_supplicant to configure your WIFI.

```terminal { title="Debian host" }
!!root!!host!!~!!wpa_passphrase 'your network SSID' 'your wifi password'
  network={
  	ssid="your network SSID"
  	#psk="your wifi password"
  	psk=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  }
!!root!!host!!~!!vi /etc/wpa_supplicant/wpa_supplicant.conf
!.
!!root!!host!!~!!cat /etc/wpa_supplicant/wpa_supplicant.conf
  network={
  	ssid="your network SSID"
  	psk=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  }
  ctrl_interface_group=root
  ctrl_interface=/run/wpa_supplicant
  update_config=1
  ap_scan=1
  country=US
!# Note I removed the plaintext password, also if you are not
!# in the US change the country above
!!root!!host!!~!!ln -s /usr/share/dhcpcd/hooks/10-wpa_supplicant /usr/lib/dhcpcd/dhcpcd-hooks/
!!root!!host!!~!!systemctl disable wpa_supplicant.service 
!!root!!host!!~!!systemctl reenable dhcpcd.service 
!!root!!host!!~!!systemctl restart dhcpcd.service 
```

if everything is correct you should now see an IP address associated to
your WIFI network card as well. If this is not working for you, there is a lot of information about wpa_supplicant
and dhcpcd on the arch wiki at [^1] and [^2]

```terminal { title="Debian host" }
!!root!!host!!~!!ip addr
  1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
      link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
      inet 127.0.0.1/8 scope host lo
         valid_lft forever preferred_lft forever
  2: enp6s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
      link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
      inet 192.168.1.162/24 brd 192.168.1.255 scope global noprefixroute enp6s0
         valid_lft forever preferred_lft forever
  3: wlp5s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
      link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
      inet 192.168.1.96/24 brd 192.168.1.255 scope global noprefixroute wlp5s0
         valid_lft forever preferred_lft forever
```

if you have both a wired and a wireless connection, it is likely a good idea to
prioritize traffic going to your wired interface, rather than your wireless one,
in general it seems the above will set things correctly, you can check this using
the route command

```terminal { title="Debian host" }
!!root!!host!!~!!route -n
  Kernel IP routing table
  Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
  0.0.0.0         192.168.1.1     0.0.0.0         UG    202    0        0 enp6s0
  0.0.0.0         192.168.1.1     0.0.0.0         UG    303    0        0 wlp5s0
  192.168.1.0     0.0.0.0         255.255.255.0   U     202    0        0 enp6s0
  192.168.1.0     0.0.0.0         255.255.255.0   U     303    0        0 wlp5s0
```

for example here you can see how the wired interface is getting 202 as the metric,
while the wireless has 303, meaning traffic will prefer the wired whenever possible.
This can be changed by running something like **ifmetric wlp5s0 100** which would
make traffic prefer your wireless network, this can be made permanent creating 
an appropriate script for your interface as described in [^3] or by changing the
dhcpcd configuration.

If you have wired and wireless and your DHCP server creates DNS records, you should
probably set things up so that each interface has its own hostname, this can be done
in dhcpcd.conf as follows by adding interface specific lines at the end of the file,
note I have also commented the **hostname** line earlier in the file.

```terminal { title="Debian host" }
!!root!!host!!~!!cat /etc/dhcpcd.conf  | tail
  # Generate SLAAC address using the Hardware Address of the interface
  #slaac hwaddr
  # OR generate Stable Private IPv6 Addresses based from the DUID
  slaac private
   
  interface enp6s0
  hostname yourwiredhostname
   
  interface wlp5s0
  hostname yourwifihostname
```

other customizations to dhcpcd are out of scope for this document, however there are
several pointers at the relevant Arch Wiki page [https://wiki.archlinux.org/title/Dhcpcd](https://wiki.archlinux.org/title/Dhcpcd)
which was linked earlier, especially if you want to override DNS servers etc.

## Time and date

First of all let's set up our locale, note that we'll get warnings on apt commands
about our locale before we do, the below assumes `en_US.UTF-8` but of course choose
whatever you need.

```terminal { title="Debian host" }
!!root!!host!!~!!apt-get install -y locales
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following packages were automatically installed and are no longer required:
    libevent-core-2.1-7 libevent-pthreads-2.1-7 libopts25 sntp
  Use 'apt autoremove' to remove them.
  The following additional packages will be installed:
    libc-l10n
  The following NEW packages will be installed:
    libc-l10n locales
  0 upgraded, 2 newly installed, 0 to remove and 1 not upgraded.
  Need to get 4950 kB of archives.
  After this operation, 20.9 MB of additional disk space will be used.
  Get:1 http://yourmirror.net.net/debian bullseye/main amd64 libc-l10n all 2.31-13+deb11u5 [865 kB]
  Get:2 http://yourmirror.net.net/debian bullseye/main amd64 locales all 2.31-13+deb11u5 [4086 kB]
  Fetched 4950 kB in 1s (5365 kB/s)
  perl: warning: Setting locale failed.
  perl: warning: Please check that your locale settings:
  	LANGUAGE = (unset),
  	LC_ALL = (unset),
  	LANG = "en_US.UTF-8"
      are supported and installed on your system.
  perl: warning: Falling back to the standard locale ("C").
  locale: Cannot set LC_CTYPE to default locale: No such file or directory
  locale: Cannot set LC_MESSAGES to default locale: No such file or directory
  locale: Cannot set LC_ALL to default locale: No such file or directory
  Preconfiguring packages ...
  Selecting previously unselected package libc-l10n.
  (Reading database ... 26901 files and directories currently installed.)
  Preparing to unpack .../libc-l10n_2.31-13+deb11u5_all.deb ...
  Unpacking libc-l10n (2.31-13+deb11u5) ...
  Selecting previously unselected package locales.
  Preparing to unpack .../locales_2.31-13+deb11u5_all.deb ...
  Unpacking locales (2.31-13+deb11u5) ...
  Setting up libc-l10n (2.31-13+deb11u5) ...
  Setting up locales (2.31-13+deb11u5) ...
  Generating locales (this might take a while)...
  Generation complete.
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
!!root!!host!!~!!locale
  locale: Cannot set LC_CTYPE to default locale: No such file or directory
  locale: Cannot set LC_MESSAGES to default locale: No such file or directory
  locale: Cannot set LC_ALL to default locale: No such file or directory
  LANG=en_US.UTF-8
  LANGUAGE=
  LC_CTYPE="en_US.UTF-8"
  LC_NUMERIC="en_US.UTF-8"
  LC_TIME="en_US.UTF-8"
  LC_COLLATE="en_US.UTF-8"
  LC_MONETARY="en_US.UTF-8"
  LC_MESSAGES="en_US.UTF-8"
  LC_PAPER="en_US.UTF-8"
  LC_NAME="en_US.UTF-8"
  LC_ADDRESS="en_US.UTF-8"
  LC_TELEPHONE="en_US.UTF-8"
  LC_MEASUREMENT="en_US.UTF-8"
  LC_IDENTIFICATION="en_US.UTF-8"
  LC_ALL=
!!root!!host!!~!!dpkg-reconfigure locales
!# Choose the locale(s) you want to generate
  perl: warning: Setting locale failed.
  perl: warning: Please check that your locale settings:
  	LANGUAGE = (unset),
  	LC_ALL = (unset),
  	LANG = "en_US.UTF-8"
      are supported and installed on your system.
  perl: warning: Falling back to the standard locale ("C").
  locale: Cannot set LC_CTYPE to default locale: No such file or directory
  locale: Cannot set LC_MESSAGES to default locale: No such file or directory
  locale: Cannot set LC_ALL to default locale: No such file or directory
  /usr/bin/locale: Cannot set LC_CTYPE to default locale: No such file or directory
  /usr/bin/locale: Cannot set LC_MESSAGES to default locale: No such file or directory
  /usr/bin/locale: Cannot set LC_ALL to default locale: No such file or directory
  Generating locales (this might take a while)...
    en_US.UTF-8... done
  Generation complete.
!# now set the system locale
!!root!!host!!~!!localectl set-locale LANG=en_US.UTF-8
!# at this point you should log out from the user and log back in
!!root!!host!!~!!locale
!# Note no more warnings
  LANG=en_US.UTF-8
  LANGUAGE=
  LC_CTYPE="en_US.UTF-8"
  LC_NUMERIC="en_US.UTF-8"
  LC_TIME="en_US.UTF-8"
  LC_COLLATE="en_US.UTF-8"
  LC_MONETARY="en_US.UTF-8"
  LC_MESSAGES="en_US.UTF-8"
  LC_PAPER="en_US.UTF-8"
  LC_NAME="en_US.UTF-8"
  LC_ADDRESS="en_US.UTF-8"
  LC_TELEPHONE="en_US.UTF-8"
  LC_MEASUREMENT="en_US.UTF-8"
  LC_IDENTIFICATION="en_US.UTF-8"
  LC_ALL=
```

Now that we have the locale, let's fix our timezone, again choose whatever works
for you

```terminal { title="Debian host" }
!!root!!host!!~!!date
  Sun 19 Feb 2023 09:03:59 PM UTC
!!root!!host!!~!!timedatectl
                 Local time: Sun 2023-02-19 21:05:05 UTC
             Universal time: Sun 2023-02-19 21:05:05 UTC
                   RTC time: Sun 2023-02-19 21:05:05
                  Time zone: Etc/UTC (UTC, +0000)
  System clock synchronized: no
                NTP service: n/a
            RTC in local TZ: no
!!root!!host!!~!!ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
!!root!!host!!~!!echo 'America/Chicago' > /etc/timezone
!!root!!host!!~!!timedatectl set-timezone America/Chicago
!!root!!host!!~!!timedatectl
                 Local time: Sun 2023-02-19 15:05:50 CST
             Universal time: Sun 2023-02-19 21:05:50 UTC
                   RTC time: Sun 2023-02-19 21:05:50
                  Time zone: America/Chicago (CST, -0600)
  System clock synchronized: no
                NTP service: n/a
            RTC in local TZ: no
!!root!!host!!~!!date
  Sun 19 Feb 2023 03:06:20 PM CST
!!root!!host!!~!!apt-get install -y chrony
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following packages were automatically installed and are no longer required:
    libevent-core-2.1-7 libevent-pthreads-2.1-7 libopts25 sntp
  Use 'apt autoremove' to remove them.
  Suggested packages:
    dnsutils networkd-dispatcher
  The following NEW packages will be installed:
    chrony
  0 upgraded, 1 newly installed, 0 to remove and 1 not upgraded.
  Need to get 0 B/287 kB of archives.
  After this operation, 644 kB of additional disk space will be used.
  Selecting previously unselected package chrony.
  (Reading database ... 27554 files and directories currently installed.)
  Preparing to unpack .../chrony_4.0-8+deb11u2_amd64.deb ...
  Unpacking chrony (4.0-8+deb11u2) ...
  Setting up chrony (4.0-8+deb11u2) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
!!root!!host!!~!!chronyc sources
  MS Name/IP address         Stratum Poll Reach LastRx Last sample
  ===============================================================================
  ^+ 172.107.84.94                 4   6     7     2   -231us[-3431us] +/-   28ms
  ^- ntp.xtom.com                  2   6    17     0  -2366us[-2366us] +/-   75ms
  ^- srv11.dynamigs.net            2   6    17     0  +3715us[+3715us] +/-  112ms
  ^* time.ecansol.net              1   6     7     2   +167us[-3033us] +/-   25ms
  !!root!!host!!~!!timedatectl
                   Local time: Sun 2023-02-19 15:39:17 CST
               Universal time: Sun 2023-02-19 21:39:17 UTC
                     RTC time: Sun 2023-02-19 21:39:17
                    Time zone: America/Chicago (CST, -0600)
    System clock synchronized: yes
                  NTP service: active
              RTC in local TZ: no
!!root!!host!!~!!
```

As you can see timedatectl will now confirm you are using NTP.

## Time and date (deprecated)

*Note in my latest installs for some reason despite apt-file showing **62-chrony.conf** being
part of the dhcpcd package, it was not there. I am not sure why. Same thing for the
chrony package showing chrony-helper, but that not being installed. This could be a
difference between **bullseye** and **bookworm**, I will leave this here for reference
but the current way to achieve this might be different*

If your dhcp server is also set up to send you NTP information, you can get it automatically set
in chrony, it should work by default however the dhcpcd hook script is looking
for `chrony-helper` in `/usr/lib` while my chrony package put it in `/usr/libexec`,
so fixing it is just a symlink away, but verify this is needed in your case. After
this enable the relevant option in `dhcpcd.conf`

```terminal { title="Debian host" }
!!root!!host!!~!!cat /lib/dhcpcd/dhcpcd-hooks/62-chrony.conf
  # vi: ft=sh
  
  SERVERFILE_IPV4="/var/lib/dhcp/chrony.servers.ipv4.$interface"
  SERVERFILE_IPV6="/var/lib/dhcp/chrony.servers.ipv6.$interface"
  
  reload_config() {
  	/usr/libexec/chrony/chrony-helper update-daemon || :
  }
  
  rebuild_config() {
  	for server in $new_ntp_servers; do
  		echo "$server iburst" >> "$SERVERFILE"
  	done
  }
  
  if [ -e /usr/libexec/chrony/chrony-helper ]; then
  	handle_reason
  fi
!!root!!host!!~!!cat /lib/dhcpcd/dhcpcd-hooks/62-chrony.conf  | grep helper
  	/usr/lib/chrony/chrony-helper update-daemon || :
  if [ -e /usr/lib/chrony/chrony-helper ]; then
!!root!!host!!~!!ls -la /usr/lib/chrony/chrony-helper
  ls: cannot access '/usr/lib/chrony/chrony-helper': No such file or directory  
!!root!!host!!~!!ln -s /usr/libexec/chrony /usr/lib/chrony
!!root!!host!!~!!vi /etc/dhcpcd.conf
!# depending on your networking configuration, either simply  
!# uncomment the option ntp_servers line, or add one after
!# the interface the dhcp server returns ntp information for
!!root!!host!!~!!systemctl restart dhcpcd.service
!!root!!host!!~!!chronyc sources -v
  
    .-- Source mode  '^' = server, '=' = peer, '#' = local clock.
   / .- Source state '*' = current best, '+' = combined, '-' = not combined,
  | /             'x' = may be in error, '~' = too variable, '?' = unusable.
  ||                                                 .- xxxx [ yyyy ] +/- zzzz
  ||      Reachability register (octal) -.           |  xxxx = adjusted offset,
  ||      Log2(Polling interval) --.      |          |  yyyy = measured offset,
  ||                                \     |          |  zzzz = estimated error.
  ||                                 |    |           \
  MS Name/IP address         Stratum Poll Reach LastRx Last sample
  ===============================================================================
  ^+ 172.107.84.94                 4   7   377    96   -314us[ -314us] +/-   29ms
  ^- ntp.xtom.com                  2   7   377    32  -1798us[-1798us] +/-   57ms
  ^- srv11.dynamigs.net            2   8   377   159  +1421us[+1421us] +/-  101ms
  ^* time.ecansol.net              1   8   377   160    +39us[ -155us] +/-   25ms
  ^? bogusntpserver.localdomain    0   8     0     -     +0ns[   +0ns] +/-    0ns
!!root!!host!!~!!
```

as you can see now the dhcp ntp server is added to the list (non functional in my
example above). By default chrony is set up with the debian ntp pool, if you want
to use something else, just create a file in `/etc/chrony/sources.d` named `yoursource.sources`
containing `server x.y.w.z` lines, afterwards simply `chronyc reload sources`.

## Your shell

Choosing a shell is really up to you, however this series of articles will be using
zsh, so let's set it up now

```terminal { title="Debian host" }
!!root!!host!!~!!apt-get install -y zsh
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    zsh-common
  Suggested packages:
    zsh-doc
  The following NEW packages will be installed:
    zsh zsh-common
  0 upgraded, 2 newly installed, 0 to remove and 6 not upgraded.
  Need to get 4,849 kB of archives.
  After this operation, 18.3 MB of additional disk space will be used.
  Get:1 http://yourmirror.net.net/debian bullseye/main amd64 zsh-common all 5.8-6+deb11u1 [3,941 kB]
  Get:2 http://yourmirror.net.net/debian bullseye/main amd64 zsh amd64 5.8-6+deb11u1 [908 kB]
  Fetched 4,849 kB in 1s (4,800 kB/s)
  Selecting previously unselected package zsh-common.
  (Reading database ... 72219 files and directories currently installed.)
  Preparing to unpack .../zsh-common_5.8-6+deb11u1_all.deb ...
  Unpacking zsh-common (5.8-6+deb11u1) ...
  Selecting previously unselected package zsh.
  Preparing to unpack .../zsh_5.8-6+deb11u1_amd64.deb ...
  Unpacking zsh (5.8-6+deb11u1) ...
  Setting up zsh-common (5.8-6+deb11u1) ...
  Setting up zsh (5.8-6+deb11u1) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
!!root!!host!!~!!su - luser
!!luser!!host!!~!!chsh
  Password:
  Changing the login shell for luser
  Enter the new value, or press ENTER for the default
  	Login Shell [/bin/bash]: /usr/bin/zsh
!!luser!!host!!~!!exit
!!root!!host!!~!!su - luser
  This is the Z Shell configuration function for new users,
  zsh-newuser-install.
  You are seeing this message because you have no zsh startup files
  (the files .zshenv,
!#choose (2) for a basic default setup.
!!luser!!host!!~!!
```

the first time you log in after configuring zsh, you will be presented with the above
screen, although we will be changing things later, let's for now start with a basic
zsh setup, so choose (2) for a basic default setup.

After doing so let's set up some basic directories for any additional programs we will
be compiling at this time

```terminal { title="Debian host" }
!!luser!!host!!~!!rm $HOME/.bash_* $HOME/.bashrc
!!luser!!host!!~!!for i in {1..8}; do mkdir -p $HOME/.local/man/man$i; done
!!luser!!host!!~!!mkdir $HOME/.local/bin
!!luser!!host!!~!!mkdir $HOME/sources
!!luser!!host!!~!!echo 'export PATH=$HOME/.local/bin:$PATH' > ~/.zshenv
```

in general I find **GNU stow** to be quite helpful to manage multiple versions
of self-compiled programs, let's set that up now

```terminal { title="Debian host" }
!!luser!!host!!~!!sudo apt-get install -y stow
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  Suggested packages:
    doc-base
  The following NEW packages will be installed:
    stow
  0 upgraded, 1 newly installed, 0 to remove and 20 not upgraded.
  Need to get 410 kB of archives.
  After this operation, 865 kB of additional disk space will be used.
  Get:1 http://yourmirror.net.net/debian bullseye/main amd64 stow all 2.3.1-1 [410 kB]
  Fetched 410 kB in 0s (3,256 kB/s)
  Selecting previously unselected package stow.
  (Reading database ... 82107 files and directories currently installed.)
  Preparing to unpack .../archives/stow_2.3.1-1_all.deb ...
  Unpacking stow (2.3.1-1) ...
  Setting up stow (2.3.1-1) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
!!luser!!host!!~!!echo 'export STOW_DIR=/usr/local/stow' >> ~/.zshenv
```

## Network card sleeping issues

This might or might not happen to you, however in the last AMD system(s) I have installed
for some reason if there is no network traffic the ethernet card will go to "sleep" and
the next time there is any network traffic it will take a few seconds to "wake up" which is
annoying, while the card is sleeping it is also impossible to ssh to the host, which is
a dealbreaker for me.

I have gone through a lot of documentation and I have not found anything that can turn off
this behavior yet, in linux or in the bios, however a simple workaround is to create a dummy
service that just pings my router, this keeps the card busy enough so that it doesn't sleep
and is not an issue for the system. To do this simply create the following file and enable
the service (note you can run this as whatever user you see fit by changing the User= line,
also obviously change 192.168.1.1 to whatever is the IP address of your router)

```terminal { title="Debian host" }
!!root!!host!!~!!vi /usr/local/bin/pinger.sh
!.
!!root!!host!!~!!cat /usr/local/bin/pinger.sh
  #!/bin/sh
  ping -i 2 -4 192.168.1.1 > /dev/null
!!root!!host!!~!!chmod a+x /usr/local/bin/pinger.sh
!!root!!host!!~!!vi /etc/systemd/system/pinger.service
!.
!!root!!host!!~!!cat /etc/systemd/system/pinger.service
  [Unit]
  Description=Background ping due to ACPI NIC issues
  After=network.target
  StartLimitIntervalSec=0
   
  [Service]
  Type=simple
  ExecStart=/usr/local/bin/pinger.sh
  Restart=always
  RestartSec=5
  User=luser
  # StandardOutput=/path/to/log
  # StandardError=/path/to/log
  # SyslogIdentifier=PINGER
   
  [Install]
  WantedBy=multi-user.target
!!root!!host!!~!!systemctl enable pinger.service
  Created symlink /etc/systemd/system/multi-user.target.wants/pinger.service → /etc/systemd/system/pinger.service.
!!root!!host!!~!!systemctl start pinger.service
  ● pinger.service - Background ping due to ACPI NIC issues
       Loaded: loaded (/etc/systemd/system/pinger.service; enabled; preset: enabled)
       Active: active (running) since Sun 2023-02-26 16:20:49 CST; 3s ago
     Main PID: 4085 (pinger.sh)
        Tasks: 2 (limit: 76252)
       Memory: 560.0K
       CGroup: /system.slice/pinger.service
               ├─4085 /bin/sh /usr/local/bin/pinger.sh
               └─4087 ping -4 -i 2 192.168.1.1
  
  Feb 26 16:20:49 yourhostname systemd[1]: Started pinger.service - Background ping due to ACPI NIC issues.
!!root!!host!!~!!ps -aux | grep ping
  luser       4085  0.0  0.0   2484   512 ?        Ss   16:20   0:00 /bin/sh /usr/local/bin/pinger.sh
  luser       4087  0.0  0.0   7264   720 ?        S    16:20   0:00 ping -4 -i 2 192.168.1.1
  root        4093  0.0  0.0   6244   636 pts/0    S+   16:21   0:00 grep ping```
```

## X11

Setting up X11 is dependent on your video card, I suggest looking at the instructions
on the Debian official site for up-to-date information, however here are a couple of examples

### NVidia drivers

More details on the NVidia install are available at [^5], however note that it seems that the latest
drivers are available in the base distribution and *not* in backports, you can see this by running

```terminal { title="Debian host" }
!!root!!host!!~!!apt-cache policy nvidia-kernel-dkms
    Installed: 525.147.05-7~deb12u1
    Candidate: 535.183.06-1~bpo12+1
    Version table:
       535.216.03-1 400
          400 http://deb.debian.org/debian trixie/non-free amd64 Packages
       535.183.06-1~bpo12+1 900
          900 http://deb.debian.org/debian bookworm-backports/non-free amd64 Packages
       535.183.01-1~deb12u1 500
          500 http://deb.debian.org/debian bookworm/non-free amd64 Packages
   *** 525.147.05-7~deb12u1 500
          500 http://deb.debian.org/debian bookworm-updates/non-free amd64 Packages
          100 /var/lib/dpkg/status
       470.256.02-2 100
          100 http://deb.debian.org/debian bullseye/non-free amd64 Packages
```

depending on which version you want you might want to pass a specific **-t debianrelease** to the apt-get command, 
anyways first of all do remember to install the kernel headers

```terminal { title="Debian host" }
!!root!!host!!~!!apt-get install -y linux-headers-amd64
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    cpp-10 fontconfig-config fonts-dejavu-core gcc-10 libasan6 libatomic1 libc-dev-bin libc-devtools libc6-dev libcc1-0 libcrypt-dev libdeflate0 libfontconfig1 libgcc-10-dev libgd3 libgomp1 libisl23 libitm1 libjbig0 libjpeg62-turbo liblsan0 libmpc3 libmpfr6 libnsl-dev
    libquadmath0 libtiff5 libtirpc-dev libtsan0 libubsan1 libwebp6 libxpm4 linux-compiler-gcc-10-x86 linux-headers-6.0.0-0.deb11.6-amd64 linux-headers-6.0.0-0.deb11.6-common linux-kbuild-6.0 linux-libc-dev manpages manpages-dev
  Suggested packages:
    gcc-10-locales gcc-10-multilib gcc-10-doc glibc-doc libgd-tools
  The following NEW packages will be installed:
    cpp-10 fontconfig-config fonts-dejavu-core gcc-10 libasan6 libatomic1 libc-dev-bin libc-devtools libc6-dev libcc1-0 libcrypt-dev libdeflate0 libfontconfig1 libgcc-10-dev libgd3 libgomp1 libisl23 libitm1 libjbig0 libjpeg62-turbo liblsan0 libmpc3 libmpfr6 libnsl-dev
    libquadmath0 libtiff5 libtirpc-dev libtsan0 libubsan1 libwebp6 libxpm4 linux-compiler-gcc-10-x86 linux-headers-6.0.0-0.deb11.6-amd64 linux-headers-6.0.0-0.deb11.6-common linux-headers-amd64 linux-kbuild-6.0 linux-libc-dev manpages manpages-dev
  0 upgraded, 39 newly installed, 0 to remove and 1 not upgraded.
  Need to get 60.0 MB of archives.
  After this operation, 223 MB of additional disk space will be used.
!.
  Setting up gcc-10 (10.2.1-6) ...
  Setting up libc6-dev:amd64 (2.31-13+deb11u5) ...
  Setting up libfontconfig1:amd64 (2.13.1-4.2) ...
  Setting up linux-compiler-gcc-10-x86 (6.0.12-1~bpo11+1) ...
  Setting up linux-headers-6.0.0-0.deb11.6-amd64 (6.0.12-1~bpo11+1) ...
  Setting up libgd3:amd64 (2.3.0-2) ...
  Setting up libc-devtools (2.31-13+deb11u5) ...
  Setting up linux-headers-amd64 (6.0.12-1~bpo11+1) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
```

and then you can install the actual drivers

```terminal { title="Debian host" }
!!root!!host!!~!!apt-get install -t bookworm-backports nvidia-kernel-dkms nvidia-driver nvidia-xconfig
```

and reboot once you're done

### AMD drivers

These days most AMD cards work with **amdgpu** so you can just install the following (more details
at [^4])

```terminal { title="Debian host" }
!!root!!host!!~!!apt-get install -y firmware-amd-graphics libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers xserver-xorg-video-amdgpu
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  firmware-amd-graphics is already the newest version (20210818-1~bpo11+1).
  The following additional packages will be installed:
    libdrm-amdgpu1 libdrm-common libdrm-intel1 libdrm-nouveau2 libdrm-radeon1 libdrm2 libegl-mesa0 libegl1 libepoxy0 libfontenc1 libgbm1 libgl1 libglapi-mesa libglvnd0 libglx0 libice6 libllvm11 libpciaccess0 libpixman-1-0 libsensors-config libsensors5 libsm6
    libunwind8 libvulkan1 libwayland-client0 libwayland-server0 libx11-xcb1 libxaw7 libxcb-dri2-0 libxcb-dri3-0 libxcb-glx0 libxcb-present0 libxcb-randr0 libxcb-shm0 libxcb-sync1 libxcb-xfixes0 libxdamage1 libxfixes3 libxfont2 libxkbfile1 libxmu6 libxshmfence1 libxt6
    libxxf86vm1 libz3-4 x11-common x11-xkb-utils xfonts-base xfonts-encodings xfonts-utils xserver-common xserver-xorg-core
  Suggested packages:
    pciutils lm-sensors xfs | xserver xfonts-100dpi | xfonts-75dpi xfonts-scalable
  The following NEW packages will be installed:
    libdrm-amdgpu1 libdrm-common libdrm-intel1 libdrm-nouveau2 libdrm-radeon1 libdrm2 libegl-mesa0 libegl1 libepoxy0 libfontenc1 libgbm1 libgl1 libgl1-mesa-dri libglapi-mesa libglvnd0 libglx-mesa0 libglx0 libice6 libllvm11 libpciaccess0 libpixman-1-0 libsensors-config
    libsensors5 libsm6 libunwind8 libvulkan1 libwayland-client0 libwayland-server0 libx11-xcb1 libxaw7 libxcb-dri2-0 libxcb-dri3-0 libxcb-glx0 libxcb-present0 libxcb-randr0 libxcb-shm0 libxcb-sync1 libxcb-xfixes0 libxdamage1 libxfixes3 libxfont2 libxkbfile1 libxmu6
    libxshmfence1 libxt6 libxxf86vm1 libz3-4 mesa-vulkan-drivers x11-common x11-xkb-utils xfonts-base xfonts-encodings xfonts-utils xserver-common xserver-xorg-core xserver-xorg-video-amdgpu
  0 upgraded, 56 newly installed, 0 to remove and 1 not upgraded.
  Need to get 55.5 MB of archives.
  After this operation, 191 MB of additional disk space will be used.
!.
  Setting up libglx0:amd64 (1.3.2-1) ...
  Setting up libxaw7:amd64 (2:1.0.13-1.1) ...
  Setting up libgl1:amd64 (1.3.2-1) ...
  Setting up x11-xkb-utils (7.7+5) ...
  Setting up xserver-common (2:1.20.11-1+deb11u5) ...
  Setting up xserver-xorg-core (2:1.20.11-1+deb11u5) ...
  Setting up xserver-xorg-video-amdgpu (19.1.0-2) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
```

as per the instructions in [^4] let's also create a tearfree configuration

```terminal { title="Debian host" }
!!root!!host!!~!!vi /etc/X11/xorg.conf.d/20-amdgpu.conf
!.
!!root!!host!!~!!cat /etc/X11/xorg.conf.d/20-amdgpu.conf
   Section "Device"
      Identifier  "AMD Graphics"
      Driver      "amdgpu"
      Option      "TearFree"  "true"
   EndSection
   EOF
```

and reboot once you're done. Note you will likely be getting some warnings
from now on every time you update initramfs due to some firmware files for amdgpu
not being on your system, this seems to happen sometimes if the *firmware-amd-gpu* 
package does not have everything the kernel supports and in general it seems harmless.

### Intel drivers

Depending on the age of the Intel card (or CPU), you would install either the `xserver-xorg-video-intel`
(for older cards) or just the `xserver-xorg-core` package. I have not used intel cards much, if you
have one I suggest investigating at the Debian page [https://wiki.debian.org/GraphicsCard] for more
details.


### A Basic X11 environment

Regardless of NVidia or AMD, you now need to install the actual X environment, continue now 
to [the next part of the guide]({{< ref "dont-fear-part-3.md" >}})

[^1]: [https://wiki.archlinux.org/title/wpa_supplicant](https://wiki.archlinux.org/title/wpa_supplicant)

[^2]: [https://wiki.archlinux.org/title/Dhcpcd#10-wpa_supplicant](https://wiki.archlinux.org/title/Dhcpcd#10-wpa_supplicant)

[^3]: [https://manpages.debian.org/testing/ifupdown/interfaces.5.en.html](https://manpages.debian.org/testing/ifupdown/interfaces.5.en.html)

[^4]: [https://wiki.debian.org/AtiHowTo](https://wiki.debian.org/AtiHowTo)

[^5]: [https://wiki.debian.org/NvidiaGraphicsDrivers](https://wiki.debian.org/NvidiaGraphicsDrivers)
