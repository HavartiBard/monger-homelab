{{ Proxmox Template Creation }}

It's important to set the storage location to `isos` initially so it is on the shared NFS mount.  In our terraform we will override this to local-zfs for each proxmox node.

These commands are run on the proxmox node with access to the cloud image and prepare the image for qemu and templatation.
```bash
sudo virt-customize -a oracular-server-cloudimg-amd64.img --install qemu-guest-agent 
sudo virt-customize -a oracular-server-cloudimg-amd64.img --run-command "echo -n > /etc/machine-id"
```

These commands create the VM template on the proxmox node.
```bash
sudo qm create 8001 --name ubuntu-2404-cloudinit --ostype l26 --memory 2048 --agent 1 --cores 2  --sockets 1 --vga serial0 --serial0 socket --net0 virtio,bridge=vmbr0 --bios ovmf --machine q35 --efidisk0 isos:0,pre-enrolled-keys=0 --scsihw virtio-scsi-pci --tags ubuntu-template,24.04,cloudinit --ciuser james --cipassword $(openssl passwd -6 ******) --sshkeys ~/.ssh/authorized_keys --ipconfig0 ip=dhcp

sudo qm importdisk 8001 /mnt/pve/isos/template/iso/oracular-server-cloudimg-amd64.img isos
sudo qm set 8001 --virtio0 isos:8001/vm-8001-disk-1.raw
sudo qm set 8001 --ide2 isos:cloudinit

sudo qm template 8001
```

Possibly look at building an ansible playbook to do all of this in the future, ref: https://fredrickb.com/2023/08/05/setting-up-k3s-nodes-in-proxmox-using-terraform/#writing-the-terraform-configuration-for-the-vms
