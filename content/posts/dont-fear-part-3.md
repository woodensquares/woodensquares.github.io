+++
type = "post"
title = "Don't fear the command line, X11 configuration"
description = ""
tags = [
    "debian",
]
date = "2025-04-27T14:31:13-06:00"
categories = [
    "Debian",
]
shorttitle = "DFTCL 3 - X11 configuration"
changelog = [ 
    "Initial release - 2025-04-27",
]
+++

{{< toc >}}

## Basic X11 packages

At the [end of the X11 installation instructions]({{< ref
"dont-fear-part-2.md#basic-environment" >}}) you had just installed the X11 drivers, and regardless of your video card being NVidia or AMD, you now need to install the actual X environment, let's start with
something simple, a window manager and some basic applications (a terminal, a browser, some utilities, some eye candy) and let's
make sure our unprivileged user is in all the groups it needs to be to operate and there are
drivers installed for what is needed.

```terminal { title="Debian host" }
!!root!!host!!~!!apt-get install -y openbox pulseaudio xinit x11-xserver-utils dbus-x11 rxvt-unicode pavucontrol firefox-esr wmctrl avahi-daemon 
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    adwaita-icon-theme alsa-topology-conf alsa-ucm-conf at-spi2-core cpp dconf-gsettings-backend dconf-service fontconfig fonts-dejavu fonts-dejavu-extra fonts-vlgothic glib-networking glib-networking-common glib-networking-services gnome-icon-theme
    gsettings-desktop-schemas gtk-update-icon-cache hicolor-icon-theme i965-va-driver intel-media-va-driver libaom0 libasound2 libasound2-data libasound2-plugins libasyncns0 libatk-bridge2.0-0 libatk1.0-0 libatk1.0-data libatkmm-1.6-1v5 libatspi2.0-0 libavahi-client3
    libavahi-common-data libavahi-common3 libavcodec58 libavresample4 libavutil56 libcairo-gobject2 libcairo2 libcairomm-1.0-1v5 libcanberra-gtk3-0 libcanberra-gtk3-module libcanberra0 libcodec2-0.9 libcolord2 libcups2 libdatrie1 libdav1d4 libdbus-glib-1-2 libdconf1
    libevdev2 libevent-2.1-7 libflac8 libfribidi0 libgail-common libgail18 libgdk-pixbuf-2.0-0 libgdk-pixbuf-xlib-2.0-0 libgdk-pixbuf2.0-0 libgdk-pixbuf2.0-bin libgdk-pixbuf2.0-common libgif7 libglib2.0-0 libglib2.0-data libglibmm-2.4-1v5 libgraphite2-3 libgsm1
    libgtk-3-0 
!.
  Setting up libcanberra-gtk3-0:amd64 (0.30-7) ...
  Setting up libcanberra-gtk3-module:amd64 (0.30-7) ...
  Setting up firefox-esr (102.8.0esr-1~deb11u1) ...
  update-alternatives: using /usr/bin/firefox-esr to provide /usr/bin/x-www-browser (x-www-browser) in auto mode
  update-alternatives: using /usr/bin/firefox-esr to provide /usr/bin/gnome-www-browser (gnome-www-browser) in auto mode
  Setting up obconf (1:2.0.4+git20150213-2) ...
  Setting up libgtkmm-3.0-1v5:amd64 (3.24.2-2) ...
  Setting up pavucontrol (4.0-2) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
  Processing triggers for dbus (1.12.24-0+deb11u1) ...
  Processing triggers for udev (252.5-2~bpo11+1) ...
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
  Processing triggers for libgdk-pixbuf-2.0-0:amd64 (2.42.2+dfsg-1+deb11u1) ...  
!!root!!host!!~!!adduser luser pulse
  Adding user `luser' to group `pulse' ...
  Adding user luser to group pulse
  Done.
!!root!!host!!~!!adduser luser pulse-access
  Adding user `luser' to group `pulse-access' ...
  Adding user luser to group pulse-access
  Done.
!!root!!host!!~!!adduser luser audio
  The user `luser' is already a member of `audio'.
!!root!!host!!~!!su - luser
!!luser!!host!!~!!startx
```

as shown above, you should now log in as your normal user, and type **startx**, and if everything works well you should
see an X11 mouse cursor (quite large possibly, which we will fix later), by right-clicking you can show the openbox menu where
you can click on **terminal** to launch the rxvt terminal we installed earlier. If this is not working you
should try to debug the issue before continuing.

## All-in-one dependencies

Note that in various sections when compiling programs there are dependencies specified to be installed via apt-get,
it might have happened while writing the series that some were installed in different orders, so to be sure everything
compiles you should install everything at once first like so

```terminal { title="Debian host" }
!!root!!host!!~!!apt-get install -y pasystray tint2 x11-utils dunst libnotify-bin feh xss-lock i3lock imagemagick libimlib2-dev libfontconfig1-dev libfreetype6-dev libx11-dev libxext-dev libxft-dev libxrender-dev zlib1g-dev libxinerama-dev libxcomposite-dev libxdamage-dev libxfixes-dev libxmu-dev xfce4-dev-tools build-essential libglib2.0-dev xorg-dev libwnck-3-dev libclutter-1.0-dev libgarcon-1-0-dev libxfconf-0-dev libxfce4util-dev libxfce4ui-2-dev libxcomposite-dev lxterminal xdotool gawk cmake libncurses-dev lua5.4-dev stow suckless-tools neovim maim xterm libutempter-dev debhelper-compat debhelper autoconf-dickey groff xorg-docs-core desktop-file-utils stest chafa vivid autoconf automake cmake g++ gettext libncurses5-dev libtool libtool-bin libunibilium-dev libunibilium4 ninja-build pkg-config libgmock-dev software-properties-common unzip 
```

## Desktop manager

In general a text-mode login followed by running startx can help if there are issues to debug (especially
if something happens to X11) however if you prefer logging in with a graphical session manager you can
install one as follows

```terminal { title="Debian host" }
!!root!!host!!~!!apt-get install -y lightdm lightdm-gtk-greeter
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    desktop-base fonts-quicksand gnome-accessibility-themes gnome-themes-extra gnome-themes-extra-data gtk2-engines-pixbuf libayatana-ido3-0.4-0 libayatana-indicator3-7 liblightdm-gobject-1-0 libplymouth5 libxklavier16 plymouth plymouth-label
  Suggested packages:
    gnome | kde-standard | xfce4 | wmaker iso-codes accountsservice upower xserver-xephyr plymouth-themes
  The following NEW packages will be installed:
    desktop-base fonts-quicksand gnome-accessibility-themes gnome-themes-extra gnome-themes-extra-data gtk2-engines-pixbuf libayatana-ido3-0.4-0 libayatana-indicator3-7 liblightdm-gobject-1-0 libplymouth5 libxklavier16 lightdm lightdm-gtk-greeter plymouth
    plymouth-label
  0 upgraded, 15 newly installed, 0 to remove and 6 not upgraded.
!.
  I: The initramfs will attempt to resume from /dev/dm-1
  I: (/dev/mapper/dvg20230205-swap)
  I: Set the RESUME variable to override this.
!!root!!host!!~!!
```

after rebooting you should be presented with a familiar debian username/password login screen
followed by our openbox environment.

Note that lightdm will not automatically source any shell configuration files, if you want to be
able to set some environment variables for all your X applications, I found the most foolproof way to
create a **$HOME/.xsessionrc** file set to something like this (note this has to be bourne sh compatible
in general, I use it primarily only to set PATH and anything else that everything, including openbox, has
to have before starting).

```terminal { title="Debian host" }
!!luser!!host!!~!!vi ~/.xsessionrc
!.
!!luser!!host!!~!!cat ~/.xsessionrc
  insert2PATH() {
      case ":$PATH:" in
          *:"$1":*)
              # Path already in $PATH, do nothing
              ;;
          *)
              # Check if directory exists before adding
              if [ -d "$1" ]; then
                  export PATH="$1:$PATH"
              fi
              ;;
      esac
  }
  
  _available() {
      command -v "$1" >/dev/null 2>&1
  }
  
  mkdir -p $HOME/tmp
  export TMPDIR=$HOME/tmp
  export STOW_DIR=/usr/local/stow
  export GOPATH=$HOME/go
  
  insert2PATH "/sbin"
  insert2PATH "/bin"
  insert2PATH "/usr/sbin"
  insert2PATH "/usr/bin"
  insert2PATH "/usr/local/sbin"
  insert2PATH "/usr/local/bin"
  insert2PATH "/usr/local/sbin"
  insert2PATH "$HOME/.cargo/bin"
  insert2PATH "$HOME/go/bin"
  insert2PATH "$HOME/.local/bin"
  insert2PATH "$HOME/custom/bin"
