# This first function should be put in your system's bashrc, together with
# XENDIR being set in your profile, and XENDIR/bin being in your path

# cd to the cluster in question and loads any scripts if present
function xencd {
    if [[ -z $XENDIR ]]; then
        echo XENDIR must be set
        return 1
    fi

    if [[ ! -d "$XENDIR/guests/$1" ]]; then
        echo "$XENDIR/guests/$1" does not exist!
        return 1
    fi

    cd "$XENDIR/guests/$1" || return
    if [[ -f ./functions.bashrc ]]; then
        # shellcheck disable=SC1091
        . ./functions.bashrc
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

############################################################################
# These functions are available
#
# khostsfile      Generates a hosts file for dnsmasq
# kubeconfig      Sets up the kubectl configuration to use the current cluster
# kup             Starts a cluster
# kdown           Shuts down a cluster
# kdestroy        Force unclean shutdown a cluster
# kcreateimgs     Create Xen .img files for the cluster from CoreOS image
# kcreatecfg      Creates Xen configuration files for the cluster
# kgen            Operates on the existing .img files, typically force ignition to rerun
# kgenip          Generates a custom certificate
# kgencert        Generates all certificates for the cluster
# knodeportcert   Generates a nodeport certificate for the cluster



# Also does some sanity checks
function _getbase() {
    local _basename=$1
    local pwd
    pwd=$(pwd)
    local _base
    _base=$(basename "$pwd")

    if [[ -z $XENDIR ]]; then
        echo XENDIR must be set
        return 0
    fi

    if [[ "$pwd" != "$XENDIR/guests/$_base" ]]; then
        echo "You must be in a guests subdirectory! ($pwd != $XENDIR/guests/<guestname>)"
        return 0
    fi

    eval "$_basename=$_base"
    return 1
}

# Used to quickly generate a dnsmasq hostsfile
function khostsfile {
    local macprefix='00:16:3e:4e:31:'
    local ipprefix='192.168.100.'

    for i in {10..99}
    do
        echo $macprefix$i','$ipprefix$i
    done
}

# Assume the master is the first passed host, set the server in the kubeconfig
# to the Xen IP of the guest.
function kubeconfig {
    local master=$1
    local base

    if _getbase base; then
        return 1
    fi

    if [[ ! -f "$master.cfg" ]]; then
        echo "Cannot find $master.cfg"
        return 1
    fi

    local mac
    while IFS='' read -r line; do
        if [[ $line =~ mac=([^,]+), ]]; then
            mac=${BASH_REMATCH[1]}
        fi
    done< "$master.cfg"

    local ip
    while IFS=',' read -r fmac fip; do
        if [[ $fmac == $mac ]]; then
            ip=$fip
        fi
    done< /var/lib/dnsmasq/virbr1/hostsfile

    kubectl config set-cluster "$base" \
            --certificate-authority=certs/"$base-kube-ca.pem" \
            --embed-certs=true --server="https://$ip:8443"

    kubectl config set-credentials admin --embed-certs=true \
            --client-certificate="certs/$base-kube-client.pem" \
            --client-key="certs/$base-kube-client-key.pem" \
            --token="$(awk -F ',' '/system:masters/ { print $1 }' < out/known_tokens.csv)"

    kubectl config set-context "$base" --cluster="$base" --user=admin
    kubectl config use-context "$base"
}

# Will tell Xen to start the specified guest(s), assumes guest.cfg exists
function kup {
    local base

    if _getbase base; then
        return 1
    fi

    for x in "$@"
    do
        cmd="xl create $x.cfg"
        $cmd &
    done
}

# Will tell Xen to shutdown the specified guest(s)
function kdown {
    local base

    if _getbase base; then
        return 1
    fi

    for x in "$@"
    do
        cmd="xl shutdown $base-$x"
        $cmd &
    done
}

# For emergencies
function kdestroy {
    local base

    if _getbase base; then
        return 1
    fi

    for x in "$@"
    do
        cmd="xl destroy $base-$x"
        $cmd &
    done
}

# Will create Xen image files
# kcreateimgs 1520.9.0 2048 master node-1 node-2 ...
# will create master.img, node-1.img, ... with an extra 2gb of space and using
# the Kubernetes 1520.9.0 distribution as long as it's in /storage/xen/images
# and is named coreos-1520.9.0.bin.bz2
function kcreateimgs {
    local version=$1
    shift
    local extra=$1
    shift
    local base

    if _getbase base; then
        return 1
    fi

    img="$XENDIR/images/coreos-$version.bin.bz2"
    if [[ ! -f $img ]]; then
        echo "Cound not find image $img"
        return 1
    fi

    if [[ ! $extra =~ ^[0-9]+$ ]]; then
        echo "The number of extra megabytes must be a number $extra"
        return 1
    fi

    i=0
    for x in "$@"
    do
        echo "Expanding $img to $x.img"
        bzcat "$img" > "$x.img"

        if [[ $extra -gt 0 ]]; then
            echo "Adding $extra megabytes to $x.img"
            # shellcheck disable=SC2086
            dd if=/dev/zero bs=1048576 count=$extra >> "$x.img"
        fi
    done
}

# Will create Xen configuration files for the specified hosts
# kcreatecfg 20 master node-1 node-2 ...
# will create master.cfg, node-1.cfg, ... with macs that will get IPs 20,21,...
function kcreatecfg {
    local startip=$1
    shift
    local base

    if _getbase base; then
        return 1
    fi

    if [[ $startip -lt 10 || $startip -gt 90 || $((startip % 10)) -ne 0 ]]; then
        echo "The start octet must be one of 10,20, ... 90"
        return 1
    fi

    declare -A IPS
    declare -A MACS
    local i=0
    while IFS=',' read -r mac ip; do
        # Check for lines that end with an octet between the specified octet
        # and it + 10
        if [[ $ip =~ ([0-9]+$) ]]; then
            if [[ ${BASH_REMATCH[0]} -ge $startip && ${BASH_REMATCH[0]} -lt $((startip + 10)) ]]; then
                MACS[$i]=$mac
                IPS[$i]=$ip
                ((i += 1))
            fi
        fi
    done< /var/lib/dnsmasq/virbr1/hostsfile

    mastervcpu=2
    mastermem=2048
    nodevcpu=1
    nodemem=1536
    i=0
    for x in "$@"
    do
        if [[ -z ${MACS[$i]} ]]; then
            echo "Could not find a mac for your $x node in the hostfile"
            return 1
        fi
        echo "Creating $x.cfg, will become ${IPS[$i]} with mac ${MACS[$i]}"
        echo 'bootloader = "pygrub"' > "$x".cfg
        {
            echo "name = \"$base-$x\""
            if [[ $i == 0 ]]; then
                echo "memory = $mastermem"
                echo "vcpus = $mastervcpu"
            else
                echo "memory = $nodemem"
                echo "vcpus = $nodevcpu"
            fi
            echo "vif = [ 'mac=${MACS[$i]},model=rtl8139,bridge=virbr1' ]"
            echo "disk = [ '$XENDIR/guests/$base/$x.img,raw,xvda' ]"
        } >> "$x".cfg
        i=$((i+1))
    done
    echo -e "\\nThe cluster was created with master: vcpu=$mastervcpu, mem=$mastermem nodes: vcpu=$nodevcpu mem=$nodemem"
}

# Will generate ignition files and set up images
#   kgen action node
# action can be
#   refresh: will execute everything
#   grub: will set the grub override for ignition
#   systemd: will remove machine-id to refresh sytemd units
#   ct: will transpile the ignition file and add it to nginx
#   firstboot: will cause ignition to run
#
# additionally this can also be invoked as
#   kgen mount node PARTNAME
# which will mount the partition in the image in XENDIR/mnt
function kgen() {
    local action=$1
    shift

    if [[ $action == "mount" ]]; then
        _hkgen "$action" "$@"
        return $?
    fi

    for x in "$@"
    do
        if [[ $x =~ (.*).cfg$ ]]; then
            _hkgen "$action" "${BASH_REMATCH[1]}"
        else
            _hkgen "$action" "$x"
        fi
    done
}

function _hkgen () {
    local action=$1
    local node=$2
    local base

    if _getbase base; then
        return 1
    fi

    if [[ -z $2 ]]; then
        echo A node must be passed
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
        refresh|ct)
            local ct="out/$node.ct"
            if [[ ! -f $ct ]]; then
                echo Ignition directives file "$ct" not found
                return 1
            fi
            echo Transpiling "$node.ct" and adding it to nginx
            mkdir -p "$XENDIR/nginx/$base"
            ct -in-file "$ct" -out-file "$XENDIR/nginx/$base/$node.json"
            ;;&
        refresh|firstboot)
            _partmount "$node" EFI-SYSTEM
            echo Creating coreos/first_boot
            touch "$XENDIR/mnt/coreos/first_boot"
            _partumount
            ;;&
        refresh|firstboot|ct|systemd|grub)
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


