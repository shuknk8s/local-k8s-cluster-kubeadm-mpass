parallel -j 4 multipass launch --mem 4G --cpus 2 --disk 10G --verbose --name ::: master-node worker-node-1 worker-node-2

multipass shell master-node < setup-master-node.sh 
multipass shell worker-node-1 < setup-worker-node-1.sh &
multipass shell worker-node-2 < setup-worker-node-2.sh 

join_command=$(multipass exec master-node -- bash -c  "kubeadm token create --print-join-command")

multipass exec worker-node-1 -- bash -c "sudo $join_command" 
multipass exec worker-node-2 -- bash -c "sudo $join_command" 

multipass exec master-node -- bash -c "sudo cat /etc/kubernetes/admin.conf" > k8s-cluster.yaml
export KUBECONFIG=$PWD/k8s-cluster.yaml
kubectl get nodes -o wide -w
# install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Metrics server pod fails to start with default secure tls - add --kubelet-insecure-tls flag - NOT recommended for production
kubectl patch deployment metrics-server -n kube-system --type 'json' -p '[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
sleep 20
kubectl get deployment metrics-server -n kube-system -w
kubectl top nodes 
kubectl top pods -A