```

in general this should be in **$HOME/.xprofile** however in debian it seems one has to use **$HOME/.xsessionrc** as per
[https://wiki.debian.org/Xsession].

Configuring lightdm is beyond the scope of this series, however a lot of information about it,
like many other things, is available at the Arch Wiki at [^1] the one thing I will mention here
is setting up XDMCP which makes it really easy to open an X session on the machine from any
other X11 machine on your network. To do so simply add

```text
[XDMCPServer]
enabled=true
port=177
```

then from an external machine you can do something like **Xnest -query <your host ip> -geometry 1024x768 :1** 
or **Xephyr -query yourhostname.localdomain -screen 1024x768 :1** to get an X11 session going. 
Note this protocol is not encrypted, so if you require more security in your local network you should 
probably use VNC (which LightDM supports natively) or X2GO or some other technology. 
In my environment Xnest doesn't seem to get repainting events (so switching desktops 
on the client will cause the Xnest window to become useless) but Xephyr seems to work for me.

## Startup without using a desktop manager

If you prefer to login in text mode and type `startx` every time, you can take over the startup by
creating a file named `.xsession` in your home directory, containing something like

```bash
#!/usr/bin/env bash

# If you need to do something specific in your environment with xrandr say
# xrandr --output DP-3 --off

# Avoid endlessly accumulating, keep the last one just in case
cp $HOME/.xsession-errors $HOME/.xsession-errors.last
: > $HOME/.xsession-errors

echo ----------------------------------------
echo user X session started on $(date)
echo ----------------------------------------

exec /usr/bin/openbox-session
exit 0
```

which will start up Openbox as in the case above, with the openbox startup files.

## Audio in X11

To quickly verify audio works correctly, you can just open the installed Firefox LTS and browse
to YouTube. It is quite likely you will have to launch `pavucontrol` to correctly mute/unmute
whatever audio device you are using and/or to change its default volume.

Normally pulseaudio is configured so that any change you make will be reapplied on reboot, configuring
pulseaudio can be a complex process so if something is not working correctly your best bet is to
follow the excellent Arch Wiki as usual at [https://wiki.archlinux.org/title/PulseAudio]

## X11 Large cursor

By default, depending on your screen resolution, the mouse cursor could be quite large, this can 
be easily fixed by creating the following file in your home directory

```terminal { title="Debian host" }
!!luser!!host!!~!!vi ~/.Xresources
!.
!!luser!!host!!~!!cat ~/.Xresources
  !Xcursor.theme: cursor-theme
  Xcursor.size: 16
```

## X11 startup programs

Openbox can start applications/processes when you log in, this is controlled by the 
`~/.config/openbox/autostart` file, here is a recommended setup which I will go through in the
individual subsections. Note besides this file, any desktop file in `/etc/xdg/autostart` will also
be run automatically as part of the startup procedure, so if there is something that you are
unsure how it got started, that is also a good place to look.

Note most of the invocation lines below will have a conditional check, this is so that you can copy this
file before having installed the relevant helper programs without getting errors.

{{< highlight bash >}}
# This should already be automatically done, however just in case
[ -f $HOME/.Xresources ] && /usr/bin/xrdb -merge $HOME/.Xresources

#  Panel
[ -x /usr/bin/tint2 ] && /usr/bin/tint2 &

# Desktop geometry; make our desktops 3x3 and move to the central one
# note for this to work correctly you also very likely need to configure
# openbox's desktops in $HOME/.config/openbox/rc.xml
# https://superuser.com/questions/347528/openbox-make-4-desktops-2x2
# https://specifications.freedesktop.org/wm-spec/wm-spec-1.3.html#idm46435610117776
# https://askubuntu.com/questions/41093/is-there-a-command-to-go-a-specific-workspace
[ -x /usr/bin/xprop ] && xprop -root -f _NET_NUMBER_OF_DESKTOPS 32c -set _NET_NUMBER_OF_DESKTOPS 9
[ -x /usr/bin/xprop ] && xprop -root -f _NET_DESKTOP_LAYOUT 32cccc -set _NET_DESKTOP_LAYOUT 0,3,3,0
sleep 0.5
[ -x /usr/bin/wmctrl ] && wmctrl -s 4

# Notifications
[ -x /usr/bin/dunst ] && /usr/bin/dunst $HOME/.config/dunst/dunstrc &

# Desktop backgrounds
pkill fehbgdaemon
[ -x /usr/bin/feh -a -x $HOME/.local/bin/fehbgdaemon ] && $HOME/.local/bin/fehbgdaemon &

# Monitoring
[ -x /usr/local/bin/conky ] && /usr/local/bin/conky -d &

# Locking
[ -x /usr/bin/xss-lock -a -x $HOME/.local/bin/fuzzylock ] && xss-lock $HOME/.local/bin/fuzzylock &

# If you want, say, moving the mouse to the bottom right corner to lock the screen, you would uncomment the following
# [ -x /usr/bin/xdotool -a -x $HOME/.local/bin/fuzzylock ] && xdotool behave_screen_edge --delay 1000 bottom-right exec $HOME/.local/bin/fuzzylock &
{{< / highlight >}}

### Panel

I typically run a very simple top panel with left/to/right a couple of programs, the desktops,
with window titles, the systray and date/time. This requires `tint2`, for the panel, and `pasystray`
for the systray

```terminal { title="Debian host" }
!!luser!!host!!~!!sudo apt-get install -y pasystray tint2
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    libavahi-glib1 libayatana-appindicator3-1 libdbusmenu-glib4 libdbusmenu-gtk3-4 libnotify4 notification-daemon
  Suggested packages:
    paman paprefs pavumeter pulseaudio-module-zeroconf
  The following NEW packages will be installed:
    libavahi-glib1 libayatana-appindicator3-1 libdbusmenu-glib4 libdbusmenu-gtk3-4 libnotify4 notification-daemon pasystray tint2
  0 upgraded, 7 newly installed, 0 to remove and 6 not upgraded.
  Need to get 365 kB of archives.
!.
  Setting up pasystray (0.7.1-1) ...
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
  Processing triggers for hicolor-icon-theme (0.17-2) ...
!!luser!!host!!~!!
```

tint2 can be configured via the `.config/tint2/tint2rc` file, there are many themes available, I have
included mine here [link to the source file](/code/dontfear/tint2rc.txt), note the tint2 configuration
application that was installed (accessible from the included theme top left) which will make it very easy
to add/remove applications to the launcher and/or to adjust colors to your liking. In general you can also
run **tint2conf** and edit the configuration manually.

### Desktop geometry

I find it more straightforward, and that it makes for easier keybindings, to have desktops arranged in a 
3x3 grid, as opposed to a straight left-to-right line, these commands set things up as described. The **sleep 0.5**
line should not strictly be necessary however I found it helps with making sure the session does start
on the central desktop reliably.

For the 1x9 -> 3x3 geometry change to work **xprop** needs to be available so install it via

```terminal { title="Debian host" }
!!luser!!host!!~!!sudo apt-get install -y x11-utils 
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    libxcb-shape0 libxv1 libxxf86dga1
  Suggested packages:
    mesa-utils
  The following NEW packages will be installed:
    libxcb-shape0 libxv1 libxxf86dga1 x11-utils
!.
  Setting up pasystray (0.7.1-1) ...
  Setting up x11-utils (7.7+5) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
!!luser!!host!!~!!
```

### Notifications

It's useful to have notification support, **dunst** is a very lightweight solution for that
and you can test notifications using **notify-send** which is part of **libnotify-bin**

```terminal { title="Debian host" }
!!luser!!host!!~!!sudo apt-get install -y dunst libnotify-bin
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    libauthen-sasl-perl 
!.
  Setting up libwww-perl (6.52-1) ...
  Setting up libxml-parser-perl:amd64 (2.46-2) ...
  Setting up libxml-twig-perl (1:3.52-1) ...
  Setting up libnet-dbus-perl (1.2.0-1+b1) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
