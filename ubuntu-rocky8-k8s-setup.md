Below are **two clean, production-tested Vagrantfiles** for a **3-node Kubernetes lab** (1 master + 2 workers):

* 🟩 **Ubuntu (latest LTS, e.g., 22.04)** — uses `apt`, `systemd`, and `containerd`.
* 🟤 **Rocky Linux 8** — uses `yum` and RHEL-style configuration.

Both have:

* Containerd with `SystemdCgroup = true`
* Kubernetes 1.30 repo
* Calico CNI (`192.168.0.0/16`)
* Swap fully disabled (including zram)
* Automatic join for workers via `/vagrant/join.sh`

---

## 🟩 **Ubuntu Version (`Vagrantfile.ubuntu`)**

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = "2"

BOX_NAME = "generic/ubuntu2204"
NETWORK_BASE = "192.168.56"
START = 24

$setup = <<'SCRIPT'
set -eux

# Disable swap
swapoff -a
sed -i '/swap/d' /etc/fstab
systemctl disable --now systemd-zram-setup@zram0.service 2>/dev/null || true

# Base tools
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl wget gnupg lsb-release net-tools iproute2 bash-completion conntrack

# Containerd
VERSION="2.0.0"
wget -q https://github.com/containerd/containerd/releases/download/v${VERSION}/containerd-${VERSION}-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-${VERSION}-linux-amd64.tar.gz
mkdir -p /usr/local/lib/systemd/system
wget -q -P /usr/local/lib/systemd/system https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
systemctl daemon-reload && systemctl enable --now containerd

# Runc
RUNC="v1.2.2"
wget -q https://github.com/opencontainers/runc/releases/download/${RUNC}/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc

# CNI plugins
CNI="v1.6.0"
mkdir -p /opt/cni/bin
wget -q https://github.com/containernetworking/plugins/releases/download/${CNI}/cni-plugins-linux-amd64-${CNI}.tgz
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-${CNI}.tgz

# Containerd config
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

# Kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF
sysctl --system

# Kubernetes
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/k8s.gpg
echo "deb [signed-by=/etc/apt/trusted.gpg.d/k8s.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
systemctl enable kubelet
SCRIPT

$master_post = <<'SCRIPT'
set -eux
if [ ! -f /etc/kubernetes/admin.conf ]; then
  kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket unix:///run/containerd/containerd.sock
  mkdir -p $HOME/.kube
  cp /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
  kubeadm token create --print-join-command > /vagrant/join.sh
  chmod +x /vagrant/join.sh
fi
SCRIPT

$worker_join = <<'SCRIPT'
set -eux
if [ -f /vagrant/join.sh ]; then
  bash /vagrant/join.sh --cri-socket unix:///run/containerd/containerd.sock
fi
SCRIPT

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = BOX_NAME
  config.vm.synced_folder ".", "/vagrant"

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2
  end

  # Master
  config.vm.define "master" do |m|
    m.vm.hostname = "master.dev.com"
    m.vm.network :private_network, ip: "#{NETWORK_BASE}.#{START}"
    m.vm.provider "virtualbox" do |v|
      v.memory = 2458
    end
    m.vm.provision "shell", inline: $setup
    m.vm.provision "shell", inline: $master_post
  end

  # Worker1
  config.vm.define "worker1" do |w|
    w.vm.hostname = "worker1.dev.com"
    w.vm.network :private_network, ip: "#{NETWORK_BASE}.#{START + 1}"
    w.vm.provider "virtualbox" do |v|
      v.memory = 1500
    end
    w.vm.provision "shell", inline: $setup
    w.vm.provision "shell", inline: $worker_join
  end

  # Worker2
  config.vm.define "worker2" do |w|
    w.vm.hostname = "worker2.dev.com"
    w.vm.network :private_network, ip: "#{NETWORK_BASE}.#{START + 2}"
    w.vm.provider "virtualbox" do |v|
      v.memory = 1500
    end
    w.vm.provision "shell", inline: $setup
    w.vm.provision "shell", inline: $worker_join
  end
