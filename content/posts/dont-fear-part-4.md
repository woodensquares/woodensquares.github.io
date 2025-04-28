+++
type = "post"
title = "Don't fear the command line, setting up the final environment"
description = ""
tags = [
    "debian",
]
date = "2025-04-27T14:31:14-06:00"
categories = [
    "Debian",
]
shorttitle = "DFTCL 4 - setting up the final environment"
changelog = [ 
    "Initial release - 2025-04-27",
]
+++

{{< toc >}}

## Prerequisites
At the [end of the Basic X11 Packages post]({{< ref
"dont-fear-part-3.md#what-terminal-to-use" >}}) we have set up a basic X11 environment, with
openbox as a window manager and some niceties like a status bar, and an easy way to launch programs
via dmenu. Let's now set up our python, rust and golang environments, since several dependencies
and command-line utilities have their latest versions easily installable via them, and install some other
useful command-line utilities.

```terminal { title="Debian host" }
!!luser!!host!!~!!sudo apt-get install -y chafa vivid
```

### Rust

For rust the easiest way to set up is to use rustup

```terminal { title="Debian host" }
!!luser!!host!!~!!cd sources
!!luser!!host!!~/sources!!curl -Slo rustup.sh https://sh.rustup.rs/
!!luser!!host!!~/sources!!chmod a+x rustup.sh
!#it is a good idea to take a look at the script before running it at this point
!!luser!!host!!~/sources!!./rustup.sh
!#and follow the prompts, the defaults should be ok
```

this should set up your cargo and rust environment, since in a previous post we already
set up **.xsessionrc** to have the rust path if present, you should at this point quit
openbox entirely and log back in, afterwards when opening a new terminal you should be able
to run **cargo version** and have it complete successfully. Periodically you would run
**rustup update** to download the latest version(s) of the rust toolchain.

While we are here, let's install some useful rust programs for later

```terminal { title="Debian host" }
!!luser!!host!!~/sources!!cargo install fd-find ripgrep eza bat viu
!.
```

### Golang