!!luser!!host!!~!!mkdir -p $HOME/.config/dunst/dunstrc
!!luser!!host!!~!!vi $HOME/.config/dunst/dunstrc
```

with a simple configuration like this, see the **dunst** manpage for more information
on all the options

**$HOME/.config/dunst/dunstrc**
{{< highlight toml >}}
[global]
    monitor = 0
    follow = none
    width = 300
    height = 300
    origin = top-right
    offset = 10x50
    scale = 0
    notification_limit = 0
    progress_bar = true
    progress_bar_height = 10
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300
    indicate_hidden = yes
    transparency = 0
    separator_height = 2
    padding = 8
    horizontal_padding = 8
    text_icon_padding = 0
    frame_width = 3
    separator_color = frame
    sort = yes
    font = Monospace 8
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    vertical_alignment = center
    show_age_threshold = 60
    ellipsize = middle
    ignore_newline = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators = yes
    icon_position = left
    min_icon_size = 0
    max_icon_size = 32
    icon_path = /usr/share/icons/Adwaita/16x16/status/:/usr/share/icons/Adwaita/16x16/devices/
    sticky_history = yes
    history_length = 20
    dmenu = /usr/bin/dmenu -p dunst:
    browser = /usr/bin/xdg-open
    always_run_script = true
    title = Dunst
    class = Dunst
    corner_radius = 0
    ignore_dbusclose = false
    force_xwayland = false
    force_xinerama = false
    mouse_left_click = close_current
    mouse_middle_click = do_action, close_current
    mouse_right_click = close_all

[experimental]
    per_monitor_dpi = false

[urgency_low]
    timeout = 10

[urgency_normal]
    timeout = 10

[urgency_critical]
    timeout = 0
{{</ highlight >}}


### Desktop backgrounds

If you want to have backgrounds, I find **feh** to be a very good way of setting them

```terminal { title="Debian host" }
!!luser!!host!!~!!sudo apt-get install -y feh
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    libexif12 libjpeg-turbo-progs libturbojpeg0 yudit-common
!.
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
  Processing triggers for hicolor-icon-theme (0.17-2) ....
!!luser!!host!!~!!
```

I use two scripts for this, one is the one referenced above in autostart, which will set a different 
background on each virtual desktop by listening to events via xprop (there will be a slight
delay due to this before the background changes).

**$HOME/.local/bin/fehbgdaemon**
{{< highlight bash >}}
#!/usr/bin/bash
# From https://forums.bunsenlabs.org/viewtopic.php?id=657 with changes to randomize
# the picture every time from the wallpapers directory
WALLS_FILE="$HOME/.config/wallpapers.cfg"
FEH_CMD="feh --no-xinerama --bg-fill"
WPDIR="$HOME/Pictures/wallpapers/wallpapers"
files=( "$WPDIR/"* )
# From http://stackoverflow.com/questions/701505/

rm -f "${WALLS_FILE}"
NUM_DESKTOPS=$(xprop -root _NET_NUMBER_OF_DESKTOPS | tail -c -2)
for (( i=0; i < $NUM_DESKTOPS; i++ ));do
    WP="${files[RANDOM % ${#files[@]}]}"
    echo "[DESKTOP_$i] $FEH_CMD $WP" >> "$WALLS_FILE"
done

xprop -root -spy _NET_CURRENT_DESKTOP | (
while read -r;do
    CURR_DESKTOP=${REPLY:${#REPLY}-1:1}
    while read DTOP CMD;do
        VAL="[DESKTOP_$CURR_DESKTOP]"
        if [[ "$DTOP" = "$VAL" ]];then
            eval $CMD
        fi
    done < "$WALLS_FILE"
done
)
{{< /highlight >}}

and the other instead is a one-shot that supports multiple monitors but no
per-virtual desktop background (or therefore any running process).

**$HOME/.local/bin/fehbg**
{{< highlight bash >}}
#!/bin/bash
WPDIR="$HOME/Pictures/wallpapers/"
files=( "$WPDIR/"* )

# From http://stackoverflow.com/questions/701505/
THIRD="${files[RANDOM % ${#files[@]}]}"

feh --no-xinerama --bg-fill "$THIRD"
exit 0

# If you have multiple screens, the below is a way to have a different
# wallpaper on each, adapt as needed. The below example is for 4 screens
# and requires also imagemagick to be installed (for the convert executable)
######################################################################
# Adapted from http://ubuntuforums.org/archive/index.pho/t-964558.html

AX=1920
AY=1200
BX=1680
BY=1050
CX=2560
CY=1440
DX=1920
DY=1080

TEMP_DIR=/run/user/$(id -u)
ATEMP=$TEMP_DIR/dualbackgroundA.$$.$RANDOM
BTEMP=$TEMP_DIR/dualbackgroundB.$$.$RANDOM
CTEMP=$TEMP_DIR/dualbackgroundC.$$.$RANDOM
DTEMP=$TEMP_DIR/dualbackgroundD.$$.$RANDOM

files=( "$WPDIR/"* )

# From http://stackoverflow.com/questions/701505/
FIRST="${files[RANDOM % ${#files[@]}]}"
SECOND="${files[RANDOM % ${#files[@]}]}"
THIRD="${files[RANDOM % ${#files[@]}]}"
FOURTH="${files[RANDOM % ${#files[@]}]}"

# Resize images and store in temp directory
convert "$FIRST" \
-resize x${AY} -resize "${AX}x<" \
-gravity center -crop ${AX}x${AY}+0+0 +repage "$ATEMP"

convert "$SECOND" \
-resize x${BY} -resize "${BX}x<" \
-gravity center -crop ${BX}x${BY}+0+0 +repage "$BTEMP"

convert "$THIRD" \
-resize x${CY} -resize "${CX}x<" \
-gravity center -crop ${CX}x${CY}+0+0 +repage "$CTEMP"

convert "$FOURTH" \
-resize x${DY} -resize "${DX}x<" \
-gravity center -crop ${DX}x${DY}+0+0 +repage "$DTEMP"

# Join images to output file
montage "$ATEMP" "$BTEMP" "$CTEMP" "$DTEMP" -mode Concatenate -tile x1 -gravity north "$TEMP_DIR/final.jpg"

# And have feh display them
feh --no-xinerama --bg-center "$TEMP_DIR/final.jpg"

# Remove temporary files from tmpfs and move the final result to /tmp
rm "$ATEMP"
rm "$BTEMP"
rm "$CTEMP"
rm "$DTEMP"
cp "$TEMP_DIR/final.jpg" /tmp/
rm "$TEMP_DIR/final.jpg"
{{< /highlight  >}}

### Monitoring

I like having at a glance information on the system fans, temperatures and so on, and I find
**conky** to be a very good flexible way of displaying them. Configuring conky can be complex
and there are a number of ready made themes, I am including my current configuration but
feel free to change it or use something else.

Conky has a fairly old package in apt, so I prefer to compile it from scratch, to find the
build dependencies you can simply run **apt-rdepends --build-depends --follow=DEPENDS conky**
(you will have to install apt-rdepends). Theoretically you should be able to install them via
**apt-get build-dep conky** but unfortunately for me that does not work due to some version
mismatches. Also note in general that might add dependencies that are not strictly needed
for the upstream package (say nvidia-settings, if you don't have an nvidia card) so you might 
want to massage the list before installing it, the below works for me.

```terminal { title="Debian host" }
!!luser!!host!!~!!cd ~/sources
!!luser!!host!!~/sources!!git clone https://github.com/brndnmtthws/conky
  Cloning into 'conky'...
  remote: Enumerating objects: 27131, done.
  remote: Counting objects: 100% (69/69), done.
  remote: Compressing objects: 100% (35/35), done.
  remote: Total 27131 (delta 49), reused 46 (delta 34), pack-reused 27062
  Receiving objects: 100% (27131/27131), 19.63 MiB | 34.41 MiB/s, done.
  Resolving deltas: 100% (18599/18599), done.
!!luser!!host!!~/sources!!cd conky
!!luser!!host!!~/sources/conky!!git checkout v1.19.1
  Note: switching to 'v1.19.1'.
  
  You are in 'detached HEAD' state. You can look around, make experimental
  changes and commit them, and you can discard any commits you make in this
  state without impacting any branches by switching back to a branch.
  
  If you want to create a new branch to retain commits you create, you may
  do so (now or later) by using -c with the switch command. Example:
  
    git switch -c <new-branch-name>
  
  Or undo this operation with:
  
    git switch -
  
  Turn off this advice by setting config variable advice.detachedHead to false
  
  HEAD is now at 4b4fb7aa build(deps-dev): bump cypress from 12.8.1 to 12.9.0 in /web
!!luser!!host!!~/sources/conky!!sudo apt-get install -y cmake g++ libimlib2-dev libncurses5-dev libx11-dev libxdamage-dev libxft-dev libxinerama-dev libxml2-dev libxext-dev libcurl4-openssl-dev liblua5.3-dev cmake libncurses-dev lua5.4-dev
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    autoconf automake
!.
  Setting up libimlib2-dev (1.7.1-2) ...
  Setting up libxinerama-dev:amd64 (2:1.1.4-2) ...
  Setting up libxft-dev:amd64 (2.3.2-2) ...
  Setting up libfontconfig1-dev:amd64 (2.13.1-4.2) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
