+++
type = "post"
title = "Using i3 and Virtualbox"
description = ""
tags = [
    "i3",
    "linux",
]
date = "2016-09-05T09:52:00-08:00"
categories = [
    "Applications",
]
shorttitle = "i3 and VirtualBox"
changelog = [ 
    "Initial release - 2016-09-05",
    "Added fehbg - 2017-12-30",
]
+++

I spent many years using stacking window managers and environments, from
cde to mwm, fvwm, window maker, Gnome / KDE, and finally to Xfce.

The past little while I kept hearing a lot about tiling window managers
and since my typical desktop workspaces were pretty much always full of
maximized windows, I figured I'd give i3 a try, so last year I switched
and I haven't looked back since.

Having i3 also works very well for my virtualbox-centered setup, as I
simply have a single VirtualBox window in each i3 workspace, and it
pretty much feels like not having a VirtualBox layer at all and using
the environments in the VMs directly.

There are still a couple of rough edges that I will mention later, but
overall I am quite happy with how functional things are and what this
environment allows me to do.

<div id="vb"></div>

Starting VirtualBox
-------------------

First of all, it would be annoying having to use the VirtualBox GUI to
start VMs, also considering each VM is running with an encrypted disk,
which would mean having to type the LUKS password in them every time.

Given that if anything broke into Dom-0 it would be game over anyways
from a security standpoint, I decided to have the LUKS password for my
VMs available on the filesystem to ease the VM launching process.

I would of course not want to have it in cleartext, and since I have GPG
set up so that when logging in I unlock its agent, so I can use it to
decrypt on the fly the script that enters the password in the VM as part
of it being started.

With the setup below, there will be one command named *vb* that will
launch the VM for you and/or switch to its i3 workspace if it is already
running.

### The vb script

The *vb* script is [available here](/pages/vb.html) as you can see it is
quite simple, it will use the *i3switch* script to switch to the
workspace, or the vboxmanage command to start the vm followed by the
*vboxputmount* script to enter the password.

In order for the password to be entered in a VM, one needs to actually
type keys inside the VM, this can be easily done by using the vboxmanage
*keyboardputscancode* command, which will take the specified scancodes
and enter them in the selected VM.

To find out the scancodes to use for the password, one can either look
them up online [^1], or use the showkey program. Although in general it
should be used on a console, as opposed to under X, it seemed to work
fine for me even there (although also outputting the pressed key besides
the scancode as you can see below)

Let's get the scancodes for a string: p4\^\^+

{{< terminal title="andromeda" >}}
{{< terminal-command user="luser" host="andromeda" path="/usr/local/stow" >}}
~ sudo showkey -s
{{< /terminal-command >}}
{{< terminal-output >}}
kb mode was ?UNKNOWN?
{{< /terminal-output >}}
{{< terminal-comment >}}
if you are trying this under X, it might not work
since the X server is also reading /dev/console ]
{{< /terminal-comment >}}
{{< terminal-output >}}
press any key (program terminates 10s after last keypress)...
0x9c 
p0x19 
0x99 
a0x1e 
0x9e 
0x2a 
^0x2a 0x2a 0x2a 0x07 
0x87 
^0x07 0x87 
+0x0d 
0x8d 
0xaa 