For golang you can either download it manually [from its website](https://go.dev/dl/) or you can
use a one-liner. Either way once you have the tarfile you can extract it, I typically keep it in
**/usr/local**. Given how golang's backwards compatibility works it isn't really needed to keep
older versions around. For any new version simply remove the existing **/usr/local/go** directory
and extract the new one.

```terminal { title="Debian host" }
!!luser!!host!!~!!cd sources
!!luser!!host!!~/sources!!VV=$(curl -sL 'https://go.dev/VERSION?m=text' | grep 'go') curl -Lo "$VV.tgz" "https://dl.google.com/go/$VV.linux-amd64.tar.gz"
!!luser!!host!!~/sources!!cd /usr/local
!!luser!!host!!/usr/local!!sudo rm -rf go
!!luser!!host!!/usr/local!!sudo tar xf ~/sources/go-1.24.2.tgz
!!luser!!host!!/usr/local!!sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go
!!luser!!host!!/usr/local!!sudo ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
```

similarly to rust, you should log out and log back in so the PATH and GOPATH are set correctly. Let's verify
everything is set up by installing some useful golang programs

```terminal { title="Debian host" }
!!luser!!host!!~!!go install github.com/junegunn/fzf@latest
!.
```

### Python

There are many ways to set up a python toolchain independent from the system's, which you
should always do, treat the system python as something completely out of your control you
should never depend on. Lately it seems [uv](https://github.com/astral-sh/uv) is showing
to be a very easy to use and powerful way to have your python environments, let's set it up
using cargo directly and create a venv we'll use right away for neovim.

```terminal { title="Debian host" }
!!luser!!host!!~!!cargo install --git https://github.com/astral-sh/uv uv
!#Note the last step might take a long time to finish compiling
!!luser!!host!!~!!uv python list
!.
!!luser!!host!!~!!uv python install 3.13.3
!!luser!!host!!~!!mkdir -p $HOME/.cache/virtualenvs
!!luser!!host!!~!!uv venv --python 3.13.3 ~/.cache/virtualenvs/nvim-python
!!luser!!host!!~!!uv pip install -p ~/.cache/virtualenvs/nvim-python/bin/python pynvim
!!luser!!host!!~!!uv pip install -p ~/.cache/virtualenvs/nvim-python/bin/python neovim-remote
```

### Neovim

Although an older version of neovim is packaged for debian, given its pace of development
I prefer to always compile from source.

```terminal { title="Debian host" }
!!luser!!host!!~!!cd ~/sources
!!luser!!host!!~/sources/!!source /home/luser/.cache/virtualenvs/nvim-python/bin/activate
!!luser!!host!!~/sources/!!git clone https://github.com/neovim/neovim && cd neovim
!!luser!!host!!~/sources/neovim!!git tag
!.
!!luser!!host!!~/sources/neovim!!git checkout v0.11.1
!.
!!luser!!host!!~/sources/neovim!!sudo apt-get install -y autoconf automake cmake g++ gettext libncurses5-dev libtool libtool-bin libunibilium-dev libunibilium4 ninja-build pkg-config libgmock-dev software-properties-common unzip  
!.
!!luser!!host!!~/sources/neovim!!make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=/usr/local/stow/neovim-0.11.1"
!!luser!!host!!~/sources/neovim!!make install
!!luser!!host!!~/sources/neovim!!sudo stow -d $STOW_DIR neovim-0.11.1
!!luser!!host!!~/sources/neovim!!deactivate
```

neovim should now be available, we will make

### The fish shell

Although shell preference is quite personal, especially for people just starting to really work
on the commandline and that don't have a many years old bash / zsh setup, I find fish to have a set of very
user-friendly defaults, and with some additional small plug-ins can serve very well as the foundation
of the command line usage. I do find it best, however, to not set fish as a login shell via **chsh**, I
prefer to invoke it explicitly only as a terminal configuration while leaving bash as my default shell
for added compatibility.

Although debian does provide fish, I do prefer to, once again, build from source the latest release.

```terminal { title="Debian host" }
!!luser!!host!!~!!cd ~/sources/
!!luser!!host!!~/sources/!!git clone https://github.com/fish-shell/fish-shell && cd fish-shell
!!luser!!host!!~/sources/!!git clone https://github.com/fish-shell/fish-shell && cd fish-shell
!!luser!!host!!~/sources/fish-shell!!git tag
!.
!!luser!!host!!~/sources/fish-shell/!!git checkout 4.0.2
!!luser!!host!!~/sources/fish-shell/!!mkdir build && cd build
!!luser!!host!!~/sources/fish-shell/build!!cmake .. -G "Ninja" -DCMAKE_INSTALL_PREFIX="/usr/local/stow/fish-4.0.2" -DCMAKE_EXPORT_COMPILE_COMMANDS=1
!!luser!!host!!~/sources/fish-shell/build!!cd ..
!!luser!!host!!~/sources/fish-shell/!!cmake --build build
!!luser!!host!!~/sources/fish-shell/!!make install
!!luser!!host!!~/sources/fish-shell/!!sudo stow -d $STOW_DIR fish-4.0.2
```

## The Kitty terminal

It is time now to set up the terminal and shell that we'll be using for the remainder of
this series, which will be [kitty](https://github.com/kovidgoyal/kitty).
The reason behind this choice is that in my opinion it strikes a good balance between performance and
features, it is quite mature and has great shell integration, which will be very useful for your
commandline usage.

We will build kitty from source as follows, of course feel free to choose the latest version available.
In general for kitty you have two options for source builds, you can either follow [the official instructions](https://sw.kovidgoyal.net/kitty/build/)
or try to do a normal source build by installing dependencies manually. When building from source
I prefer to have less magic, so I will try to use the system libraries as much as possible. Here is how
I was able to build it. Note, unfortunately given how *uv* seems to work, we cannot use a python built
by it for kitty, due to libpython not being available (which makes kitty not launch), so despite trying 
really hard to stay away from the system python, we have no choice here but to use it.

Unfortunately kitty also depends on a newer version of cairo than what is available in bookworm, and
rather to upgrade most/all of the system to trixie to get it to run, let's just build it and its freetype
dependency.

```terminal { title="Debian host" }
!!luser!!host!!~!!cd sources/debian
!!luser!!host!!~/sources/debian/!!sudo apt-get install -y gtk-doc-tools libfreetype-dev liblzo2-dev libpoppler-glib-dev meson python3-dev
!!luser!!host!!~/sources/debian/!!apt source libfreetype-dev/trixie
!!luser!!host!!~/sources/debian/!!cd freetype-2.13.3+dfsg/
!!luser!!host!!~/sources/debian/freetype-2.13.3+dfsg!!dpkg-buildpackage -rfakeroot -b -uc -us -d
!.
!!luser!!host!!~/sources/debian/freetype-2.13.3+dfsg!!cd ..
!!luser!!host!!~/sources/debian/!!cd ..
!!luser!!host!!~/sources/debian/!!sudo apt-get install ./libfreetype-dev_2.13.3+dfsg-1_amd64.deb ./libfreetype6_2.13.3+dfsg-1_amd64.deb
!!luser!!host!!~/sources/debian/!!apt source cairo/trixie
!.
!!luser!!host!!~/sources/debian/!!cd cairo-1.18.4
!!luser!!host!!~/sources/debian/cairo-1.18.4!!dpkg-buildpackage -rfakeroot -b -uc -us -d
!!luser!!host!!~/sources/debian/cairo-1.18.4!!cd ..
!!luser!!host!!~/sources/debian/!!sudo apt-get install ./libcairo2-dev_1.18.4-1_amd64.deb ./libcairo2_1.18.4-1_amd64.deb ./libcairo2-doc_1.18.4-1_all.deb ./libcairo-gobject2_1.18.4-1_amd64.deb ./libcairo-script-interpreter2_1.18.4-1_amd64.deb
!!luser!!host!!~/sources/debian/!!cd ..
!!luser!!host!!~/sources/debian/!!uv python install 3.11.12
!#I have had issues with later python versions for kitty, 3.11.12 seems to work fine
!!luser!!host!!~/sources/debian/!!uv venv --python 3.11.12 ~/.cache/virtualenvs/kitty-python
!!luser!!host!!~/sources/debian/!!cd ~/.cache/virtualenvs/kitty-python/lib
!#kitty seems to require these, otherwise it won't find libpython when starting
!!luser!!host!!~/.cache/virtualenvs/kitty-python/lib/!!ln -s ~/.local/share/uv/python/cpython-3.11.12-linux-x86_64-gnu/lib/libpython3.11.so.1.0
!!luser!!host!!~/.cache/virtualenvs/kitty-python/lib/!!ln -s ~/.local/share/uv/python/cpython-3.11.12-linux-x86_64-gnu/lib/libpython3.11.so
!!luser!!host!!~/.cache/virtualenvs/kitty-python/lib/!!cd ~/sources
!!luser!!host!!~/sources/!!git clone https://github.com/kovidgoyal/kitty && cd kitty
!!luser!!host!!~/sources/kitty/!!source ~/.cache/virtualenvs/kitty-python/bin/activate
!!luser!!host!!~/sources/kitty/!!git tag
!.
!!luser!!host!!~/sources/kitty/!!git checkout v0.41.1
  Note: switching to 'v0.41.1'.
!.  
  HEAD is now at f56c3edd7 version 0.41.1
!!luser!!host!!~/sources/kitty/!!sudo apt-get install -y libxxhash-dev libssl-dev libxkbcommon-x11-dev libx11-xcb-dev liblcms2-dev libfontconfig-dev libsimde-dev libcairo2-dev libdbus-1-dev libxcursor-dev libxrandr-dev libxi-dev libxinerama-dev libgl1-mesa-dev libfontconfig-dev libx11-xcb-dev
!!luser!!host!!~/sources/kitty/!!wget 'https://github.com/ryanoasis/nerd-fonts/blob/master/patched-fonts/NerdFontsSymbolsOnly/SymbolsNerdFontMono-Regular.ttf?raw=true'
!!luser!!host!!~/sources/kitty/!!mv 'SymbolsNerdFontMono-Regular.ttf?raw=true' ~/.local/share/fonts/SymbolsNerdFontMono-Regular.ttf
!!luser!!host!!~/sources/kitty/!!fc-cache -fv
!!luser!!host!!~/sources/kitty/!!make
!#the moment of truth, hopefully it compiles for you
!!luser!!host!!~/sources/kitty/!!ln -sf $HOME/sources/kitty/kitty/launcher/kitty $HOME/.local/bin/kitty
!!luser!!host!!~/sources/kitty/!!ln -sf $HOME/sources/kitty/kitty/launcher/kitten $HOME/.local/bin/kitten
```

either way if you have issues with the above, please do follow the official instructions, as the kitty
that is packaged with bookworm is fairly old (at the moment of this writing 0.26, while trixie's kitty is
0.39, and the latest available is 0.41.1).

## My dotfiles

At this point I would suggest getting [my dotfiles](https://github.com/woodensquares/dotfiles) and set them up, we will
go through in detail in future posts about their contents, which are primarily focused on
the fish shell, neovim, and their integration with kitty.

```terminal { title="Debian host" }
!!luser!!host!!~!!cd sources
!!luser!!host!!~/sources!!git clone https://github.com/woodensquares/dotfiles
!!luser!!host!!~/sources!!cd dotfiles
!!luser!!host!!~/sources/dotfiles!!./setup.sh
```

all the dependencies should have already been installed earlier, so this should hopefully complete successfully.
After this you should be able to launch kitty from dmenu and have it work correctly.