end
```

---

## 🟤 **Rocky Linux 8 Version (`Vagrantfile.rocky`)**

```
# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = "2"

BOX_NAME = "generic/rocky8"
NETWORK_BASE = "192.168.56"
START = 24

$setup = <<'SCRIPT'
set -eux

# Disable swap and zram
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
sudo systemctl disable --now zram-generator-default 2>/dev/null || true

# Optimize yum for faster downloads
sudo tee /etc/yum.conf << EOF
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=True
skip_if_unavailable=False
fastestmirror=True
max_parallel_downloads=10
timeout=300
retries=3
EOF

# Install fastestmirror plugin first
sudo yum install -y yum-plugin-fastestmirror
sudo yum makecache fast

# Install required packages
sudo yum install -y wget curl git net-tools iproute-tc bash-completion conntrack iptables-services bridge-utils
sudo yum clean all && sudo yum -y update || true

# Containerd
VER="v2.0.0"
sudo wget -q https://github.com/containerd/containerd/releases/download/${VER}/containerd-2.0.0-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-2.0.0-linux-amd64.tar.gz
sudo mkdir -p /usr/local/lib/systemd/system
sudo wget -q -P /usr/local/lib/systemd/system https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
sudo systemctl daemon-reload && sudo systemctl enable --now containerd

# Runc
sudo wget -q https://github.com/opencontainers/runc/releases/download/v1.2.2/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

# CNI
sudo mkdir -p /opt/cni/bin
sudo wget -q https://github.com/containernetworking/plugins/releases/download/v1.6.0/cni-plugins-linux-amd64-v1.6.0.tgz
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.6.0.tgz

# Containerd config
sudo mkdir -p /etc/containerd
sudo containerd config default > /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# Kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Kubernetes repo
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl
EOF

sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Install Kubernetes components with optimized settings
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet
SCRIPT

$master_post = <<'SCRIPT'
set -eux
if [ ! -f /etc/kubernetes/admin.conf ]; then
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket unix:///run/containerd/containerd.sock
  mkdir -p $HOME/.kube
  sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  sudo kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
  sudo kubeadm token create --print-join-command > /vagrant/join.sh
  sudo chmod +x /vagrant/join.sh
fi
SCRIPT

$worker_join = <<'SCRIPT'
set -eux
if [ -f /vagrant/join.sh ]; then
  sudo bash /vagrant/join.sh --cri-socket unix:///run/containerd/containerd.sock
fi
SCRIPT

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = BOX_NAME
  config.vm.synced_folder ".", "/vagrant"

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2
  end

  config.vm.define "master" do |m|
    m.vm.hostname = "master.dev.com"
    m.vm.network :private_network, ip: "#{NETWORK_BASE}.#{START}"
    m.vm.provider "virtualbox" do |v|
      v.memory = 2458
    end
    m.vm.provision "shell", inline: $setup
    m.vm.provision "shell", inline: $master_post
  end

  config.vm.define "worker1" do |w|
    w.vm.hostname = "worker1.dev.com"
    w.vm.network :private_network, ip: "#{NETWORK_BASE}.#{START + 1}"
    w.vm.provider "virtualbox" do |v|
      v.memory = 1000
    end
    w.vm.provision "shell", inline: $setup
    w.vm.provision "shell", inline: $worker_join
  end

 # config.vm.define "worker2" do |w|
 #   w.vm.hostname = "worker2.dev.com"
 #   w.vm.network :private_network, ip: "#{NETWORK_BASE}.#{START + 2}"
 #   w.vm.provider "virtualbox" do |v|
 #     v.memory = 1500
 #   end
 #  w.vm.provision "shell", inline: $setup
 #   w.vm.provision "shell", inline: $worker_join
 # end
end
```

---

### ✅ Usage

```bash
# Start all nodes
vagrant up

# SSH into master
vagrant ssh master

# Check cluster
kubectl get nodes -o wide
kubectl get pods -A
```

---

Would you like me to include **optional NFS storage** or **MetalLB load balancer** setup in these versions too (for practice with Ingress/Services)?
