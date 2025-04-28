+++
type = "code"
title = "kgen"
description = ""
tags = [
]
date = "2017-12-14T09:30:48-08:00"
categories = [
]
shorttitle = "kgen"
changelog = [ 
    "Initial release - 2017-12-14",
]
+++

These bash functions and python script are used to make it easier to operate
on CoreOS images and guests [as discussed here]({{< ref "xen-3.md#kgen" >}})
[and here]({{< ref "xen-4.md#kgen" >}})

# kgen

[link to the source file](/code/kgen.txt)

```bash
function kgen () {
    local action=$1
    local node=$2
    local base
    local pwd

    pwd=$(pwd)
    base=$(basename "$pwd")

    if [[ -z $XENDIR ]]; then
        echo XENDIR must be set
        return 1
    fi

    if [[ -z $2 ]]; then
        echo A node must be passed
        return 1
    fi

    if [[ "$pwd" != "$XENDIR/guests/$base" ]]; then
        echo You should be in a guests subdirectory!
        return 1
    fi

    function _partmount () {
        local img="$1.img"
        local offset
        local length

        if [[ ! -f "$img" ]]; then
            echo Image "$img" not found!
            return 1
        fi

        mkdir -p "$XENDIR/mnt"
        # Do not complain about awk lines
        # shellcheck disable=SC2086
        offset=$(parted -sm "$img" unit b print 2>/dev/null | awk -F ":" '$6=="'$2'"{gsub(/B/, ""); print $2}')
        # shellcheck disable=SC2086
        length=$(parted -sm "$img" unit b print 2>/dev/null | awk -F ":" '$6=="'$2'"{gsub(/B/, ""); print $4}')
        if [[ -z $offset || -z $length ]]; then
            echo Could not parse the image file or bad partition
            return 1
        fi
        # these are just numbers
        # shellcheck disable=SC2086
        mount -o loop,offset=$offset,sizelimit=$length "$img" "$XENDIR/mnt"
        return 0
    }

    function _partumount () {
        umount "$XENDIR/mnt/"
    }

    # shellcheck disable=SC2221,SC2222
    # https://github.com/koalaman/shellcheck/issues/1044
    case $action in
        mount)
            if [[ -z $3 ]]; then
                echo Need a partition to mount!
                return 1
            fi
            _partmount "$node" "$3"
            ;;
        refresh|grub)
            _partmount "$node" OEM
            echo "set linux_append=\"coreos.config.url=http://192.168.100.1/$base/$node.json\"" > "$XENDIR/mnt/grub.cfg"
            echo -n grub.cfg set to:
            cat "$XENDIR/mnt/grub.cfg"
            _partumount
            ;;&
        refresh|systemd)
            _partmount "$node" ROOT
            echo Removed /etc/machine-id for systemd units refresh
            rm -f "$XENDIR/mnt/etc/machine-id"
            _partumount
            ;;&
        refresh|tmpl)
            local ct="$node.ct"
            local tmpl="$node.ct.tmpl"
            if [[ -f $tmpl ]]; then
                if [[ -f $ct && $ct -nt $tmpl ]]; then
                    echo A "$tmpl" file exists, but "$ct" is newer, so will not regenerate it
                else
                    echo Creating the transpile file from the template "$tmpl"
                    kgenct -t "$tmpl"
                fi
            fi
            ;;&
        refresh|ct)
            local ct="$node.ct"
            if [[ ! -f $ct ]]; then
                echo Ignition directives file "$ct" not found
                return 1
            fi
            echo Transpiling "$node.ct" and adding it to nginx
            ct -in-file "$ct" -out-file "$XENDIR/nginx/$base/$node.json"
            ;;&
        refresh|firstboot)
            _partmount "$node" EFI-SYSTEM
            echo Creating coreos/first_boot
            touch "$XENDIR/mnt/coreos/first_boot"
            _partumount
            ;;&
        refresh|firstboot|ct|systemd|grub|tmpl)
            # If we are here we had a valid action, so nop, the * case will
            # catch syntax errors.
            ;;
        *)
            echo Unknown action "$action"
            return 1
    esac
}

function _kgen()
{
    local cur prev

    COMPREPLY=()
    cur=$(_get_cword)
    prev=${COMP_WORDS[COMP_CWORD-1]}
    _expand || return 0

    case "$prev" in
        refresh|firstboot|ct|systemd|grub|mount|tmpl)
            # this is idiomatic compgen as far as I can see
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -f -X '!*.cfg' -- "$cur" | sed -e 's/\.cfg//' ) )
        return 0
        ;;
    esac

    # this is idiomatic compgen as far as I can see
    # shellcheck disable=SC2207
    COMPREPLY=( $( compgen -W 'refresh firstboot ct systemd grub mount tmpl' -- "$cur" ))
    return 0
}
complete -F _kgen kgen
```

# kgencert

