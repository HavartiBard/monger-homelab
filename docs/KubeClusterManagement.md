Right now this is just a list of resources that I've found useful for managing Kubernetes clusters. I'll be adding more information as I learn more about the topic.

https://github.com/oobenland/terraform-proxmox-k3s/blob/main/docs/roll-node-pools.md


Manual install process:
```curl -sfL https://get.k3s.io | sh -```

verify install:
```systemctl status k3s```

Check default kube objects:
```sudo kubectl get all -n kube-system```

Check kubeconfig:
```sudo cat /etc/rancher/k3s/k3s.yaml```


Terraform notes: https://fredrickb.com/2023/08/05/setting-up-k3s-nodes-in-proxmox-using-terraform/#writing-the-terraform-configuration-for-the-vms