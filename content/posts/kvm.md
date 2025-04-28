+++
type = "post"
title = "USB keyboards, xmodmap and udev"
description = ""
tags = [
    "hardware",
    "linux",
]
date = "2016-01-02T14:25:00-08:00"
categories = [
    "Hardware",
]
shorttitle = "USB and KVMs"
changelog = [ 
    "Initial release - 2016-01-01",
    "Stretch issues - 2018-06-21",
]
+++

For many years I have run a PS/2 keyboard switch between my two
computers with no issues whatsoever, however PS/2 ports can be in fairly
short supply these days, and after I last upgraded I had to move to a
USB switch to be able to connect to my computer, and use a USB converter
for my PS/2 keyboard to connect to the switch (I am typing this on an
original Microsoft Natural Keyboard, still going strong since I bought
it in 1995)

After switching from PS/2 to USB I noticed that every time I toggled the
keyboard between computers X11 would forget my xmodmap mappings,
evidently the USB switch *"switches"* by simply unplugging / replugging
the USB devices attached to it, and from an X11/computer perspective
when it's replugged it is a completely different device, and
consequently without the xmodmap mappings I had on it before it was
disconnected.

In order to fix this the first order of business is to figure out where
the keyboard is connected from a USB perspective, to do that let's first
find out which event id it's using: **ls -l /dev/input/by-id** here you
should be able to find the name of your keyboard (in my case I see
**usb-CHESEN\_PS2\_to\_USB\_Converter-event-kbd** there pointing to
*../event15*)

With this information you can run **udevadm info -q all -a -n
/dev/input/event15**, where *event15* is the input event name you just
found. The first parent device listed (the second device overall, the
first where you can see "looking at parent device") will be the actual
device that you want to use (in my case this device has an ATTRS{name}
set to **CHESEN PS2 to USB converter**)

The other information in the parent device's ATTRS are all things you
can use for your udev rule to identify the correct device that you are
plugging / unplugging, for example in my case the attributes look like

{{< highlight bnf >}}
looking at parent device '/devices/pci0000:00/0000:00:1d.0/usb8/8-1/8-1.4/8-1.4.3/8-1.4.3:1.0/0003:0A81:0205.0005/input/input19':
   KERNELS=="input19"
   SUBSYSTEMS=="input"
   DRIVERS==""
   ATTRS{name}=="CHESEN PS2 to USB Converter"
   ATTRS{phys}=="usb-0000:00:1d.0-1.4.3/input0"
   ATTRS{uniq}==""
   ATTRS{properties}=="0"
{{< / highlight >}}

and the udev rule I created looks like this (note the rule is all on one
line)

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
cat /etc/udev/rules.d/83-xmodmap.rules 
{{< /terminal-command >}}
{{< terminal-output >}}
ACTION=="add", KERNEL=="event[0-9]*", SUBSYSTEM=="input", ATTRS{name}=="CHESEN PS2 to USB Converter", ATTRS{phys}=="usb-0000:00:1d.0-1.4.3/input0", RUN+="/usr/local/bin/udev-keyboard"
{{< /terminal-output >}}
{{< /terminal >}}

After creating the udev rule **sudo udevadm control \-\-reload** needs to
be run for it to be activated.

With this, when the device you specify connects the
*/usr/local/bin/udev-keyboard* script gets invoked. 