[link to the source file](/code/kgencert.txt)

```bash
function kgencert () {
    local node=$1
    local ip=$2
    local pwd

    pwd=$(pwd)
    base=$(basename "$pwd")

    if [[ -z $XENDIR ]]; then
        echo XENDIR must be set
        return 1
    fi

    if [[ $pwd != "$XENDIR/guests/$base" ]]; then
        echo You should be in a guests subdirectory!
        return 1
    fi

    if [[ ! -f "$XENDIR/guests/$base/$node.cfg" ]]; then
        echo "$node.cfg" not found!
        return 1
    fi

    if [[ -z $ip ]]; then
        if [[ ! -f /var/lib/dnsmasq/virbr1/hostsfile ]]; then
            echo Missing dnsmasq hosts file and no IP passed
            return 1
        fi

        mac=$(awk "\$1 == \"vif\" { gsub(/'mac=/, \"\"); gsub(/,*model.*/, \"\"); print \$4 }" < "$1.cfg")
        ip=$(grep "$mac" /var/lib/dnsmasq/virbr1/hostsfile)

        if [[ -z $ip ]]; then
            echo The node\'s mac address "$mac" is not present in the dnsmasq hosts file
            return 1
        fi

        IFS=',' read -ra IPS <<< "$ip"
        ip=${IPS[1]}
    fi

    mkdir -p ./certs

    if [[ ! -f ./certs/ca-csr.json ]]; then
        cat > ./certs/ca-csr.json <<EOF
{
    "CN": "$base cluster CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "O": "$(hostname) clusters",
            "OU": "The $base cluster"
        }
    ]
}
EOF
    fi

    if [[ ! -f ./certs/ca-config.json ]]; then
        cat > ./certs/ca-config.json <<EOF
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
EOF
    fi

    cd certs || return

    ca="$base-ca.pem"
    cak="$base-ca-key.pem"
    if [[ ! -f $ca || ! -f $cak ]]; then
        # Generate the cluster CA, no need to remove existing .pem certificate
        # files as they will be overwritten.
        cfssl gencert -initca ca-csr.json | cfssljson -bare "$base-ca" -
        rm -f "$base-ca.csr"
    fi

    # Now generate the cluster certificates
    pre='{"CN":"'$base'-'$node
    post='","hosts":[""],"key":{"algo":"rsa","size":2048}}'
    echo "$pre-server$post" | cfssl gencert \
                                    -ca="$ca" -ca-key="$cak" \
                                    -config=ca-config.json -profile=server \
                                    -hostname="$ip,$base-$node" \
                                    - | cfssljson -bare "$base-$node-server"
    rm -f "$base-$node-server.csr"
    echo "$pre-peer$post" | cfssl gencert \
                                  -ca="$ca" -ca-key="$cak" \
                                  -config=ca-config.json -profile=peer \
                                  -hostname="$ip,$base-$node" \
                                  - | cfssljson -bare "$base-$node-peer"
    rm -f "$base-$node-peer.csr"

    echo "$pre-client$post" | cfssl gencert \
                                    -ca="$ca" -ca-key="$cak" \
                                    -config=ca-config.json -profile=client \
                                    - | cfssljson -bare "$base-$node-client"
    rm -f "$base-$node-client.csr"
    cd ..
}

function _kgencert()
{
    local cur prev

    COMPREPLY=()
    cur=$(_get_cword)
    _expand || return 0

    # this is idiomatic compgen as far as I can see
    # shellcheck disable=SC2207
    COMPREPLY=( $(compgen -f -X '!*.cfg' -- "$cur" | sed -e 's/\.cfg//' ) )
    return 0
}
complete -F _kgencert kgencert
```

# kgenct

[link to the source file](/code/kgenct.txt)

```python
#!/usr/bin/env python
from __future__ import print_function
import argparse
import sys

parser = argparse.ArgumentParser(
    description='Add certificates to Ignition configuration files.')
parser.add_argument('-t', '--template', metavar='T', type=str, required=True,
                    help='template file to use')

args = parser.parse_args()

if not args.template.endswith(".ct.tmpl"):
    print ("The template file should end with .ct.tmpl")
    sys.exit(-1)

with open(args.template) as f:
    contents = f.read().split('\n')

with open(args.template[:-len(".tmpl")], "w") as f:
    for x in contents:
        try:
            col = x.index("###")
            colspace = " " * (col - 1)
        except Exception:
            f.write(x + "\n")
            continue

        subfile = x[col + 3:]
        with open(subfile) as c:
            subcontents = c.read().split('\n')

        if x[col - 1] == '|':
            for cline in subcontents:
                f.write(colspace + cline + "\n")
        elif x[col - 1] == '-':
            f.write(x[:(col - 1)] + "".join(subcontents) + "\n")
        else:
            print("Unknown qualifier in %s", x)
            sys.exit(-1)
```
