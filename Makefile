# targets prefixed with underscore are not intended be invoked by human

.DEFAULT_GOAL := binaries
IMAGE=usernetes

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
	./hack/smoketest.sh $(IMAGE) default-docker
	./hack/smoketest.sh $(IMAGE) default-containerd
	./hack/smoketest.sh $(IMAGE) default-crio

up: image
	docker-compose up -d
	echo "To use kubectl: export KUBECONFIG=$(shell pwd)/config/localhost.kubeconfig"

down:
	docker-compose down

_artifact:
	rm -rf _artifact
	mkdir _artifact
	tar --transform 's@^\.@usernetes@' --exclude-vcs --exclude=./_artifact -cjvf ./_artifact/usernetes-x86_64.tbz .
	sha256sum _artifact/* | tee _artifact/SHA256SUM

_upload-artifact-to-transfer-sh:
	echo "Uploading usernetes-x86_64.tbz"
	curl --progress-bar --upload-file _artifact/usernetes-x86_64.tbz https://transfer.sh/usernetes-x86_64.tbz
	echo -e "\nUploading SHA256SUM"
	curl --progress-bar --upload-file _artifact/SHA256SUM https://transfer.sh/SHA256SUM
	echo -e "\nThe transfer.sh URL will expire in 14 days."

clean:
	rm -rf _artifact bin

_ci: image _test _binaries _artifact _upload-artifact-to-transfer-sh

.PHONY: binaries _binaries image test _test up down _artifact _upload-artifact-to-transfer-sh clean _ci
