output "controllers" {
  value = [for vm in proxmox_vm_qemu.k3s : { name = vm.name, ip=vm.default_ipv4_address } if contains(split(";", vm.tags), "controller")]
}

output "workers" {
  value = [for vm in proxmox_vm_qemu.k3s : { name = vm.name, ip=vm.default_ipv4_address } if contains(split(";", vm.tags), "worker")]
}

resource "local_file" "ansible_inventory" {
    filename = "../inventory/raclette/hosts.ini"
    content = templatefile("files/dynamic_inventory.tmpl", 
    {
        k3s_controllers = [for vm in proxmox_vm_qemu.k3s : { name = vm.name, ip=vm.default_ipv4_address } if contains(split(";", vm.tags), "controller")]
        k3s_workers = [for vm in proxmox_vm_qemu.k3s : { name = vm.name, ip=vm.default_ipv4_address } if contains(split(";", vm.tags), "worker")]
    })
}