!!luser!!host!!~/sources/conky!!mkdir build
!!luser!!host!!~/sources/conky!!cd build
!!luser!!host!!~/sources/conky/build!!cmake -DCMAKE_INSTALL_PREFIX=/usr/local/stow/conky-1.19.1 ..
  -- The C compiler identification is GNU 10.2.1
  -- The CXX compiler identification is GNU 10.2.1
  -- Detecting C compiler ABI info
!.
  -- Configuring done
  -- Generating done
  -- Build files have been written to: /home/luser/sources/conky/cmake
!!luser!!host!!~/sources/conky/build!!make -j16
  [  1%] Building C object 3rdparty/toluapp/CMakeFiles/toluapp_lib_static.dir/src/lib/tolua_event.c.o
  [  2%] Building C object 3rdparty/toluapp/CMakeFiles/toluapp_lib_static.dir/src/lib/tolua_is.c.o
  [  3%] Building C object 3rdparty/toluapp/CMakeFiles/toluapp_lib_static.dir/src/lib/tolua_map.c.o
  [  5%] Building C object 3rdparty/toluapp/CMakeFiles/toluapp_lib_static.dir/src/lib/tolua_push.c.o
  [  6%] Building C object 3rdparty/toluapp/CMakeFiles/toluapp_lib_static.dir/src/lib/tolua_to.c.o
  [  7%] Linking C static library libtoluapp.a
  [  7%] Built target toluapp_lib_static
  [  8%] Building C object 3rdparty/toluapp/CMakeFiles/toluapp.dir/src/bin/tolua.c.o
  [ 10%] Building C object 3rdparty/toluapp/CMakeFiles/toluapp.dir/src/bin/toluabind.c.o
!.
  [ 98%] Building CXX object src/CMakeFiles/conky.dir/nc.cc.o
  [100%] Linking CXX executable conky
  [100%] Built target conky
!!luser!!host!!~/sources/conky/build!!make install
  [  7%] Built target toluapp_lib_static
  [ 11%] Built target toluapp
  [ 13%] Built target tcp-portmon
  [ 16%] Built target generated_hdr_files
  [100%] Built target conky
  Install the project...
  -- Install configuration: "RelWithDebInfo"
  -- Installing: /usr/local/stow/conky-1.19.1/share/applications/conky.desktop
  -- Installing: /usr/local/stow/conky-1.19.1/share/icons/hicolor/scalable/apps/conky-logomark-violet.svg
  -- Installing: /usr/local/stow/conky-1.19.1/bin/conky
  -- Installing: /usr/local/stow/conky-1.19.1/lib/libtcp-portmon.a
  -- Installing: /usr/local/stow/conky-1.19.1/share/doc/conky-1.19.1_pre/convert.lua
  -- Installing: /usr/local/stow/conky-1.19.1/share/doc/conky-1.19.1_pre/conky_no_x11.conf
  -- Installing: /usr/local/stow/conky-1.19.1/share/doc/conky-1.19.1_pre/conky.conf
!!luser!!host!!~/sources/conky/build!!sudo stow -d /usr/local/stow conky-1.19.1  
!!luser!!host!!~/sources/conky/build!!mkdir -p ~/.config/conky
!!luser!!host!!~/sources/conky/build!!vi ~/.config/conky/conky_scripts.lua
!.  
!!luser!!host!!~/sources/conky/build!!vi ~/.config/conky/conky.conf
!.  
```

my conky configuration follows, for an 8 core Ryzen AMD processor with onboard AMD video 

**$HOME/.config/conky/conky_scripts.lua**
{{< highlight lua >}}
function conky_pad4( number )
    return string.format( '%4i' , conky_parse( number ) )
end
function conky_pad3( number )
    return string.format( '%3i' , conky_parse( number ) )
end
function conky_pads7( st )
    return string.format( '%7s' , conky_parse(st) )
end
function conky_padnet( number )
    -- return string.format( '%03.2f MBps' , conky_parse( number ) / 1000.0 )
    return string.format( '%06.2f MBps' , conky_parse( number ) / 1000.0 )
end
{{< /highlight  >}}

**$HOME/.config/conky/conky.conf**
{{< highlight lua >}}
conky.config = {
    alignment = 'bottom_middle',
    background = true,
    border_width = 2,
    border_inner_margin = 2,
    cpu_avg_samples = 2,
    diskio_avg_samples = 2,
    net_avg_samples = 2,
    music_player_interval = 1.0,
    default_color = 'white',
    default_outline_color = 'white',
    default_shade_color = 'black',
    double_buffer = true,
    draw_borders = false,
    draw_graph_borders = true,
    draw_outline = false,
    draw_shades = false,
    use_xft = true,
    xftalpha = 1,
    font = 'JetBrains Mono:pixelsize=15',
    override_utf8_locale = true,
    gap_x = 0,
    gap_y = 0,
    lua_load = "~/.config/conky/conky_scripts.lua",

    no_buffers = true,
    out_to_console = false,
    out_to_ncurses = false,
    out_to_stderr = false,
    out_to_x = true,
    extra_newline = false,
    own_window = true,
    own_window_colour = '444444',
    own_window_type = 'normal',
    own_window_argb_visual = true,
    own_window_argb_value = 150,
    own_window_class = 'Conky',
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    own_window_transparent = false,
    double_buffer = true,

    stippled_borders = 0,
    update_interval = 1.0,
    uppercase = false,
    use_spacer = 'left',
    use_spacer = 'right',
    pad_percents = 2,
    show_graph_scale = false,
    show_graph_range = false,
}

conky.text = "|| " ..
             "$kernel || " ..
             "RAM: ${lua pad3 $memperc}%, ${lua pads7 ${memfree}} || " ..
             "CPU: ${cpu cpu0}% ${cpugraph 12,50,-l} " ..
             "${hwmon 3 temp 2}C " ..
             "${lua pad4 ${hwmon 6 fan 1}} rpm " ..
             "CSET: ${hwmon 3 temp 1}C " ..
             "MOBO: ${hwmon 3 temp 3}C " ..
             "${cpubar cpu1 12,4}" ..
             "${cpubar cpu2 12,4}" ..
             "${cpubar cpu3 12,4}" ..
             "${cpubar cpu4 12,4}" ..
             "${cpubar cpu5 12,4}" ..
             "${cpubar cpu6 12,4}" ..
             "${cpubar cpu7 12,4}" ..
             "${cpubar cpu8 12,4}" ..
             "${cpubar cpu9 12,4}" ..
             "${cpubar cpu10 12,4}" ..
             "${cpubar cpu11 12,4}" ..
             "${cpubar cpu12 12,4}" ..
             "${cpubar cpu13 12,4}" ..
             "${cpubar cpu14 12,4}" ..
             "${cpubar cpu15 12,4}" ..
             "${cpubar cpu16 12,4}" ..
             " ${freq_g  1}" ..
             " ${freq_g  3}" ..
             " ${freq_g  4}" ..
             " ${freq_g  6}" ..
             " ${freq_g  7}" ..
             " ${freq_g  9}" ..
             " ${freq_g 10}" ..
             " ${freq_g 12}" ..
             " ${freq_g 13}" ..
             " ${freq_g 15}" ..
             " ${freq_g 16} || " ..
             "D: ${lua padnet ${downspeedf enp6s0}} ${downspeedgraph enp6s0 14,50 ADFF2F 32CD32 -t} || " ..
             "U: ${lua padnet ${upspeedf enp6s0}} ${upspeedgraph enp6s0 14,50 FFAD2F 32CD32 -t} || " ..
             "TOP ${lua pad4 ${hwmon 6 fan 2}} rpm VRM ${lua pad4 ${hwmon 3 fan 1}} rpm || " ..
             "root: ${fs_free /} || " ..
             "TD: ${totaldown enp6s0} TU: ${totalup enp6s0} || " ..
             ""
{{< /highlight  >}}

You will for sure have to change any of the hwmon lines, and the WIFI interface name as well. If, say, 
you had a separate nvidia card you could have a line for it as follows (all on one line)

{{< highlight lua >}}
"${execi 2 nvidia-smi --query-gpu=temperature.gpu,fan.speed,power.draw,memory.used,clocks.sm 
--format=csv,noheader | awk -F ',' '{printf \"GPU: %3dC Fan:%3d%% %3dW %5dMiB %4dMhz\", 
$1, $2, $3, $4, $5, $6}'} || " ..
{{< /highlight  >}}

in order to find which sensors are available I recommend installing the packages **inxi** and **lm-sensors**
and then run something like **inxi -F** (also don't forget to run **sudo sensors-detect** first and follow
the prompts to load the relevant kernel modules) as well as **sensors**.

After installing sensors you could for example do something like this (note this is on a dell laptop)

```terminal { title="Debian host" }
!!root!!host!!~!!sensors
  acpitz-acpi-0
  Adapter: ACPI interface
  temp1:        +25.0°C  
  
  dell_smm-isa-0000
  Adapter: ISA adapter
  Processor Fan:    0 RPM  (min =    0 RPM, max = 4900 RPM)
  CPU:            +40.0°C  
  Ambient:        +21.0°C  
  SODIMM:         +25.0°C  
  
  coretemp-isa-0000
  Adapter: ISA adapter
  Package id 0:  +41.0°C  (high = +86.0°C, crit = +100.0°C)
  Core 0:        +40.0°C  (high = +86.0°C, crit = +100.0°C)
  Core 1:        +38.0°C  (high = +86.0°C, crit = +100.0°C)
