# Bare Metal Kubernetes Installation with Metal³ (CAPM3)

This guide describes how to provision a Kubernetes cluster on bare metal using **Metal³** and **Cluster API Provider Metal3 (CAPM3)**.

---

## 1. Architecture Overview

| Role | Count | Purpose |
|------|-------|---------|
| **Management Cluster Node** | 1 | Runs Cluster API, Metal³ components, Ironic, etc. |
| **Control Plane Node** | 1 | Kubernetes control plane for the workload cluster |
| **Worker Node** | 1 | Runs application workloads |

---

## 2. Prerequisites

### Required Tools

Install these on the **management node**:

- Container runtime: docker or podman  
- Local Kubernetes cluster (if needed): kind or minikube  
- kubectl  
- clusterctl  
- htpasswd  
- virsh and virt-install (for virtualized setups)

---

## 3. Network Topology

### Management + BMC Network  
**192.168.3.0/24**

- DHCP-enabled router  
- Used for management, BMC, and iPXE boot  

### Provisioning Network  
**172.22.0.0/24**

- No router connected  
- Used for provisioning and Ironic traffic  

### Host Interfaces

Each host requires **three interfaces**:

| Interface | Network | Purpose |
|----------|---------|---------|
| NIC 1 | 172.22.0.0/24 | Provisioning |
| NIC 2 | 192.168.3.0/24 | Cluster communication |
| NIC 3 | BMC | Out-of-band management |

---

## 4. Image Server Setup

Metal³ requires an HTTP server hosting OS images. We use an nginx container.

### Download Images

```bash
#!/usr/bin/env bash
set -e

mkdir -p disk-images
pushd disk-images

wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS
sha256sum --ignore-missing -c SHA256SUMS

wget https://artifactory.nordix.org/artifactory/metal3/images/k8s_v1.34.1/CENTOS_10_NODE_IMAGE_K8S_v1.34.1.qcow2
sha256sum CENTOS_10_NODE_IMAGE_K8S_v1.34.1.qcow2 > CENTOS_10_NODE_IMAGE_K8S_v1.34.1.qcow2.sha256sum

qemu-img convert -f qcow2 -O raw \
  CENTOS_10_NODE_IMAGE_K8S_v1.34.1.qcow2 \
  CENTOS_10_NODE_IMAGE_K8S_v1.34.1.raw

sha256sum CENTOS_10_NODE_IMAGE_K8S_v1.34.1.raw > CENTOS_10_NODE_IMAGE_K8S_v1.34.1.raw.sha256sum

wget https://tarballs.opendev.org/openstack/ironic-python-agent/dib/ipa-centos9-master.tar.gz

popd || exit

# Start Image Server
docker run --name image-server --rm -d -p 80:8080 \
  -v "$(pwd)/disk-images:/usr/share/nginx/html" nginxinc/nginx-unprivileged
``` 
## 5. Infrastructure Setup
```bash
./create-infra.sh
```
Update IP configuration inside:
- ironic/certificate.yaml
- ironic/ironic.yaml

## 6. Register Bare Metal Hosts
Edit *baremetal-config.yaml* with:
- BMC address
- Credentials
- MAC address
- Image URL and checksum
```bash
kubectl apply -f baremetal-config.yaml
```
Check status:
```bash
kubectl get bmh
```
## 7. Create Workload Cluster
Set variables in *.env*, then:
```bash
source .env
kubectl apply -f cluster-metal.yaml
```
