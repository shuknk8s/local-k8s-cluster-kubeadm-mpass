#multipass launch --name master-node --mem 4G --cpus 2 --disk 20G --verbose

#multipass shell master-node << EOF 
sudo -i
apt-get upgrade -y
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl

curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" |  tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
#apt-get install -y kubeadm=1.22.4-00 kubelet=1.22.4-00 kubectl=1.22.4-00
apt-get install -y kubeadm kubelet kubectl
apt-mark hold kubelet kubeadm kubectl

apt-get install containerd -y
mkdir -p /etc/containerd
containerd config default  /etc/containerd/config.toml
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
sysctl --system
modprobe overlay
modprobe br_netfilter
hostnamectl set-hostname master
swapoff -a
echo '1' > /proc/sys/net/ipv4/ip_forward
kubeadm init
exit
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
#EOF
