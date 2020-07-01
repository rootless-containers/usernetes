#!/bin/bash
set -eu -o pipefail

function INFO() {
	echo -e "\e[104m\e[97m[INFO]\e[49m\e[39m $@"
}

function ERROR() {
	echo >&2 -e "\e[101m\e[97m[ERROR]\e[49m\e[39m $@"
}

function util::wait_for_pod() {
	name="$1"
	if ! timeout 60 sh -exc "until kubectl get pods -o json $name | jq -r \".status.phase\" | grep -x \"Running\" ;do sleep 10; done"; then
		ERROR "The $name pod is not running."
		set -x
		kubectl get pods -o wide $name
		kubectl get pods -o yaml $name
		exit 1
	fi
}

function smoketest_dns() {
	INFO "Installing CoreDNS"
	kubectl apply -f manifests/coredns.yaml

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
	if ! timeout 90 sh -exc "until [ \$(kubectl get pods --field-selector status.phase=Running -l run=dnstest -o name | wc -l) = "3" ]; do sleep 10; done"; then
		ERROR "Pods are not ready."
		set -x
		kubectl get pods -o wide
		kubectl get pods -o yaml
		exit 1
	fi

	INFO "FIXME: remove this sleep"
	sleep 10

	INFO "Connecting to dnstest-{0,1,2}.dnstest.default.svc.cluster.local"
	kubectl run -i --rm --image=alpine --restart=Never dnstest-shell -- sh -exc 'for f in $(seq 0 2); do wget -O- http://dnstest-${f}.dnstest.default.svc.cluster.local; done'

	INFO "Deleting Service \"dnstest\""
	kubectl delete service dnstest
	INFO "Deleting StatefulSet \"dnstest\""
	kubectl delete statefulset dnstest
}

function smoketest_limits() {
	INFO "Creating Pod \"test-limits\""
	kubectl apply -f hack/smoketest-manifests/test-limits.yaml
	util::wait_for_pod test-limits

	INFO "Testing memory limit (42 Mib)"
	[ "$(kubectl exec test-limits -- cat /sys/fs/cgroup/memory.max)" = "$((1024 * 1024 * 42))" ]

	INFO "Testing CPU limit (0.42 cores)"
	[ "$(kubectl exec test-limits -- cat /sys/fs/cgroup/cpu.max)" = "42000 100000" ]

	INFO "Deleting Pod \"test-limits\""
	kubectl delete pod test-limits
}
