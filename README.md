# Infra with PXE/DHCP Server

I will use a PXE/DHCP Server to provision the nodes on their own VLAN and inject their initial configuration with Ignition or AutoInstall.

- PXE

  - [Matchbox](https://matchbox.psdn.io/)
  - [netboot.xyz](https://netboot.xyz/)

- The provisioned VM's will run:
  - Fedora CoreOS with Ignition
  - Ubuntu Server with AutoInstall
  - Debian with Preseed
  - NixOS with something (NixOps)

## TODO

- [ ] Convert pxe-router to docker/podman
- [ ] Do Ubuntu Server with AutoInstall
- [ ] tailscale on FCOS - not automated yet, because it requires a manual step
  - [ ] remove PasswordAuthentication=yes (and passwordhash) once tailscale working
- [ ] NixOS with NixOps

## Testbed in Proxmox (eventually VLAN)

### Create `vmbr1` bridge

Since all these VMs will be on the same server, I will just create a separate bridge

Navigate to Datacenter -> hilbert -> System -> Network.
Add a New Linux Bridge:

Click "Create" and select "Linux Bridge".

- Provide a unique name for the bridge, such as vmbr1.
- Leave the "Bridge ports" field empty since this bridge will be used for isolated internal networking.
- leave it without an IP.

## PXE-Router VM

Name: pxe-router
ISO ubuntu-22.04.1-live-server.iso
Disk 32G
cores: 2
memory: 2G
network: vmbr0, then add vmbr1 after creation

- Install ubuntu server.
- Shut down and add the vmbr1 to the VM, reboot

sudo emacs 00-installer-config.yaml

### Configure networking

```txt
# This is the network config written by 'subiquity'
network:
  ethernets:
    ens18:
      dhcp4: true
    ens19:
      dhcp4: false
      addresses: [192.168.100.1/24]  # This is an example. Adjust the IP address as needed.
  version: 2
```

```bash
sudo netplan apply
ip addr show ens19
```

Enable IP Forwarding

```bash
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-ipforward.conf
sudo sysctl -p /etc/sysctl.d/99-ipforward.conf
```

NAT with iptables

```bash
# Apply NAT rule
sudo iptables -t nat -A POSTROUTING -o ens18 -j MASQUERADE

# Install iptables-persistent to save the rule across reboots
sudo apt-get install iptables-persistent
```

confirm All is OK:

```bash
daniel@pxe-router:~$ cat /proc/sys/net/ipv4/ip_forward
1
daniel@pxe-router:~$ sudo iptables -t nat -L POSTROUTING -v
Chain POSTROUTING (policy ACCEPT 1 packets, 71 bytes)
 pkts bytes target     prot opt in     out     source               destination
    4   294 MASQUERADE  all  --  any    ens18   anywhere             anywhere
daniel@pxe-router:~$ ping -c 4 google.com
PING google.com (142.251.41.46) 56(84) bytes of data.
64 bytes from yyz12s08-in-f14.1e100.net (142.251.41.46): icmp_seq=1 ttl=114 time=11.2 ms

--- google.com ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3006ms
rtt min/avg/max/mdev = 9.622/10.023/11.180/0.668 ms

```

### Matchbox (Install)

We will install matchbox on the pxe-router VM.

Install:

```bash
wget https://github.com/poseidon/matchbox/releases/download/v0.10.0/matchbox-v0.10.0-linux-amd64.tar.gz
tar -xvf matchbox-v0.10.0-linux-amd64.tar.gz
sudo mv matchbox-v0.10.0-linux-amd64/matchbox /usr/local/bin/

# check
$ which matchbox
/usr/local/bin/matchbox
$ matchbox --version
v0.10.0
```

Create the matchbox directories:

```bash
sudo mkdir -p /etc/matchbox /var/lib/matchbox/assets
# /etc/matchbox is actually just for certs
```

Confirm the network for DHCP is `ens19`:

```bash
$ ip addr show ens19
# should be the one with the 192.168.100.1 address (as above)
```

Configure Matchbox:

```bash
sudo emacs /etc/systemd/system/matchbox.service
```

```txt
[Unit]
Description=Matchbox

[Service]
# we configure with ENV vars instead of exec args
# IP address and port Matchbox listens on
Environment="MATCHBOX_ADDRESS=192.168.100.1:8080"
# MATCHBOX_RPC_ADDRESS (gRPC API disabled by default - we won;t use it)
# log: debug or info
Environment="MATCHBOX_LOG_LEVEL=info"

ExecStart=/usr/local/bin/matchbox
User=root
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl restart matchbox.service

sudo systemctl status matchbox.service
# logs
sudo journalctl -u matchbox.service
sudo journalctl -u matchbox.service -f
```

### DHCP/DNS Setup: `dnsmasq`

Use `dnsmasq` to provide DHCP and DNS services to the PXE clients.
This requires turning off le DNSStubListener in systemd-resolved.

```bash
sudo apt install dnsmasq
sudo emacs /etc/dnsmasq.conf
```

`/etc/dnsmasq.conf`:

```txt
interface=ens19
dhcp-range=192.168.100.50,192.168.100.150,255.255.255.0,24h

# Custom DNS servers (Cloudflare)
## Use Cloudflare DNS
server=1.1.1.1
server=1.0.0.1
## Use Google DNS
# server=8.8.8.8
# server=8.8.4.4

# Optional: Increase the cache size for better performance
cache-size=1000

# PXE booting (Matchbox)
dhcp-boot=tag:ipxe,http://192.168.100.1:8080/boot.ipxe,192.168.100.1
dhcp-match=set:ipxe,175 # iPXE sends a DHCP option 175, match it

# Optional: Static DNS entries
# address=/example.local/192.168.100.10
```

Disable the system's DNS resolver in `/etc/systemd/resolved.conf`:

```txt
[Resolve]
DNSStubListener=no
```

Now restart the services

```bash
sudo systemctl restart systemd-resolved
sudo systemctl restart dnsmasq
```

### Get Feodra assets

- Go to <https://fedoraproject.org/coreos/download?stream=stable#arches>
- Download assets into `/var/lib/matchbox/assets/fedora-coreos/`
  - [using wget](./matchbox/assets/fedora-coreos/get-assets.sh)

### Configure Matchbox for PXE Booting

Prepare the assets directory: `/var/lib/matchbox/...`

```bash
sudo mkdir -p /var/lib/matchbox/profiles
sudo mkdir -p /var/lib/matchbox/groups
```

## Fedora CoreOS / Ignition

- Create a profile and group for fedora-coreos
  - [profiles/fedora-coreos.json](./matchbox/profiles/fedora-coreos.json)
  - [groups/fedora-coreos.json](./matchbox/groups/fedora-coreos.json)

FCC (Fedora CoreOS Config) is now called butane.

Here is the simplest possible Butane/Ignition file to get Fedora CoreOS installed:

[`simplest-fcos.yaml.bu`](./matchbox/assets/simplest-fcos.yaml.bu):

See butane docs: <https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/>.

To compile the butane file into an Ignition config, use the `butane` command:

```bash
# you can also use docker podman
brew install butane
butane --pretty --strict ./matchbox/assets/simplest-fcos.yaml.bu -o ./matchbox/assets/simplest-fcos.ign
```

Now copy the [`simplest-fcos.ign`](./matchbox/assets/simplest-fcos.ign) file
to `/var/lib/matchbox/assets/simplest-fcos.ign`:

### Test the PXE Boot

```bash
# watch matchbox logs
journalctl -u matchbox.service -f
# watch dnsmasq logs
journalctl -u dnsmasq.service -f
```

### Tailscale

See <https://techoverflow.net/2022/04/16/how-to-install-tailscale-on-fedora-coreos/>

```bash
sudo curl -o /etc/yum.repos.d/tailscale.repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo
sudo rpm-ostree install tailscale
# reboot
sudo systemctl reboot
# after reboot
sudo systemctl enable --now tailscaled
sudo tailscale up # --authkey tskey-xxxx
```

## Ubuntu Server / AutiInstall

See <https://ubuntu.com/server/docs/install/autoinstall>

NOT WORKING YET. We are able to boot the VM, but it is not getting the autoinstall config.

- Create a profile and group for ubuntu
  - [profiles/ubuntu.json](./matchbox/profiles/ubuntu.json)
  - [groups/ubuntu.json](./matchbox/groups/ubuntu.json)

## Debian / Preseed

- Create a profile and group for ubuntu
  - [profiles/ubuntu.json](./matchbox/profiles/debian.json)
  - [groups/ubuntu.json](./matchbox/groups/debian.json)