!!root!!host!!~!!find /sys/devices -type f -name "temp*_input" -o -name "fan*_input" | xargs -I{} sh -c 'echo "{}: $(cat {})"'
  /sys/devices/platform/coretemp.0/hwmon/hwmon1/temp3_input: 43000
  /sys/devices/platform/coretemp.0/hwmon/hwmon1/temp1_input: 42000
  /sys/devices/platform/coretemp.0/hwmon/hwmon1/temp2_input: 40000
  /sys/devices/platform/dell_smm_hwmon/hwmon/hwmon3/temp3_input: 25000
  /sys/devices/platform/dell_smm_hwmon/hwmon/hwmon3/fan1_input: 0
  /sys/devices/platform/dell_smm_hwmon/hwmon/hwmon3/temp1_input: 40000
  /sys/devices/platform/dell_smm_hwmon/hwmon/hwmon3/temp2_input: 21000
  /sys/devices/virtual/thermal/thermal_zone0/hwmon0/temp1_input: 25000
!!root!!host!!~!!for i in /sys/class/hwmon/hwmon*/name; do echo "$i: $(cat $i)"; done
  /sys/class/hwmon/hwmon0/name: acpitz
  /sys/class/hwmon/hwmon1/name: coretemp
  /sys/class/hwmon/hwmon2/name: AC
  /sys/class/hwmon/hwmon3/name: dell_smm
```

and by looking at the numbers you can see that for conky's CPU temperature, for example,
you would have to use hwmon 3 (which is dell_sm) temperature 1 (40000 / +40C)

### An easy way to launch programs

Although you could modify further your tint2 bar to add more icons, I find it easier to have a super+space
shortcut to launch [dmenu](http://git.suckless.org/dmenu/), which you can install via **sudo apt-get install -y
suckless-tools stest** and the following script which allow some memory of your most launched programs

**$HOME/.local/bin/hdmenu**
{{< highlight bash >}}
#!/usr/bin/bash
if [ -f $HOME/.config/dmenu/dmenurc ]; then
    source $HOME/.config/dmenu/dmenurc
else
    DMENU=(dmenu -fn 'DejaVu Sans Mono 10' -m 1)
fi

cachedir=${XDG_CACHE_HOME:-"$HOME/.cache"}
mostused=$cachedir/dmenu_cache_recent
cache=$cachedir/dmenu_cache

IFS=:
if stest -dqr -n "$cache" $PATH; then
    stest -flx $PATH | sort -u > "$cache"
fi
unset IFS

touch $mostused
mostused_data=$(sort $mostused | uniq -c | sort -nr | colrm 1 8)
run=$((echo "$mostused_data"; cat $cache | grep -vxF "$mostused_data") | "${DMENU[@]}" $@) \
    && (echo "$run"; head -n 199 "$mostused") > $mostused.$$ \
    && mv $mostused.$$ $mostused

$run &
{{< /highlight  >}}

dmenu's colors and font can be configured in its configuration file

**$HOME/.config/dmenu/dmenurc**
{{< highlight bash >}}
DMENU=(dmenu -fn 'Droid Sans Mono-14' -b -nb "#151617" -nf '#d8d8d8' -sb '#005577' -sf '#d8d8d8')
{{< /highlight  >}}

and after this, you would bind *hdmenu* to the shortcut that works for you in openbox's rc.xml

**$HOME/.config/dmenu/dmenurc**
{{< highlight xml >}}
   <keybind key="W-space">
      <action name="Execute">
        <command>/home/youruser/.local/bin/hdmenu</command>
      </action>
    </keybind>
{{< /highlight  >}}

and from then on you can just simply super+space and type the program you want to launch

### Web browsing

Web browsers are also definitely a personal choice, although we have installed *firefox-esr* as a fallback,
I typically want to run the latest firefox manually installed, I find it best to do it manually by keeping
all firefox installs in **/usr/local/firefox/** symlinked to a particular version, and then once only run
**sudo ln -sf /usr/local/firefox/firefox /usr/local/bin/firefox**, and back-up my full profile every time 
I upgrade using the following script

**$HOME/.local/bin/fox**
{{< highlight bash >}}
#!/usr/bin/env bash
CANDIDATE=$(ls $HOME/Downloads/firefox*tar* | sort | tail -n1 | sed -e 's/.*firefox-//' | sed -e 's/\.tar.*$//')
if [[ -d /usr/local/firefox-${CANDIDATE} ]]; then
	echo Already using version ${CANDIDATE}
	exit 0
fi

if [[ -z ${CANDIDATE} || ! -f $HOME/Downloads/firefox-${CANDIDATE}.tar.xz ]]; then
	echo Cannot find a candidate tarfile for ${CANDIDATE}
	exit 1
fi

pkill -HUP firefox
sudo rm -f /usr/local/firefox
cd /usr/local
sudo tar xJf $HOME/Downloads/firefox-${CANDIDATE}.tar.xz
sudo mv firefox firefox-${CANDIDATE}
sudo ln -s firefox-${CANDIDATE} firefox
cd $HOME
tar -c -v --exclude='*morgue*' -f .mozilla-pre-${CANDIDATE} .mozilla
echo Choose the 'local' profile in case firefox changes the default
firefox --ProfileManager
exit
{{< /highlight  >}}

this script expects any new firefox to be in **$HOME/Downloads**, when want to upgrade I download it
directly via this command. I also typically **sudo mv /usr/bin/firefox /usr/bin/firefox.dist** to make
sure my newer firefox is executed.

```terminal { title="Debian host" }
!!luser!!host!!~!! curl -sLo $(curl -sfI 'https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-US' | awk '/Location:/ { gsub(/.*en-US\//,""); print }' | tr -d "\r") 'https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-US'
```

which automatically grabs the latest version and saves it with the appropriate filename. Note the first time you execute
this script you will have to create a profile, also it is helpful to create a .desktop file for the tint2 icon

**$HOME/.local/share/applications/firefox.desktop**
{{< highlight ini >}}
[Desktop Entry]
Name=Firefox
Comment=Browse the World Wide Web
GenericName=Web Browser
X-GNOME-FullName=Firefox Web Browser
Exec=/usr/local/firefox/firefox %u
Terminal=false
X-MultipleArgs=false
Type=Application
Icon=firefox-esr
Categories=Network;WebBrowser;
StartupWMClass=Firefox
StartupNotify=true
MimeType=x-scheme-handler/unknown;x-scheme-handler/about;text/html;text/xml;application/xhtml+xml;application/xml;application/vnd.mozilla.xul+xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;
{{< /highlight  >}}

### Locking

I like automatically locking the screen after a certain delay, and the screen itself becoming
a blocky / pixellated version of what is on the screen itself, in order to do this I like using
**xss-lock** with a custom script that leverages **i3lock**, **maim** and **imagemagick**

```terminal { title="Debian host" }
!!luser!!host!!~!!sudo apt-get install -y xss-lock i3lock imagemagick maim
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    libxcb-screensaver0 libev4 libxcb-image0 libxcb-xinerama0 libxcb-xkb1 libxcb-xrm0 libxkbcommon-x11-0
!.
  Setting up xss-lock (0.3.0-10+b1) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
