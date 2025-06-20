# OpenStack VM Deployment with Terraform and Ansible

## Objective

Create a virtual infrastructure in OpenStack using Terraform:

- 3 Ubuntu 22.04 virtual machines
- Shared internal network
- One external (floating) IP
- Port forwarding to access each VM via SSH

---

## Project structure

```

openstack-vm-deployment/
├── terraform/
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   └── cloud-init-static-ip/
│       ├── cloud-init-static-ip-vm-1.yaml
│       ├── cloud-init-static-ip-vm-2.yaml
│       └── cloud-init-static-ip-vm-3.yaml
├── ansible/
│   ├── ansible.cfg
│   ├── inventory
│   └── playbook.yml
└── .gitignore

````

---

## Setup

1. Upload SSH keypair to the OpenStack project.

2. Copy and edit the `terraform.tfvars.example` file:

```hcl
external_network_id = "your_external_network_id"
keypair_name        = "your_keypair_name"
````

3. Make sure private key file is available locally.
   
4. In the Ansible `inventory` file, define VM-1:

```ini
[vm]
<EXTERNAL_IP> ansible_user=ubuntu
```

---

## Deployment steps

### 1. Deploy infrastructure with Terraform:

```bash
cd terraform/
terraform init
terraform apply
```

Terraform will create:

* Internal network and subnet
* Router and external gateway
* 3 VMs with internal IPs
* One floating IP with port forwarding:

  * 2201 → VM-1 (192.168.100.101)
  * 2202 → VM-2 (192.168.100.102)
  * 2203 → VM-3 (192.168.100.103)

### 2. Configure VMs using Ansible:

```bash
cd ../ansible
ansible-playbook playbook.yml --private-key=<KEY_FILE>
```

The playbook sets up iptables rules to enable port forwarding from the external IP to the internal IPs of VM-2 and VM-3.

---

## SSH access

Use the private key associated with the OpenStack keypair to connect:

```bash
chmod 600 <KEY_FILE>

ssh -i <KEY_FILE> -p 2201 ubuntu@<EXTERNAL_IP>  # VM-1
ssh -i <KEY_FILE> -p 2202 ubuntu@<EXTERNAL_IP>  # VM-2
ssh -i <KEY_FILE> -p 2203 ubuntu@<EXTERNAL_IP>  # VM-3
```

---