# kgenip will generate certificates for the specified node with the specified
# ip (overriding anything in dnsmasq hosts).
function kgenip () {
    _hkgencert "$1" "$2"
}

# kgencert will generate all certificates for the specified node, will also
# generate the CAs if needed.
function kgencert() {
    for x in "$@"
    do
        if [[ $x =~ (.*).cfg$ ]]; then
            _hkgencert "${BASH_REMATCH[1]}"
        else
            _hkgencert "$x"
        fi
    done
}

function _iphelper () {
    local _ipreturn=$1

    localip=$(/bin/ip addr |
              /usr/bin/awk '
                            BEGIN {
                               i = 0
                            }
                            /state UP/ {
                               candidate = 1;
                               }
                            # ipv4 only, no /inet6/
                            /inet / {
                               if(candidate == 1) {
                                   gsub(/\/[0-9]*$/, "", $2);
                                   if($2 != "127.0.0.1" && $2 != "") {
                                     addrs[i] = $2;
                                     i = i + 1
                                   }
                                   candidate = 0 }}
                            END {
                               if (i < 1)
                                   exit
                               printf ("%s", addrs[0]);
                               for (x = 1; x < i; x++)
                                   printf (",%s", addrs[x])
                            }')

    eval "$_ipreturn=$localip"
}

function _certsconfig() {
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

    if [[ ! -f ./certs/kube-ca-csr.json ]]; then
        cat > ./certs/kube-ca-csr.json <<EOF
{
    "CN": "$base kubernetes CA",
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

    if [[ ! -f ./certs/nodeport-ca-csr.json ]]; then
        cat > ./certs/nodeport-ca-csr.json <<EOF
{
    "CN": "$base kubernetes nodeport CA",
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

    # CA config is shared among all CAs
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
}

function _hkgencert () {
    local node=$1
    local ip=$2
    local localip=$3
    local pwd

    if _getbase base; then
        return 1
    fi

    if [[ ! -f "$node.cfg" ]]; then
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

    _certsconfig

    if [[ ! -f ./certs/kube-ca-config.json ]]; then
        # Customize here if you need to have different settings for k8s
        cp ./certs/ca-config.json ./certs/kube-ca-config.json
    fi

    cd certs || return

    pre='{"CN":"'$base
    post='","hosts":[""],"key":{"algo":"rsa","size":2048}}'

    ca="$base-ca.pem"
    cak="$base-ca-key.pem"
    if [[ ! -f $ca || ! -f $cak ]]; then
        # Generate the cluster CA, no need to remove existing .pem certificate
        # files as they will be overwritten.
        echo Generating the etcd ca
        cfssl gencert -loglevel=5 -initca ca-csr.json | \
            cfssljson -bare "$base-ca"
        rm -f "$base-ca.csr"

        # Overall client certificate to copy to the outside world if needed
        echo "$pre-client$post" | cfssl gencert -loglevel=5 \
                                        -ca="$ca" -ca-key="$cak" \
                                        -config=kube-ca-config.json -profile=client \
                                        - | cfssljson -bare "$base-client"

        rm -f "$base-client.csr"
    fi

    kca="$base-kube-ca.pem"
    kcak="$base-kube-ca-key.pem"
    if [[ ! -f $kca || ! -f $kcak ]]; then
        # Generate the kubernetes CA
        echo Generating the Kubernetes ca
        cfssl gencert -loglevel=5 -initca kube-ca-csr.json | \
            cfssljson -bare "$base-kube-ca" -  > /dev/null
        rm -f "$base-kube-ca.csr"

        # Overall client certificate to copy to the outside world if needed
        cert='{"names":[{"O":"system:masters"}],"CN":"admin'$post
        echo "$cert" | cfssl gencert -loglevel=5 \
                             -ca="$kca" -ca-key="$kcak" \
                             -config=kube-ca-config.json -profile=client \
                             - | cfssljson -bare "$base-kube-client"
        rm -f "$base-kube-client.csr"
    fi

    # Now generate the cluster certificates
    pre='{"CN":"'$base'-'$node
    echo "Generating the etcd server certificate for $node"
    echo "$pre-server$post" | cfssl gencert -loglevel=5 \
                                    -ca="$ca" -ca-key="$cak" \
                                    -config=ca-config.json -profile=server \
                                    -hostname="$ip,$base-$node" \
                                    - | cfssljson -bare "$base-$node-server"
    rm -f "$base-$node-server.csr"
    echo "Generating the etcd peer certificate for $node"
    echo "$pre-peer$post" | cfssl gencert -loglevel=5 \
                                  -ca="$ca" -ca-key="$cak" \
                                  -config=ca-config.json -profile=peer \
                                  -hostname="$ip,$base-$node" \
                                  - | cfssljson -bare "$base-$node-peer"
    rm -f "$base-$node-peer.csr"

    echo "Generating the etcd client certificate for $node"
    echo "$pre-client$post" | cfssl gencert -loglevel=5 \
                                    -ca="$ca" -ca-key="$cak" \
                                    -config=ca-config.json -profile=client \
                                    - | cfssljson -bare "$base-$node-client"
    rm -f "$base-$node-client.csr"

    # Get our local IP(s)
    if [[ -z $localip ]]; then
        _iphelper localip
    fi

    # Kubernetes server certs
    cert='{"CN":"apiserver-'$node$post
    echo "Generating the Kubernetes apiserver server certificate for $node"
    echo "$cert" | cfssl gencert -loglevel=5 \
                         -ca="$kca" -ca-key="$kcak" \
                         -config=kube-ca-config.json -profile=server \
                         -hostname="10.199.0.1,$ip,$base-$node,$localip" \
                         - | cfssljson -bare "$base-kube-$node-apiserver"
    rm -f "$base-kube-$node-apiserver.csr"

    cert='{"CN":"kubelet-'$node$post
    echo "Generating the Kubernetes kubelet server certificate for $node"
    echo "$cert" | cfssl gencert -loglevel=5 \
                         -ca="$kca" -ca-key="$kcak" \
                         -config=kube-ca-config.json -profile=server \
                         -hostname="$ip,$base-$node" \
                         - | cfssljson -bare "$base-kube-$node-kubelet"
    rm -f "$base-kube-$node-kubelet.csr"

    # Time for the kubernetes client certs, which require specific CNs.
    echo "Generating the Kubernetes kubelet client certificate for $node"
    cert='{"names":[{"O":"system:nodes"}],"CN":"system:node:'$base'-'$node$post
    echo "$cert" | cfssl gencert -loglevel=5 \
                         -ca="$kca" -ca-key="$kcak" \
                         -config=kube-ca-config.json -profile=client \
                         - | cfssljson -bare "$base-kube-$node-kubelet-client"
    rm -f "$base-kube-$node-kubelet-client.csr"

    echo "Generating the Kubernetes controller manager client certificate for $node"
    cert='{"names":[{"O":"system:kube-controller-manager"}],"CN":"system:kube-controller-manager'$post
    echo "$cert" | cfssl gencert -loglevel=5 \
                         -ca="$kca" -ca-key="$kcak" \
                         -config=kube-ca-config.json -profile=client \
                         - | cfssljson -bare "$base-kube-$node-kube-controller-manager-client"
    rm -f "$base-kube-$node-kube-controller-manager-client.csr"

    echo "Generating the Kubernetes scheduler client certificate for $node"
    cert='{"names":[{"O":"system:kube-scheduler"}],"CN":"system:kube-scheduler'$post
    echo "$cert" | cfssl gencert -loglevel=5 \
                         -ca="$kca" -ca-key="$kcak" \
                         -config=kube-ca-config.json -profile=client \
                         - | cfssljson -bare "$base-kube-$node-kube-scheduler-client"
    rm -f "$base-kube-$node-kube-scheduler-client.csr"

    echo "Generating the Kubernetes proxy client certificate for $node"
    cert='{"names":[{"O":"system:node-proxier"}],"CN":"system:kube-proxy'$post
    echo "$cert" | cfssl gencert -loglevel=5 \
                         -ca="$kca" -ca-key="$kcak" \
                         -config=kube-ca-config.json -profile=client \
                         - | cfssljson -bare "$base-kube-$node-kube-proxy-client"
    rm -f "$base-kube-$node-kube-proxy-client.csr"

    cert='{"names":[{"O":"system:masters"}],"CN":"admin'$post
    echo "Generating the Kubernetes admin client certificate for $node"
    echo "$cert" | cfssl gencert -loglevel=5 \
                         -ca="$kca" -ca-key="$kcak" \
                         -config=kube-ca-config.json -profile=client \
                         - | cfssljson -bare "$base-kube-$node-client"
    rm -f "$base-kube-$node-client.csr"
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

function knodeportcert() {
    local cn=$1
    local ip=$2

    if _getbase base; then
        return 1
    fi

    # If the user is not passing an IP, generate the cert for our real IP
    # assuming they plan to access the nodeport from somewhere else.
    if [[ -z $localip ]]; then
        _iphelper ip
    fi

    _certsconfig

    mkdir -p "./$cn-certs"
    can="./certs/$base-nodeport-ca.pem"
    cank="./certs/$base-nodeport-ca-key.pem"
    if [[ ! -f $can || ! -f $cank ]]; then
        # Generate the nodeport CA, for additional certificates if needed
        echo Generating the nodeport ca
        cfssl gencert -loglevel=5 -initca ./certs/nodeport-ca-csr.json | \
            cfssljson -bare "./certs/$base-nodeport-ca" \
                      -loglevel=5
        rm -f "./certs/$base-nodeport-ca.csr"
        rm -f "./certs/$base-nodeport-client.csr"
    fi

    echo "Generating a nodeport certificate for '$cn' with IPs set to 10.199.0.1,$ip"
    cert='{"CN":"'$cn'","hosts":[""],"key":{"algo":"rsa","size":2048}}'
    echo "$cert" | cfssl gencert \
                         -ca="$can" -ca-key="$cank" \
                         -config=./certs/ca-config.json -profile=server \
                         -loglevel=5 -hostname="10.199.0.1,$ip" \
                         - | cfssljson -bare "./$cn-certs/$base-nodeport-$cn" \
                                       -loglevel=5
    rm -f "./$cn-certs/$base-nodeport-$cn.csr"
}
