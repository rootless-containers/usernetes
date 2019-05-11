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
	./hack/smoketest.sh $(IMAGE) default-docker
	./hack/smoketest.sh $(IMAGE) default-containerd
	./hack/smoketest.sh $(IMAGE) default-crio

up: image
	docker-compose up -d
	echo "To use kubectl: export KUBECONFIG=$(shell pwd)/config/localhost.kubeconfig"

down:
	docker-compose down

_artifact:
	rm -rf _artifact _SHA256SUM
	mkdir _artifact
	tar --transform 's@^\.@usernetes@' --exclude-vcs --exclude=./_artifact -cjvf ./_artifact/usernetes-x86_64.tbz .
	(cd _artifact ; sha256sum * > ../_SHA256SUM; mv ../_SHA256SUM ./SHA256SUM)

_upload-artifact:
	echo "Uploading usernetes-x86_64.tbz"
	curl --retry 10 -F "file=@_artifact/usernetes-x86_64.tbz" https://file.io
	echo -e "\nUploading SHA256SUM"
	curl --retry 10 -F "file=@_artifact/SHA256SUM" https://file.io
	echo -e "\n"

clean:
	rm -rf _artifact bin

_ci: image _test _binaries _artifact _upload-artifact

.PHONY: binaries _binaries image test _test up down _artifact _upload-artifact clean _ci
