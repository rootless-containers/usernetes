#!/bin/bash
set -eu -o pipefail

INFO() {
	echo -e "\e[104m\e[97m[INFO]\e[49m\e[39m $@"
}

INFO "Waiting for nodes to be ready"
for node in $(kubectl get node -o name); do
	kubectl wait --timeout=5m --for=condition=ready "${node}"
done

function smoketest_dns() {
	INFO "Creating StatefulSet \"dnstest\" and headless Service \"dnstest\""
	kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: dnstest
  labels:
    run: dnstest
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: "http"
    protocol: "TCP"
    port: 80
    targetPort: 80
  selector:
    run: dnstest
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: dnstest
spec:
  serviceName: dnstest
  selector:
    matchLabels:
      run: dnstest
  replicas: 3
  template:
    metadata:
      labels:
        run: dnstest
    spec:
      containers:
      - name: dnstest
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF
	INFO "Waiting for 3 replicas to be ready"
	kubectl rollout status --timeout=5m statefulset

	INFO "Connecting to dnstest-{0,1,2}.dnstest.default.svc.cluster.local"
	kubectl run -i --rm --image=alpine --restart=Never dnstest-shell -- sh -exc 'for f in $(seq 0 2); do wget -O- http://dnstest-${f}.dnstest.default.svc.cluster.local; done'

	INFO "Deleting Service \"dnstest\""
	kubectl delete service dnstest
	INFO "Deleting StatefulSet \"dnstest\""
	kubectl delete statefulset dnstest
}

smoketest_dns