```

the script in question

**$HOME/.local/bin/fuzzylock**
{{< highlight bash >}}
#!/bin/bash

# Running i3lock without detaching, don't lock over and over
if [ ! -f /dev/shm/locked.$USER ]; then
    maim /dev/shm/orig.$USER.png
    # Faster locking, first lock with the unprocessed image, switch it later
    i3lock -i /dev/shm/orig.$USER.png -e
    convert /dev/shm/orig.$USER.png -scale 10% -scale 1000% /dev/shm/screen_locked.$USER.png
    rm /dev/shm/orig.$USER.png
    touch /dev/shm/locked.$USER
    kill $(pgrep -u $USER i3lock)
    i3lock -i /dev/shm/screen_locked.$USER.png -e -n >& /dev/null
    rm /dev/shm/locked.$USER
fi
{{< /highlight  >}}

the **xss-lock** invocation will automatically lock the screen after the delay specified
by **xset** (check **xset q** for the default values). Additionally, via **xdotool** you can
lock the screen moving the mouse bottom right.

### Expose-like behavior

I enjoy having a button on my mouse that triggers an "expose-like" behavior, for this I have
found two options as described here

#### skippy

Skippy is a fairly straightforward program, it works having a daemon that is kept running, and
using a command that we can use to toggle it off and on. We can build it from source

```terminal { title="Debian host" }
!!luser!!host!!~!!sudo apt-get install -y libimlib2-dev libfontconfig1-dev libfreetype6-dev libx11-dev libxext-dev libxft-dev libxrender-dev zlib1g-dev libxinerama-dev libxcomposite-dev libxdamage-dev libxfixes-dev libxmu-dev
  The following additional packages will be installed:
    libice-dev libsm-dev libxmu-headers libxt-dev
!.
  Setting up libxt-dev:amd64 (1:1.2.0-1) ...
  Setting up libxmu-dev:amd64 (2:1.1.2-2+b3) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
!!luser!!host!!~!!cd ~/sources
!!luser!!host!!~/sources!!git clone https://github.com/dreamcat4/skippy-xd
!!luser!!host!!~/sources!!cd skippy-xd
!!luser!!host!!~/sources/skippy-xd!!git checkout 841e6d4
!!luser!!host!!~/sources/skippy-xd!!make
  cc -I/usr/include/uuid -I/usr/include/freetype2 -I/usr/include/libpng16 -DNDEBUG -O2 -D_FORTIFY_SOURCE=2 -std=c99 -Wall -std=c99 -Wall -I/usr/include/freetype2 -DCFG_XINERAMA -DCFG_LIBPNG -DCFG_JPEG -DCFG_GIFLIB -Wno-unused-but-set-variable -DSKIPPYXD_VERSION=\""v0.6.0~fung (2023.03.10) - \\\"\\\" Edition"\" -c src/skippy.c
  cc -I/usr/include/uuid -I/usr/include/freetype2 -I/usr/include/libpng16 -DNDEBUG -O2 -D_FORTIFY_SOURCE=2 -std=c99 -Wall -std=c99 -Wall -I/usr/include/freetype2 -DCFG_XINERAMA -DCFG_LIBPNG -DCFG_JPEG -DCFG_GIFLIB -Wno-unused-but-set-variable -DSKIPPYXD_VERSION=\""v0.6.0~fung (2023.03.10) - \\\"\\\" Edition"\" -c src/wm.c
!.
  cc -I/usr/include/uuid -I/usr/include/freetype2 -I/usr/include/libpng16 -DNDEBUG -O2 -D_FORTIFY_SOURCE=2 -std=c99 -Wall -std=c99 -Wall -I/usr/include/freetype2 -DCFG_XINERAMA -DCFG_LIBPNG -DCFG_JPEG -DCFG_GIFLIB -Wno-unused-but-set-variable -DSKIPPYXD_VERSION=\""v0.6.0~fung (2023.03.10) - \\\"\\\" Edition"\" -c src/img-gif.c
  cc -Wl,-O1 -Wl,--as-needed -o skippy-xd skippy.o wm.o dlist.o mainwin.o clientwin.o layout.o focus.o config.o tooltip.o img.o img-xlib.o img-png.o img-jpeg.o img-gif.o -ljpeg -lgif -lm -lXft -lXrender -lX11 -lXcomposite -lXdamage -lXfixes -lXext -lXinerama -lpng16 -lz
!!luser!!host!!~/sources/skippy-xd!!chmod a+x skippy-xd skippy-xd-runner
!!luser!!host!!~/sources/skippy-xd!!cp skippy-xd skippy-xd-runner ~/.local/bin
!!luser!!host!!~/sources/skippy-xd!!mkdir -p ~/.config/skippy-xd/
!!luser!!host!!~/sources/skippy-xd!!vi ~/.config/skippy-xd/skippy-xd.rc
!.
```

with for example the following config file

{{< highlight ini >}}
[general]
distance = 50
useNetWMFullscreen = true
ignoreSkipTaskbar = true
updateFreq = 60.0
lazyTrans = false
pipePath = /tmp/skippy-xd-fifo
movePointerOnStart = true
movePointerOnSelect = true
movePointerOnRaise = true
switchDesktopOnActivate = false
useNameWindowPixmap = false
forceNameWindowPixmap = false
includeFrame = true
allowUpscale = true
showAllDesktops = true
showUnmapped = false
preferredIconSize = 48
clientDisplayModes = thumbnail-icon thumbnail icon filled none
iconFillSpec = orig mid mid #00FFFF
fillSpec = orig mid mid #FFFFFF
background =

[xinerama]
showAll = true

[normal]
tint = black
tintOpacity = 0
opacity = 200

[highlight]
tint = #101020
tintOpacity = 64
opacity = 255

[tooltip]
show = true
followsMouse = true
offsetX = 20
offsetY = 20
align = left
border = #ffffff
background = #404040
opacity = 128
text = #ffffff
textShadow = black
font = fixed-11:weight=bold

[bindings]
miwMouse1 = focus
miwMouse2 = close-ewmh
miwMouse3 = iconify
keysUp = Up w
keysDown = Down s
keysLeft = Left b a
keysRight = Right Tab f d
keysExitCancelOnPress = Escape BackSpace x q
keysExitCancelOnRelease =
keysExitSelectOnPress = Return space
keysExitSelectOnRelease = Super_L Super_R Alt_L Alt_R ISO_Level3_Shift
keysReverseDirection = Tab
modifierKeyMasksReverseDirection = ShiftMask ControlMask
{{< /highlight  >}}

the line in autostart simply starts this as a daemon, we will toggle the expose-like
behavior using openbox's keybindings, where a chosen keybinding can be set to run
**skippy-xd-runner dashdash toggle-window-picker** (which you can manually try from
the terminal to see how it works).

#### xfdashboard

Another alternative is xfdashboard, which is more full featured (displaying desktop
previews, and applications on other desktops) 

Similarly to skippy, we will build this from source

```terminal { title="Debian host" }
!!luser!!host!!~!!sudo apt-get install -y libimlib2-dev libfontconfig1-dev libfreetype6-dev libx11-dev libxext-dev libxft-dev libxrender-dev zlib1g-dev libxinerama-dev libxcomposite-dev libxdamage-dev libxfixes-dev libxmu-dev xfce4-dev-tools build-essential libglib2.0-dev xorg-dev libwnck-3-dev libclutter-1.0-dev libgarcon-1-0-dev  libxfconf-0-dev libxfce4util-dev libxfce4ui-2-dev libxcomposite-dev
  The following additional packages will be installed:
    libice-dev libsm-dev libxmu-headers libxt-dev
!.
  Setting up libxt-dev:amd64 (1:1.2.0-1) ...
  Setting up libxmu-dev:amd64 (2:1.1.2-2+b3) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
!!luser!!host!!~!!cd ~/sources
!!luser!!host!!~/sources!!git clone https://github.com/gmc-holle/xfdashboard
!!luser!!host!!~/sources!!cd xfdashboard
!!luser!!host!!~/sources/xfdashboard!!git checkout 1.0.0
!!luser!!host!!~/sources/xfdashboard!!./autogen.sh --prefix /usr/local/stow/xfdashboard-1.0.0
!.
!!luser!!host!!~/sources/xfdashboard!!make -j16
!.
!!luser!!host!!~/sources/xfdashboard!!make install
!.
!!luser!!host!!~/sources/xfdashboard!!sudo stow -d $STOW_DIR xfdashboard-1.0.0
```

xfdashboard comes with several themes, which will be symlinked to **/usr/local/share/themes**,
I use the **xfdashboard-blue** theme modified as follows

```terminal { title="Debian host" }
!!luser!!host!!~/sources/xfdashboard!!cd /usr/local/share/themes
!!luser!!host!!/usr/local/share/themes!!cp -a xfdashboard-blue xfdashboard-blue-launcher
!!luser!!host!!/usr/local/share/themes!!patch -p0 < the-file-below.diff
  patching file xfdashboard.xml
