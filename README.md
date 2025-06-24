# OpenStack VM deployment with Terraform, Ansible, and Kubernetes monitoring 

## Objective

Create a virtual infrastructure in OpenStack using Terraform and Ansible, then configure a Kubernetes cluster with monitoring.

### Insfrastructure goals

* 3 Ubuntu 22.04 virtual machines
* Shared internal network
* One external (floating) IP
* Port forwarding to access each VM via SSH

### Kubernetes and monitoring goals

* Install Kubernetes cluster (kubeadm)
  * VM-1 — control-plane
  * VM-2 and VM-3 — worker nodes
* Deploy Prometheus and Grafana
* Set up ingress (nginx)
* Provide HTTPS access to Prometheus and Grafana interfaces

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
├── scripts/
│   ├── k8s_base.sh
│   └── k8s_master.sh
└── .gitignore

```

---

## Setup

### 1. Upload SSH keypair to the OpenStack project.

### 2. Copy and edit the `terraform.tfvars.example` file:

```hcl
external_network_id = "your_external_network_id"
keypair_name        = "your_keypair_name"
````

### 3. Make sure private key file is available locally.
   
### 4. In the Ansible `inventory` file, define VM-1:

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

## Kubernetes cluster setup

### 1. Launch Kubernetes

On all VMs run the script `scripts/k8s_base.sh`:

```bash
sudo bash ./scripts/k8s_base.sh
```

On VM-1 (master node) run `scripts/k8s_master.sh`:

```bash
sudo bash ./scripts/k8s_master.sh
```

On VM-1, generate the join command:

```bash
kubeadm token create --print-join-command
```

Copy the output and run it on VM-2 and VM-3 (worker nodes).

Verify that all nodes have joined the cluster (from VM-1):

```bash
kubectl get nodes
```

---

## Monitoring setup

### 2. Install Helm

On VM-1, install Helm:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 3. Add Helm repositories

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

### 4. Install ingress-nginx controller

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

Verify that the ingress controller is running:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### 5. Generate self-signed TLS certificate

On VM-1, create a self-signed certificate for local domains:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=grafana.local" \
  -addext "subjectAltName=DNS:grafana.local,DNS:prometheus.local"
```

### 6. Create Kubernetes TLS secret

```bash
kubectl create secret tls monitoring \
  --cert=tls.crt --key=tls.key \
  -n kube-prometheus-stack
```

### 7. Install Prometheus and Grafana

Create a file monitoring-values.yaml with ingress and TLS configuration like `/scripts/ingress.yaml`.

Install the monitoring stack:

```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -f monitoring-values.yaml \
  --namespace kube-prometheus-stack --create-namespace
```

Verify deployment:

```bash
kubectl get pods -n kube-prometheus-stack
```

### 8. Configure local DNS and access the dashboards

On local machine add entries to `/etc/hosts`:

```bash
<EXTERNAL_IP> grafana.local prometheus.local
```

Now you can access:
* https://grafana.local
* https://prometheus.local

### 9. Default credentials for Grafana:

* Login: admin
* Password: 

  ```bash
  kubectl get secret --namespace kube-prometheus-stack kibe-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
  ```

## Conclusion

As a result, we have a Kubernetes cluster running on three Ubuntu VMs in OpenStack, with VM-1 as the control plane and VM-2, VM-3 as worker nodes. Prometheus and Grafana are deployed for monitoring, exposed via Ingress-NGINX with HTTPS access using a self-signed TLS certificate.
