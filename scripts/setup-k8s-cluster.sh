echo "Creating master and worker nodes in parallel................."
parallel -j 4 multipass launch --mem 4G --cpus 2 --disk 10G --verbose --name ::: master-node worker-node-1 worker-node-2
echo "Done................."
echo
echo


echo "Installing and configuring kubernetes components on the Master Node..................."
multipass shell master-node < setup-master-node.sh
echo "Done................."
echo
echo


echo "Installing and configuring kubernetes components on Worker Nodes..................."
multipass shell worker-node-1 < setup-worker-node-1.sh
multipass shell worker-node-2 < setup-worker-node-2.sh
echo "Done................."
echo
echo

echo "Extracting the join command for worker nodes to join master node............................"
join_command=$(multipass exec master-node -- bash -c  "kubeadm token create --print-join-command")
echo "Done................."
echo
echo

echo "Worker node 1 is joining master node on the cluster............................"
multipass exec worker-node-1 -- bash -c "sudo $join_command"
echo "Done.................."
echo
echo

echo "Worker node 2 is joining master node on the cluster.............................."
multipass exec worker-node-2 -- bash -c "sudo $join_command" 
echo "Done.................."
echo
echo


echo "Extracting kubeconfig of the cluster from master node................"
multipass exec master-node -- bash -c "sudo cat /etc/kubernetes/admin.conf" > k8s-cluster.yaml
export KUBECONFIG=$PWD/k8s-cluster.yaml
echo "Done.................."
echo
echo

echo "Checking cluster nodes are ready scheduling pods on them...................."
########
while true; do
  if kubectl wait --for=condition=Ready --timeout=60s nodes --all  2>&1 >/dev/null; then
    job_result=0
    break
  fi

  if kubectl wait --for=condition=NotReady --timeout=60s nodes --all 2>&1 > /dev/null; then
    job_result=1
    break
  fi
done

if [[ $job_result -eq 1 ]]; then
    echo "Worker Nodes failed to sync with Master Node .. Aborting............."
    exit 1
else
    kubectl get nodes -o wide
fi
echo "Done.................."
echo
echo
#########


echo "Installing Metrics Server to collect basic metrics from cluster............................."
# install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Metrics server pod fails to start as Kubelet certificate needs to be signed by Cluster Certificate Authority, not done in this setup-  NOT recommended for production
# Disable certificate validation by passing --kubelet-insecure-tls to Metrics Server deploymnet as the setup does not involve certficate signing by Cluster Certificate Authority
kubectl patch deployment metrics-server -n kube-system --type 'json' -p '[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Checking if metrics-server deployment is available 
while true; do
  if kubectl wait --for=condition=available --timeout=600s deployment metrics-server -n kube-system 2>&1 >/dev/null; then
    job_result=0
    break
  fi

  if kubectl wait --for=condition=available=false --timeout=600s deployment metrics-server -n kube-system 2>&1 >/dev/null; then
    job_result=1
    break
  fi
  sleep 3
done

if [[ $job_result -eq 1 ]]; then
    echo "Metrics server deployment failed. Aborting............"
    exit 1
else
    # Allow the metrics-server service to become ready for serving metrics queris
    sleep 10
    # Display basic node and pod mertrics
    kubectl top nodes 
    kubectl top pods -A
fi

echo "Done.................."

echo
echo
##################

echo "Deploying a sample nginx server in default namespace for testing the k8s cluster............"
kubectl create deployment nginx --image=nginx --replicas=3

while true; do
  if kubectl wait --for=condition=available --timeout=60s deployment nginx 2>&1 >/dev/null; then
    job_result=0
    break
  fi

  if kubectl wait --for=condition=available=false --timeout=60s deployment nginx -n 2>&1 >/dev/null; then
    job_result=1
    break
  fi
done

if [[ $job_result -eq 1 ]]; then
    echo "Failed to deploy nginx server on the cluster............"
    exit 1
else
    kubectl get deployment nginx 
    kubectl get pods -o wide
fi
echo "Done.................."

echo
echo