!!luser!!host!!/usr/local/share/themes!!xfdashboard-settings
```

and in the settings program choose the theme, this is the file to be used
in the patch command above, the original theme is copied first to xfdashboard-blue-launcher

{{< highlight diff >}}
diff -W 270 -duw --recursive xfdashboard-blue/xfdashboard-1.0/xfdashboard.xml xfdashboard-blue-nolauncher/xfdashboard-1.0/xfdashboard.xml
--- xfdashboard-blue/xfdashboard-1.0/xfdashboard.xml	2023-05-27 17:49:56.277655747 -0500
+++ xfdashboard-blue-nolauncher/xfdashboard-1.0/xfdashboard.xml	2023-01-07 14:39:07.699971923 -0600
@@ -32,14 +32,6 @@
 				</layout>

 				<child>
-					<object class="XfdashboardQuicklaunch" id="quicklaunch">
-						<property name="can-focus">true</property>
-						<property name="orientation">vertical</property>
-						<property name="y-expand">true</property>
-					</object>
-				</child>
-
-				<child>
 					<object class="XfdashboardActor" id="middle">
 						<property name="x-expand">true</property>
 						<property name="y-expand">true</property>
{{< / highlight  >}}

this will remove the dock/quicklauncher, which I don't find useful. The
expose-like behavior can be triggered by binding a key to the **xfdashboard -t**
command, which you can try now to test things out. Having **xfdashboard -d**
invocation in the startup script could improve the switching speed depending on your video
card and environment.

## An always accessible terminal

I find it very useful to always have a terminal available with a custom keybinding, some terminals
do provide this functionality natively, however an easy way to have whatever terminal you prefer
available in such fashion is to use the [tdrop](https://github.com/noctuid/tdrop) program.

```terminal { title="Debian host" }
!!luser!!host!!~!!cd ~/sources
!!luser!!host!!~/sources!!git clone https://github.com/noctuid/tdrop
!!luser!!host!!~/sources!!cd tdrop
!!luser!!host!!~/sources/tdrop!!git checkout 0.5.0
!!luser!!host!!~/sources/tdrop!!cp tdrop ~/.local/bin
!!luser!!host!!~/sources/tdrop!!mkdir -p ~/.local/man/man1
!!luser!!host!!~/sources/tdrop!!cp tdrop.1 ~/.local/man/man1
!!luser!!host!!~/sources/tdrop!!gzip -9 ~/.local/man/man1/tdrop.1
```

which you can then bind in openbox in a second. We will be discussing terminals more later on, for now 
let's just install something fairly simple that allows easy customization and with minimal 
dependencies, **lxterminal**. Tdrop needs **xprop** (already installed above) **gawk** and **xdotool** 
to operate so let's add it.

```terminal { title="Debian host" }
!!luser!!host!!~!!sudo apt-get install -y lxterminal xdotool gawk
  Reading package lists... Done
  Building dependency tree... Done
  Reading state information... Done
  The following additional packages will be installed:
    libvte-2.91-0 libvte-2.91-common libxdo3 libsigsegv2
!.
  Processing triggers for libc-bin (2.31-13+deb11u5) ...
  Processing triggers for man-db (2.10.1-1~bpo11+1) ...
  Processing triggers for hicolor-icon-theme (0.17-2) ...
