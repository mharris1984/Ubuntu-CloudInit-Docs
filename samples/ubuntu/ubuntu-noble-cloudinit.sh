#! /bin/bash

VMID=8200
STORAGE=NetAppPool3
USER=adminmike

set -x
rm -f ubuntu-24.04-minimal-cloudimg-amd64.img
wget -q https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img
mv ubuntu-24.04-minimal-cloudimg-amd64.img ubuntu-22.04.qcow2
qemu-img resizeubuntu-22.04.qcow2 120G
sudo qm destroy $VMID11
sudo qm create $VMID --name "ubuntu-noble-template" --ostype l26 \
    --memory 4092 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --socket 1 --cores 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0
sudo qm importdisk $VMID ubuntu-22.04.qcow2 $STORAGE
sudo qm set $VMID --serial0 socket --vga serial0
sudo qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
sudo qm set $VMID --boot order=virtio0
sudo qm set $VMID --scsi1 $STORAGE:cloudinit

cat << EOF | sudo tee /var/lib/vz/snippets/ubuntu.yaml
#cloud-config
runcmd:
    - apt-get update
    - apt-get install -y qemu-guest-agent
    - systemctl enable ssh
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF
sudo qm set $VMID --cicustom "vendor=local:snippets/ubuntu.yaml"
sudo qm set $VMID --tags ubuntu-24.04,ubuntu-template,noble,cloudinit
sudo qm set $VMID --ciuser $USER
sudo qm set $VMID --sshkeys ~/.ssh/authorized_keys
sudo qm set $VMID --ipconfig0 ip=dhcp
sudo qm template $VMID
