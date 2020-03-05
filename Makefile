# targets prefixed with underscore are not intended be invoked by human

.DEFAULT_GOAL := binaries
IMAGE=rootlesscontainers/usernetes

binaries: image _binaries

_binaries:
	rm -rf bin
	$(eval cid := $(shell docker create $(IMAGE)))
	docker cp $(cid):/home/user/usernetes/bin ./bin
	docker rm $(cid)

image:
ifeq ($(DOCKER_BUILDKIT),1)
	./hack/translate-dockerfile-runopt-directive.sh < Dockerfile | docker build -t $(IMAGE) -f - $(DOCKER_BUILD_FLAGS) .
else
	docker build -t $(IMAGE) $(DOCKER_BUILD_FLAGS) .
endif

test: image _test

_test:
	./hack/smoketest.sh u7s-test-containerd $(IMAGE) --cri=containerd
	./hack/smoketest.sh u7s-test-crio $(IMAGE) --cri=crio

up: image
	docker-compose up -d
	echo "To use kubectl: export KUBECONFIG=$(shell pwd)/config/localhost.kubeconfig"

down:
	docker-compose down

artifact: binaries _artifact

_artifact:
	rm -rf _artifact _SHA256SUM
	mkdir _artifact
	tar --transform 's@^\.@usernetes@' --exclude-vcs --exclude=./_artifact -cjvf ./_artifact/usernetes-x86_64.tbz .
	(cd _artifact ; sha256sum * > ../_SHA256SUM; mv ../_SHA256SUM ./SHA256SUM)
	cat _artifact/SHA256SUM

clean:
	rm -rf _artifact bin

.PHONY: binaries _binaries image test _test up down artifact _artifact clean