```

and now let's create a shortcut to launch this in openbox, edit the **$HOME/.config/openbox/rc.xml**
file and in the *keyboard* section add this

{{< highlight xml >}}
  <keyboard>
    <!-- ############################################################## -->
    <!-- Custom keybinds                                                -->
    <!-- ############################################################## -->
    <keybind key="W-grave">
      <action name="Execute">
        <command>tdrop -x 15% -y 15 -h 70% -w 70% lxterminal</command>
      </action>
    </keybind>
{{</ highlight >}}

you can choose whatever key you'd prefer, you can find the Openbox key names by using **xev** as described
here [http://openbox.org/wiki/Help:Bindings], also you can adjust the dimensions and position of the
window by changing the tdrop invocation, **man tdrop** for more information.

## Navigation Keybindings

For many years I used [i3](https://i3wm.org/), however since switching to a large 43" 4k monitor
I find using a tiling window manager impractical, but I did miss being able to quickly change the
layout using the keyboard so I created some shortcuts in openbox to achieve a similar result.

I have a key set as a sort of a *send an openbox command* key, super+j, and after pressing that key
I can press one of the following keys with the following behavior (I got a lot of ideas from
[this gist](https://gist.github.com/michezio/095c3a5cdf631e1de0377c9960d05fe6)). Note these
are kind of T-shaped cursor shapes on the left and right side of the keyboard.

{{< highlight bnf >}}

              Resize the current window (full height if not specified)
    -------------------------------------------------------------------------------
         u left 2/3rds            i center-ish             o right 2/3rds 
         j top left quadrant      k top middle wide        l top right quadrant
         m bottom right quadrant  , bottom middle wide     . bottom right quadrant

         s left third             d middle third           f right third
         x left half              c center 2/3rds          v right half 
    -------------------------------------------------------------------------------
    
                     Move window focus relative to the current window
    -------------------------------------------------------------------------------
                                    super+k north
                   super+m west     super+, south      super+. east
    -------------------------------------------------------------------------------
    
     
             Go to desktop                   Move current window to desktop
    -------------------------------------------------------------------------------
    super+w   super+e   super+r       super+shift+w   super+shift+e   super+shift+r    
    super+s   super+d   super+f       super+shift+s   super+shift+d   super+shift+f
    super+x   super+c   super+v       super+shift+x   super+shift+c   super+shift+v
    -------------------------------------------------------------------------------

{{< /highlight  >}}

and the following openbox bindings achieve the above, for a 4k screen (unfortunately
it does not seem to be possible to set x/y to a %, so I have to use pixels for some
things, look for 1279/1280 below to change).

{{< highlight xml >}}

    <keybind key="W-j">
      <!-- resize the current window, left side of the keyboard -->
      <keybind key="s">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>0</x><y>0</y><height>100%</height><width>33%</width>
        </action>
      </keybind>
      <keybind key="d">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>33%</x><y>0</y><height>100%</height><width>33%</width>
        </action>
      </keybind>
      <keybind key="f">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>-0</x><y>0</y><height>100%</height><width>33%</width>
        </action>
      </keybind>

      <keybind key="x">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>0</x><y>0</y><height>100%</height><width>50%</width>
        </action>
      </keybind>
      <keybind key="c">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>20%</x><y>0</y><height>100%</height><width>60%</width>
        </action>
      </keybind>
      <keybind key="v">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>-0</x><y>0</y><height>100%</height><width>50%</width>
        </action>
      </keybind>

      <!-- resize the current window, right side of the keyboard -->
      <keybind key="u">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>0</x><y>0</y><width>66%</width><height>100%</height>
        </action>
      </keybind>
      <keybind key="i">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>15%</x><y>15%</y><width>70%</width><height>80%</height>
        </action>
      </keybind>
      <keybind key="o">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>-0</x><y>0</y><width>66%</width><height>100%</height>
        </action>
      </keybind>

      <keybind key="j">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>0</x><y>0</y><width>50%</width><height>50%</height>
        </action>
      </keybind>
      <keybind key="k">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>0</x><y>0</y><width>100%</width><height>50%</height>
        </action>
      </keybind>
      <keybind key="l">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>-0</x><y>0</y><width>50%</width><height>50%</height>
        </action>
      </keybind>

      <keybind key="m">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>0</x><y>-0</y><width>50%</width><height>50%</height>
        </action>
      </keybind>
      <keybind key="comma">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>0</x><y>-0</y><width>100%</width><height>50%</height>
        </action>
      </keybind>
      <keybind key="period">
        <action name="UnmaximizeFull"/>
        <action name="MoveResizeTo">
          <x>-0</x><y>-0</y><width>50%</width><height>50%</height>
        </action>
      </keybind>

      <!-- move window focus -->
      <keybind key="W-k">
        <action name="DirectionalTargetWindow">
          <direction>north</direction>
          <finalactions>
            <action name="Focus"/>
            <action name="Raise"/>
            <action name="Unshade"/>
          </finalactions>
        </action>
      </keybind>
      <keybind key="W-m">
        <action name="DirectionalTargetWindow">
          <direction>west</direction>
          <finalactions>
            <action name="Focus"/>
            <action name="Raise"/>
            <action name="Unshade"/>
          </finalactions>
        </action>
      </keybind>
      <keybind key="W-comma">
        <action name="DirectionalTargetWindow">
          <direction>south</direction>
          <finalactions>
            <action name="Focus"/>
            <action name="Raise"/>
            <action name="Unshade"/>
          </finalactions>
        </action>
      </keybind>
      <keybind key="W-period">
        <action name="DirectionalTargetWindow">
          <direction>east</direction>
          <finalactions>
            <action name="Focus"/>
            <action name="Raise"/>
            <action name="Unshade"/>
          </finalactions>
        </action>
      </keybind>

      <!-- go to desktop -->
      <keybind key="W-w">
        <action name="GoToDesktop">
          <to>1</to>
        </action>
      </keybind>
      <keybind key="W-e">
        <action name="GoToDesktop">
          <to>2</to>
        </action>
      </keybind>
      <keybind key="W-r">
        <action name="GoToDesktop">
          <to>3</to>
        </action>
      </keybind>
      <keybind key="W-s">
        <action name="GoToDesktop">
          <to>4</to>
        </action>
      </keybind>
      <keybind key="W-d">
        <action name="GoToDesktop">
          <to>5</to>
        </action>
      </keybind>
      <keybind key="W-f">
        <action name="GoToDesktop">
          <to>6</to>
        </action>
      </keybind>
      <keybind key="W-x">
        <action name="GoToDesktop">
          <to>7</to>
        </action>
      </keybind>
      <keybind key="W-c">
        <action name="GoToDesktop">
          <to>8</to>
        </action>
      </keybind>
      <keybind key="W-v">
        <action name="GoToDesktop">
          <to>9</to>
        </action>
      </keybind>

      <!-- move window to desktop -->
      <keybind key="W-s-w">
        <action name="SendToDesktop">
          <to>1</to>
        </action>
      </keybind>
      <keybind key="W-s-e">
        <action name="SendToDesktop">
          <to>2</to>
        </action>
      </keybind>
      <keybind key="W-s-r">
        <action name="SendToDesktop">
          <to>3</to>
        </action>
      </keybind>
      <keybind key="W-s-s">
        <action name="SendToDesktop">
          <to>4</to>
        </action>
      </keybind>
      <keybind key="W-s-d">
        <action name="SendToDesktop">
          <to>5</to>
        </action>
      </keybind>
      <keybind key="W-s-f">
        <action name="SendToDesktop">
          <to>6</to>
        </action>
      </keybind>
      <keybind key="W-s-x">
        <action name="SendToDesktop">
          <to>7</to>
        </action>
      </keybind>
      <keybind key="W-s-c">
        <action name="SendToDesktop">
          <to>8</to>
        </action>
      </keybind>
      <keybind key="W-s-v">
        <action name="SendToDesktop">
          <to>9</to>
        </action>
      </keybind>
    </keybind>
{{< /highlight >}}

## What terminal to use

Terminal choice can be quite personal, there are always new terminals becoming
available, and existing terminals always improve. I personally have used and
can recommend any of [alacritty](https://github.com/alacritty/alacritty),
[kitty](https://github.com/kovidgoyal/kitty) and [wezterm](https://github.com/wez/wezterm), later on in this series we will install and
configure **kitty** however in the interest of having a standard fallback that
works well (albeit without some niceties like ligatures, or fancy
copy/paste behaviors), this section will focus on making the venerable **xterm**
look a bit more modern. As usual the Arch Wiki has really good information
on this here[^2].

XTerm will have been installed already, to configure xterm we can use the
standard X resources. My **$HOME/.Xresources** xterm section follows (note you might have already set 
this file up earlier to configure the size of the cursor), I have taken several
of these options from [this very nice article](https://aduros.com/blog/xterm-its-better-than-you-thought/)
as well.

Note this depends on the excellent **MesloLGS NF** font, which you should set up first via the 
following commands (thanks to (https://github.com/IlanCosman/tide/) which we will be installing
later as part of our fish shell setup)

```terminal { title="Debian host" }
!!luser!!host!!~!!mkdir ~/.local/share/fonts
!!luser!!host!!~!!cd ~/.local/share/fonts
!!luser!!host!!~/.local/share/fonts!!wget 'https://github.com/IlanCosman/tide/blob/assets/fonts/mesloLGS_NF_regular.ttf?raw=true'
!!luser!!host!!~/.local/share/fonts!!mv mesloLGS_NF_regular.ttf\?raw=true mesloLGS_NF_regular.ttf
!!luser!!host!!~/.local/share/fonts!!wget 'https://github.com/IlanCosman/tide/blob/assets/fonts/mesloLGS_NF_bold.ttf?raw=true'
!!luser!!host!!~/.local/share/fonts!!mv mesloLGS_NF_bold.ttf\?raw=true mesloLGS_NF_bold.ttf
!!luser!!host!!~/.local/share/fonts!!wget 'https://github.com/IlanCosman/tide/blob/assets/fonts/mesloLGS_NF_italic.ttf?raw=true'
!!luser!!host!!~/.local/share/fonts!!mv mesloLGS_NF_italic.ttf\?raw=true mesloLGS_NF_italic.ttf
!!luser!!host!!~/.local/share/fonts!!wget 'https://github.com/IlanCosman/tide/blob/assets/fonts/mesloLGS_NF_bold_italic.ttf?raw=true'
!!luser!!host!!~/.local/share/fonts!!mv mesloLGS_NF_bold_italic.ttf\?raw=true mesloLGS_NF_bold_italic.ttf
!!luser!!host!!~/.local/share/fonts!!fc-cache -fv
```

note you probably want to adjust the geometry line and font size depending on the size of your screen.

{{< highlight bnf >}}
! Behavior
XTerm.termName: xterm-256color
XTerm.vt100.backarrowKey: false
XTerm.ttyModes: erase ^?
XTerm.vt100.locale: false
XTerm.vt100.utf8: true
XTerm.vt100.scrollTtyOutput: false
XTerm.vt100.scrollKey: true
XTerm.vt100.bellIsUrgent: true
XTerm.vt100.metaSendsEscape: true
XTerm.vt100.saveLines: 65535
XTerm.vt100.visualBell: true

! Visuals
XTerm.vt100.faceName: MesloLGS NF
XTerm.vt100.boldMode: false
XTerm.vt100.faceSize: 10
XTerm.vt100.internalBorder: 16
XTerm.borderWidth: 0
XTerm.vt100.scrollBar: true
XTerm.vt100.scrollbar.width: 8
XTerm.vt100.geometry: 150x35

! Colors
XTerm.vt100.background: rgb:10/3c/48
XTerm.vt100.foreground: rgb:ad/bc/bc
XTerm.vt100.color0: rgb:18/49/56
XTerm.vt100.color1: rgb:fa/57/50
XTerm.vt100.color2: rgb:75/b9/38
XTerm.vt100.color3: rgb:db/b3/2d
XTerm.vt100.color4: rgb:46/95/f7
XTerm.vt100.color5: rgb:f2/75/be
XTerm.vt100.color6: rgb:41/c7/b9
XTerm.vt100.color7: rgb:72/89/8f
XTerm.vt100.color8: rgb:2d/5b/69
XTerm.vt100.color9: rgb:ff/66/5c
XTerm.vt100.color10: rgb:84/c7/47
XTerm.vt100.color11: rgb:eb/c1/3d
XTerm.vt100.color12: rgb:58/a3/ff
XTerm.vt100.color13: rgb:ff/84/cd
XTerm.vt100.color14: rgb:53/d6/c7
XTerm.vt100.color15: rgb:ca/d8/d9

! Bindings
XTerm.vt100.translations: #override \n\
    Super <Key>C: copy-selection(CLIPBOARD) \n\
    Super <Key>V: insert-selection(CLIPBOARD)

{{</ highlight >}}

for all the many options available just check [the XTerm man page](https://invisible-island.net/xterm/manpage/xterm.html#h2-RESOURCES)

Note that if you want a newer version of xterm it is fairly straightforward to build it,
say for example currently bookworm has a much newer xterm, which we cannot install directly
due to many updated packages, let's build our own

```terminal { title="Debian host" }
!!luser!!host!!~!!cd ~/sources
!!luser!!host!!~/sources!!mkdir debian
!!luser!!host!!~/sources!!cd debian
!!luser!!host!!~/sources/debian!!apt source xterm/trixie
  Reading package lists... Done
  Selected version '398-1' (trixie) for xterm
  NOTICE: 'xterm' packaging is maintained in the 'Git' version control system at:
  https://salsa.debian.org/xorg-team/app/xterm.git
!.
!!luser!!host!!~/sources/debian!!cd xterm-398
!!luser!!host!!~/sources/debian/xterm-398!!dpkg-buildpackage -rfakeroot -b -uc -us
!# This might complain of missing packages, in my case I had to install the following before retrying
!!luser!!host!!~/sources/debian/xterm-398!!sudo apt-get install -y libutempter-dev debhelper-compat debhelper autoconf-dickey groff xorg-docs-core desktop-file-utils
!# Once the build is complete, you can simply install via
!!luser!!host!!~/sources/debian/xterm-398!!sudo apt-get install -y ../xterm_398-1_amd64.deb
```

continue now to [the next part of the guide]({{< ref "dont-fear-part-4.md" >}})

[^1]: [https://wiki.archlinux.org/title/LightDM](https://wiki.archlinux.org/title/LightDM)

[^2]: [https://wiki.archlinux.org/title/Xterm](https://wiki.archlinux.org/title/Xterm)
