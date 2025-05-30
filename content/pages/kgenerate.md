+++
type = "code"
title = "kgenerate"
description = ""
tags = [
]
date = "2017-12-14T09:30:28-08:00"
categories = [
]
shorttitle = "kgen"
changelog = [ 
    "Initial release - 2017-12-14",
]
+++

This python script is used to create our final Kubernetes cluster [as
discussed here]({{< ref "xen-final.md" >}})

```python
#!/usr/bin/env python
from __future__ import print_function
import argparse
import sys
import os
import string
import operator
import errno
import uuid
import re
from collections import namedtuple


class Tmpl():
    "Utility class to generate, write and transpile a template"

    def __init__(self, tmpl, dst="", master=False, other=False, nany=False,
                 etcd=False, toplevel=False, subtemplate=False, ct=False):
        with open("./templates/" + tmpl + ".template") as f:
            self.template = f.read()
        self.destination = dst
        self.toplevel = toplevel
        self.ct = ct
        if ct:
            self.toplevel = True

        if nany:
            self.master = True
            self.other = True
            self.etcd = True
        else:
            self.master = master
            self.other = other
            self.etcd = etcd

    def generate(self, subs):
        self.content = string.Template(self.template).substitute(subs)
        return self.content

    def tokengenerate(self, node):
        token = str(uuid.uuid4()).replace('-', '')
        self.content = string.Template(self.template).substitute({
            "master": node,
            "token": token,
        })
        return token

    def write(self, node="", master=False, other=False, nany=False,
              etcd=False, ct=False):
        self.node = node
        if (nany or
            (master and self.master) or
            (other and self.other) or
                (etcd and self.etcd)):
            dst = "./out"
            if not self.toplevel:
                if node == "":
                    raise ValueError("Unset node for a non-toplevel template")
                dst = dst + "/" + node

            if self.ct:
                dst = dst + "/" + node + ".ct.tmpl"
            else:
                if self.destination == "":
                    raise ValueError("No destination set!")
                dst = dst + "/" + self.destination
            with open(dst, "w") as t:
                t.write(self.content)
        else:
            raise ValueError("Mismatch with the template declaration and "
                             "usage, did not write %s" % self.content)

    def transpile(self):
        if not self.ct:
            raise ValueError("Cannot transpile a non-ct template")

        if self.node == "":
            raise ValueError("Unset node")

        with open("./out/" + self.node + ".ct", "w") as f:
            for x in self.content.split('\n'):
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
                    raise ValueError("Unknown qualifier in %s", x)


def invocation():
    "Takes the command line parameters and validates them"

    parser = argparse.ArgumentParser(
        description='''Create the cluster configuration files.
                       Will create a .ct.tmpl for each .cfg file.
                       Maximum 10 nodes/images total.''')

    parser.add_argument(
        '-e', '--etcd', metavar='E', type=int, required=True,
        help='number of etcd nodes')
    parser.add_argument(
        '-c', '--cluster', metavar='C', nargs="+",
        required=True, help='''space separated image names, without .cfg,
                                will be in order master, etcd nodes, other
                                nodes. All image files in the directory need
                                to be listed here''')
    parser.add_argument(
        '-k', '--kube', metavar='K', type=str, required=True,
        help='''hyperkube tag to use, see https://quay.io/repository/
        coreos/hyperkube?tag=latest&tab=tags for available tags''')
    args = parser.parse_args()

    tag = args.kube
    if not re.match('^v[0-9]+\.[0-9]+\.[0-9]$', tag):
        raise AttributeError("The passed tag does not look correct,"
                             " expecting it in vx.y.z format"
                             "(%s)\n" % tag)

    xendir = os.getenv("XENDIR", "")
    if xendir == "":
        raise AttributeError("XENDIR must be set")
    pwd = os.getcwd()
    guest = os.path.basename(pwd)
    expected = ''.join([xendir, "/guests/", guest])
    if pwd != expected:
        raise AttributeError("You should be in a guests directory!"
                             " (am in %s, expected %s)" % (pwd, expected))

    if args.etcd < 1:
        raise AttributeError("At least one etcd node is required (%d)" %
                             args.etcd)

    with open("/var/lib/dnsmasq/virbr1/hostsfile") as f:
        t = f.read().split('\n')
        dnsmasq = [s for s in t if len(s) > 0 and '#' not in s]
        ips = dict(x.split(',') for x in dnsmasq)

    Cfg = namedtuple("Cfg", "tag cluster netcd nodes ips master etcd other")
    return Cfg(
        tag,
        guest,
        args.etcd + 1,
        args.cluster,
        ips,
        args.cluster[0],
        args.cluster[1:args.etcd + 1],
        args.cluster[args.etcd + 1:],
    )


def assemble(args):
    '''Create the nodes list from the local .cfg files, as well as the
       initial common template substitutions'''

    nodeips = {}
    for entry in os.listdir('.'):
        if not entry.endswith('.cfg') or not os.path.isfile(entry):
            continue
        c = entry[:-4]
        if c not in args.nodes:
            raise ValueError("Image %s is not in the cluster list!\n" % c)
        with open(entry) as f:
            t = f.read().split('\n')
            for x in t:
                if x.startswith('name'):
                    name = x.split('=')[1].strip().replace('"', '')
                elif x.startswith('vif'):
                    cut = x.index('mac')
                    t = x[cut:]
                    cut = t.index(',')
                    t = t[:cut]
                    mac = t.split('=')[1].strip().replace('"', '')

            if (not name.startswith(args.cluster + "-") or
                    name[len(args.cluster) + 1:] not in args.nodes):
                raise ValueError("Configuration file %s has hostname %s which"
                                 "is not in the cluster" % (entry, name))
            nodeips[c] = mac

    if len(nodeips) < args.netcd or args.netcd > 9:
        raise ValueError("%d images with %d etcd nodes is not going to"
                         " work\n" % (len(nodeips), args.netcd - 1))

    for k, v in nodeips.items():
        if v not in args.ips:
            raise ValueError("Expected to find %s in %s\n" % (v, args.ips))

        nodeips[k] = args.ips[v]

    subs = {
        # Will create
        # solar-mercury=https://192.168.100.21:2380,solar-venus=https://192...
        "etcdlist": ','.join([args.cluster + '-' + x + '=https://' +
                              nodeips[x] + ':2380'
                              for x in args.etcd]),
        # will create https://192.168.100.21:2379,https://192.168.100.2...
        "etcdiplist": ','.join(['https://' + nodeips[x] + ':2379'
                                for x in args.etcd]),
        "guest": args.cluster,
        "home": os.getenv("HOME"),
    }
    return (nodeips, subs)


def main():
    try:
        # Get the sanitized args
        args = invocation()
        (nodeips, subs) = assemble(args)

        # Set up the needed templates
        library = {
            "apiserver": Tmpl(
                "apiserver", dst="apiserver.yaml", master=True),
            "controller": Tmpl(
                "controller", dst="controller.yaml", master=True),
            "etcd": Tmpl("etcd"),
            "flannel": Tmpl("flannel-setup"),
            "flanneld": Tmpl("flanneld"),
            "kube-controller-manager": Tmpl("kube-controller-manager",
                                            "kube-controller-manager.cfg",
                                            master=True),
            "kube-proxy": Tmpl("kube-proxy", "kube-proxy.cfg", nany=True),
            "kube-scheduler": Tmpl("kube-scheduler",
                                   "kube-scheduler.cfg", master=True),
            "kubelet": Tmpl("kubelet", dst="kubelet.cfg", nany=True),
            "node-etcd": Tmpl("node-etcd", etcd=True, ct=True),
            "node-master": Tmpl("node-master", master=True, ct=True),
            "node-other": Tmpl("node-other", other=True, ct=True),
            "profile": Tmpl("profile", dst="profile.txt",
                            toplevel=True),
            "proxy": Tmpl(
                "proxy", dst="proxy.yaml", nany=True, toplevel=True),
            "scheduler": Tmpl(
                "scheduler", dst="scheduler.yaml", master=True),
            "storage": Tmpl("storage"),
            "storage-etcd": Tmpl("storage-etcd"),
            "storage-master": Tmpl("storage-master"),
            "systemd": Tmpl("systemd"),
        }

        # Prepare the output directory
        try:
            os.makedirs("./out")
            for x in args.nodes:
                os.makedirs("./out/" + x)
        except OSError as e:
            if (e.errno == errno.EEXIST):
                pass

        # First a non-template file
        with open("./out/hosts.txt", "w") as t:
            t.write('''# Autogenerated
127.0.0.1    localhost
::1          localhost
''')
            for x in sorted(nodeips.items(), key=operator.itemgetter(1)):
                t.write(x[1] + "  " + args.cluster + "-" + x[0] +
                        ".cluster.local" + "  " + args.cluster + "-" +
                        x[0] + "\n")

        # Prepare the global substitutions, later substitutions might depend
        # on the former.
        subs["master"] = nodeips[args.master]
        subs["hypertag"] = args.tag

        # We have two flanneld sections depending if it's an etcd node or not
        subs["flanneldsetup"] = library["flannel"].generate(subs)
        flanneld_with_etcd_setup = library["flanneld"].generate(subs)
        subs["flanneldsetup"] = ""
        subs["flanneld"] = library["flanneld"].generate(subs)

        # Time to start writing files
        library["profile"].generate(subs)
        library["profile"].write(nany=True)

        # First create the basic_auth csv file with a random password
        password = str(uuid.uuid4()).replace('-', '')
        with open("./out/basic_auth.csv", "w") as t:
            t.write(password)
            t.write(",admin,admin,system:masters\n")

        # Now all the other tokens, first the admin token
        token = str(uuid.uuid4()).replace('-', '')
        tokens = [','.join([token,
                            "admin",
                            "admin",
                            "system:masters"])]

        # then kubelet and kube-proxy, for all nodes
        for x in args.nodes:
            tokens.append(','.join([library["kubelet"].tokengenerate(
                nodeips[args.master]),
                "system:node:" + args.cluster + "-" + x,
                "system:node:" + args.cluster + "-" + x,
                "system:nodes"]))
            library["kubelet"].write(node=x, nany=True)

            tokens.append(','.join([library["kube-proxy"].tokengenerate(
                nodeips[args.master]),
                "system:kube-proxy",
                "system:kube-proxy",
                "system:node-proxier"]))
            library["kube-proxy"].write(node=x, nany=True)

        # Finally scheduler and controller manager, which are master-only
        tokens.append(','.join([library["kube-scheduler"].tokengenerate(
            nodeips[args.master]),
            "system:kube-scheduler",
            "system:kube-scheduler",
            "system:kube-scheduler"]))
        library["kube-scheduler"].write(node=args.master, master=True)

        tokens.append(','.join([
            library["kube-controller-manager"].tokengenerate(
                nodeips[args.master]),
            "system:kube-controller-manager",
            "system:kube-controller-manager",
            "system:kube-controller-manager"]))
        library["kube-controller-manager"].write(node=args.master,
                                                 master=True)

        # All the tokens we have created have to go in their own file
        with open('./out/known_tokens.csv', "w") as t:
            for x in tokens:
                t.write(x)
                t.write("\n")

        # Master-only templates
        for t in ["apiserver", "proxy", "controller", "scheduler"]:
            library[t].generate(subs)
            library[t].write(node=args.master, master=True)

        # Master:
        subs["hostname"] = args.master
        subs["hostip"] = nodeips[args.master]
        subs["storage"] = library["storage"].generate(subs)
        subs["storagemaster"] = library["storage-master"].generate(subs)
        subs["systemd"] = library["systemd"].generate(subs)
        library["node-master"].generate(subs)
        library["node-master"].write(node=args.master, master=True)
        library["node-master"].transpile()

        # Other nodes
        for x in args.other:
            subs["hostname"] = x
            subs["hostip"] = nodeips[x]
            subs["storage"] = library["storage"].generate(subs)
            library["node-other"].generate(subs)
            library["node-other"].write(node=x, other=True)
            library["node-other"].transpile()

        # Etcd nodes
        subs["flanneld"] = flanneld_with_etcd_setup
        subs["systemd"] = library["systemd"].generate(subs)
        for x in args.etcd:
            subs["hostname"] = x
            subs["hostip"] = nodeips[x]
            subs["storage"] = library["storage"].generate(subs)
            subs["storage"] = library["storage-etcd"].generate(subs)
            subs["etcd"] = library["etcd"].generate(subs)
            library["node-etcd"].generate(subs)
            library["node-etcd"].write(node=x, etcd=True)
            library["node-etcd"].transpile()

        # And we are done!
        print("Created templates for a cluster with:")
        print("Master:   %-20s (%s)" % (args.cluster + "-" + args.master,
                                        nodeips[args.master]))
        for x in args.etcd:
            print("Etcd:     %-20s (%s)" % (args.cluster + "-" + x,
                                            nodeips[x]))
        for x in args.other:
            print("Node:     %-20s (%s)" % (args.cluster + "-" + x,
                                            nodeips[x]))

    except Exception as e:
        print("Error: %s" % e)
        sys.exit(1)


if __name__ == '__main__':
    main()
```