0x1c 
0x9c 
{{< /terminal-output >}}
{{< terminal-comment >}}
you can either press ctrl-c here if under X or wait 10 
seconds. If waiting 10 seconds under X your password will
also be output to the terminal / console
{{< /terminal-comment >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
~ p4^^+
{{< /terminal-comment >}}
{{< terminal-output >}}
sh: p4^^+: command not found
{{< /terminal-output >}}
{{< /terminal >}}

The first 0x9c can be ignored, the rest of the codes are as follows:

{{< highlight bnf >}}
0x19 0x99     p
0x1e 0x9e     4
0x2a          [ left shift press, the scancode will repeat ]
0x07 0x87     shift + 6 => ^
0x07 0x87     shift + 6 => ^
0x0d 0x8d     shift + = => +
0xaa          [ left shift release ]
0x1c 0x9c     [ enter ]
{{< / highlight >}}

it is recommended to type slowly one character at a time especially
under X11 so you can see what is going on, this also means that if you
are pressing/releasing special keys, like shift, you would want to do
that on its own.

Given the above we can check if we got things right by entering our
string in a running VM, just open an editor window in it, and in your
Dom-0 run these commands

{{< terminal title="andromeda" >}}
{{< terminal-comment >}}
These two lines are equivalent, in the first one shift is pressed (2a)
before the first # and released (aa) after +
{{< /terminal-comment >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
vboxmanage controlvm [vmname] keyboardputscancode 19 99 1e 9e 2a 07 87 07 87 0d 8d aa 1c 9c
{{< /terminal-command >}}
{{< terminal-comment >}}
In this second case instead shift is pressed and released after
each shifted key
{{< /terminal-comment >}}
{{< terminal-command user="luser" host="andromeda" path="~" >}}
vboxmanage controlvm [vmname] keyboardputscancode 19 99 1e 9e 2a 07 87 aa 2a 07 87 aa 2a 0d 8d aa 1c 9c
{{< /terminal-command >}}
{{< /terminal >}}

if everything worked correctly you should see your string being output
twice inside the VM, as the sequences above should generate the same
result.

Note if your string is long, and it probably will be if you use it for
passwords, you should break it in multiple vboxmanage commands. I have
seen VirtualBox not correctly get all keys if I passed the string in one
command, I personally found in my environment that having 10-15
scancodes per keyboardputscancode invocation seemed to work well.

<div id="vboxputmount"></div>

### The vboxputmount script

To use the scancode commands as a password, I simply save them in a gpg
encrypted file and call it via a script named vboxputmount

```bash
#!/bin/bash
gpg2 -q --decrypt [somewhere]/vboxputmount.gpg | bash -s $1
```

which in turn is called by the [virtual machine start
script](/pages/vb.html) discussed above.

<div id="i3switch"></div>

### The i3switch script

The *i3switch* script is [discussed here](/pages/i3switch.html) as you
can see it does a few more things besides only switching, it is one of
the cornerstones of my environment.

In order for this script to work correctly, your i3 workspaces have to
be configured the following way. Assuming you have two monitors attached
respectively to HDMI-0 and DVI-I-3 (you can easily find out the names of
your monitors by simply running xrandr) you have to create workspaces
named [your vm name]\_left\_ and [your vm name]\_right\_ assigned
respectively to each.

In addition, there should be a rule making the VM go to the correct
workspace, as well as a scratch virtualbox workspace used only when
launching VMs.

VirtualBox VM windows when they first pop up, have title/class set to
VirtualBox instead of the VM that is started, so in order to avoid the
VM starting on your current workspace and being moved a second or two
later by i3, it will be started there first, and moved later behind the
scenes.

Note the \^/\$ as otherwise it would match other VirtualBox windows, we
only want windows called VirtualBox

All of this means your i3 configuration should contain something like
the following

{{< highlight bnf >}}
....              
workspace blog_left_             output HDMI-0
workspace web_left_              output HDMI-0
....              
workspace blog_right_            output DVI-I-3
workspace web_right_             output DVI-I-3
....                
workspace vb_ output DVI-I-3
assign [class="VirtualBox" title="^VirtualBox$"]     vb_
....              
assign [class="VirtualBox" title="^blog.*1$"]        blog_right_
assign [class="VirtualBox" title="^blog.*2$"]        blog_left_
assign [class="VirtualBox" title="blog.*VirtualBox"] blog_right_
....
assign [class="VirtualBox" title="web"]              web_right_
{{< / highlight >}}

Note that in the above case I have several assign lines for the "blog"
VM, this is because it might be launched with one screen or two screens
attached to it, which should be mapped to the physical screens that are
attached to the computer, in general this is not needed and the simpler
assignment you see for "web" is enough.

<div id="fehbg"></div>

### Backgrounds on multiple screens

The *fehbg* script [available here](/pages/fehbg.html) will set different
backgrounds in each of your physical screens even if they are one single X
screen, this is done using [feh](https://feh.finalrewind.org/) as well as
[Imagemagick](https://www.imagemagick.org/script/index.php).

<div id="i3bar"></div>

Monitoring your VMs
-------------------

If you are running with the workspace patch above, the VirtualBox
workspaces will not be visible on the i3bar paging controls, also it
would be useful to know at a glance which VMs are running and what their
resource consumption is, in order to do this I have some custom i3bar
scripts that will make my left/center/right monitor display the
following information

On the left side I have fairly typical information, a normal *1l* i3
workspace, mpd music status, available disk and current network transfer
speed, as well as outside temperature and a clock

{{< centerimg alt="An i3bar with one workspace named 1l, an mpd music title, disk sizes, network speeds, weather and date" src="/images/i3bar_left.png" >}}

On the center workspace, I have the more relevant i3bar, with the
current running VMs, their CPU usage and memory usage, if clicking on
any of the VM names the workspace with the VM in question will be
focused. Note in this case I have a normal workspace named *emacs*
followed by a *web*, *services*, *blog*, *[redacted]* and *pfSense* VMs.

Note the VM name will become white if its CPU consumption is high.

{{< centerimg alt="An i3bar with one workspace named emacs, several virtualbox vms running with the following format, vmname cpu% xxGB, and the date" src="/images/i3bar_center.png" >}}

And on the right workspace (which is another X screen, connected to a
secondary video card) I have two normal i3 workspaces named pfSense and
blog, some Dom-0 statistics, CPU, temperature, total ram consumption,
fan speeds and GPU temperatures/fan speeds.

{{< centerimg alt="An i3bar with two workspaces named pfSense and blog, CPU 04% 41C, RAM 12% MB, 958 | 753 | 660 rpm, GPU 58/57C, and date" src="/images/i3bar_right.png" >}}

For the left/right workspaces one can use any number of available i3bar
replacements, however for the center VirtualBox specific bar you would
use a block similar to the following

{{< highlight bnf >}}
bar {
    id bar-primary-right
    output DVI-I-3
    position top
    status_command ~/.config/i3/[script location]
    font pango:[your favorite font]
    ignore_workspaces_ending_with "_"
}
{{< / highlight >}}

with the i3bar status script is discussed [in this
page](/pages/i3bar.html) (note the ignore workspaces command is going to
work only if you apply to i3 the patch discussed below)

Keyboards and switching made easier
-----------------------------------

To make things easier, I have recently purchased an XKeys 16 keys stick
[^2], and programmed each key to send my VirtualBox host key (which I
have set to numlock) followed by the i3 host key plus a numpad key.

In i3 I have the corresponding mappings

{{< highlight bnf >}}
bindsym $mod+KP_End       exec --no-startup-id "~/bin/i3switch -o web"
bindsym $mod+KP_Next      exec --no-startup-id "~/bin/i3switch -o blog"
bindsym $mod+KP_Enter     exec --no-startup-id "~/bin/i3switch -e"
{{< / highlight >}}

this means that when I am focused in a VM and I press one of the XKeys
keys, it will output the VirtualBox host key (taking me out of the VM)
and then the Dom-0 i3 will execute the command assigned above. Pressing
the same VM XKeys key, will switch back & forth between that and the
last VM as well.

This, together with binding one of my side mouse buttons to the
VirtualBox host key, makes switching between VMs extremely fast whether
I am currently on the mouse (where I can simply click the VM name on my
center i3bar) or on the keyboard (where I have mounted the XKeys just
above my keyboard function keys) or where I want to move the VM to
another screen (where I can pres the mouse host key, followed by the i3
shortcut bound to i3switch -f)

Some i3 caveats
---------------

As you can see above, all these VirtualBox i3 workspaces have an ending
\_, this is because I have made a small modification to i3 to allow not
displaying workspaces ending in that character and switch to them via
some custom i3bar scripts.

I have opened an enhancement for this on github here [^3] and am using
the patch available in this gist [^4] to enable this behavior. Note that
you should not do this unless you have another way to switch to these
workspaces (like the status script above), as they will be invisible in
normal i3bar configurations.

While we're here, in case you are in my situation where you are using i3
on multiple X screens (meaning, with more than one video card), you
might benefit from my change available in this pull [^5], this has been
understandably not accepted into i3 as very very very few people will be
in this situation, so it probably is not worth the code changes for the
general code base.

With my multiple-X-screens i3 configuration, occasionally launching a VM
on a different screen or especially closing it, will "steal" the
keyboard focus (you will notice this happening if you can click buttons
etc. in a VM, but no typing is possible). If this happened in your
environment as well, it's simply a case of pressing your VirtualBox host
key and moving the mouse once across and back a screen boundary, this
will move the keyboard focus back to where it should be.

This happens infrequently enough that I haven't decided yet to spend the
time fixing it; soon I am planning to upgrade to a video card that has
more than two outputs, making the X11 event changes above unnecessary
and likely not triggering this issue anymore. In case it still did I
will of course get back in the X11 internals and hopefully figure it out
once and for all.

It is also to be noted that having the same key for your i3 key on Dom-0
and inside a VM, occasionally will not work (meaning that pressing it
will trigger the Dom-0 i3, as opposed to the VM i3). This might be
related to the keyboard issue above, or to the OS running inside your
VM. I work around it by having a different key for i3 inside the
troublesome VMs, this might or might not be necessary in your
environment.

The above minor issues are definitely not a big enough drawback, and are
likely to improve as i3 gets developed and as I will switch to a more
common X11 configuration (very few people are running multiple X screens
these days, as opposed to simple multihead / Xinerama)

Conclusion
----------

With the scripts described above and the i3 configuration mentioned, it
should be possible for you to have a set of fullscreen VirtualBox
windows, and be able to easily launch them while supporting full disk
encryption but without having to enter the password manually all the
time. Via the i3switch script it will also be possible for you to go to
the specified VM's workspace easily, and/or flip it back and forth
between your left/right monitors if needed.

### External links

[^1]: [https://www.win.tue.nl/~aeb/linux/kbd/scancodes-1.html](https://www.win.tue.nl/~aeb/linux/kbd/scancodes-1.html)

[^2]: [http://xkeys.com/xkeys/xk16.php](http://xkeys.com/xkeys/xk16.php)

[^3]: [https://github.com/i3/i3/issues/2333](https://github.com/i3/i3/issues/2333)

[^4]: [https://gist.github.com/woodensquares/c1afc4fb56b4d9d21fa261fb4b28b092](https://gist.github.com/woodensquares/c1afc4fb56b4d9d21fa261fb4b28b092)

[^5]: [https://github.com/i3/i3/pull/2331](https://github.com/i3/i3/pull/2331)