# Debian stretch and nouveau
I am not sure why, but since reinstalling with debian stretch and running
nouveau rather than the proprietary NVidia drivers (although the latter
shouldn't make a difference really) I cannot find a way to get the udev script
to work correctly. The script is executed by udev but even with daemonize,
XAUTHORITY and so on, the xmodmap / xset lines will not persist the settings
after the script end, and the keyboard will remain unremapped.

A different approach that still works is to launch a daemon as part of
.xsession that waits for a signal triggered by udev and executes the script:
an implementation of this is described in the [following post on the Arch
linux message
board](https://bbs.archlinux.org/viewtopic.php?pid=1440918#p1440918)
which works by having a file being watched by this process, and udev
triggering the file modification.

# The original post follows
I originally had the *udev-keyboard* script above call xmodmap directly but
for some reason despite no errors being returned and the script being run
correctly, xmodmap did not seem to have any effect.

After some time I started wondering if the issue was that X11 was not
notified of the keyboard reconnecting until after the script returned as
part of the udev connection process, a way to see if this is the case
would be to detach the script and have udev continue and see what
happens.

After some trial and error the only way I was able to get xmodmap to
work reliably has been to have udev call a "daemon" script which
detaches and in turn calls the script that will actually do the xmodmap
calls.

This intermediate daemonization script can be written in any language, a
simple python implementation is available here for example [^1], it can
be put in **/usr/local/bin/udev-keyboard** to act as the daemon, with a
separate shell script called, say, **/usr/local/bin/udev-doit** that
will contain the actual xmodmap and xset calls.

This *udev-keyboard* daemonization script is simply the python daemon
base class from the site linked above, with this simple instantiation at
the end of the file containing it

```python
.......

class KBDDaemon(Daemon):
    def run(self):
        os.system('/usr/local/bin/udev-doit')   

if __name__ == "__main__":
    daemon = KBDDaemon('/tmp/kbddaemon.pid')
    daemon.start()
```

With this setup the *udev-doit* script will be executed detached from
the terminal, which seems to make it correctly interact with X11.

The script I am using follows, it has a hardcoded username since I am
only ever logging in as my user on to start X, however it could easily
be made more generic by having it look at, for example, what user the
window manager is running as.

```bash
#!/bin/sh
export XAUTHORITY=/home/luser/.Xauthority
export DISPLAY=:0

/usr/bin/xset r rate 350 35
/usr/bin/xmodmap /home/luser/.config/i3/xmodmap
sudo -u luser /usr/bin/notify-send -i info "Remapping done"
```

as you can see I am using the X11 auth token for the calls, otherwise
*xmodmap* and *xset* would not work, and sudoing to the user to send a
notification (*notify-send* does not seem to send one unless run as the
actual user).

If you are having issues getting the script to run, the first thing
would be to turn on udev debugging via **sudo udevadm control
--log-priority=debug** and test the rule with **udevadm test
--action=add /devices/pci....** where the /devices/pci/... string is
what is printed after the 'parent device' line above.

For example a successful invocation would show as something like this

{{< terminal title="andromeda" >}}
sudo udevadm test --action=add /devices/pci0000........input97/event17
{{< terminal-output >}}
..........
PHYS="usb-0000:00:1d.0-1.4.3/input0"
PRODUCT=3/a81/205/110
PROP=0
SUBSYSTEM=input
TAGS=:seat:
UNIQ=""
USEC_INITIALIZED=425640506
run: 'kmod load input:b000.......'
run: '/usr/local/bin/udev-keyboard'
unload module index
Unloaded link configuration context.
{{< /terminal-output >}}
{{< /terminal >}}

If your rule is not being run the first thing to try would probably be
to make it more and more generic by removing == qualifiers, you can also
see in the udevadm test output variables you can use to make sure the
script is going to be run when the right device is plugged in.

If the xmodmap does not seem to be taking effect, you might investigate
adding a sleep() to the script, but in that case note you might also
want to change the daemon script to remove the pidfile logic, as in our
case it doesn't really matter if multiple copies of the script are
invoked by udev (at one point for some reason udev was calling my script
twice, never been able to reproduce it after it disappeared).

As an aside, if you are looking for a lightweight notification daemon, I
can suggest dunst, as it's fairly minimalistic and fits in well with an
i3-based environment, on Debian you would install it with something like

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
sudo aptitude -t jessie-backports install dunst libnotify-bin gnome-icon-theme gnome-icon-theme-extras
{{< /terminal-command >}}
{{< /terminal >}}

in order to get the daemon as well as some common icons to use for the
notifications, which can be activated by changing the *icon\_position =
off* line to *icon\_position = left* in your dunstrc (don't forget to
also add the /usr/share/icons/gnome/... icon directories to
*icon\_folders* as well so they can be found)

[^1]: [http://www.jejik.com/articles/2007/02/a_simple_unix_linux_daemon_in_python/](http://www.jejik.com/articles/2007/02/a_simple_unix_linux_daemon_in_python/)

