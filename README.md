# Infra with PXE/DHCP Server

I will use a PXE/DHCP Server to provision the nodes on their own VLAN and inject their initial configuration with Ignition or AutoInstall.

- PXE

  - [Matchbox](https://matchbox.psdn.io/)
  - [netboot.xyz](https://netboot.xyz/)

- The provisioned VM's will run:
  - Fedora CoreOS with Ignition
  - Ubuntu Server with AutoInstall
  - NixOS with something (NixOps)

## Testbed in Proxmox (eventually VLAN)

### Creatwe vmbr1 bridege

Since all these VMs will be on the same server, I will just create a separate bridge

Navigate to Datacenter -> hilbert -> System -> Network.
Add a New Linux Bridge:

Click "Create" and select "Linux Bridge".

- Provide a unique name for the bridge, such as vmbr1.
- Leave the "Bridge ports" field empty since this bridge will be used for isolated internal networking.
- leave it without an IP.

### Router vm

Name: pxe-router
ISO ubuntu-22.04.1-live-server.iso
Disk 32G
cores: 2
memory: 2G
network: vmbr0, then add vmbr1 after creation

- Install ubuntu server.
- Shut down and add the vmbr1 to the VM, reboot

## Matchbox Server
