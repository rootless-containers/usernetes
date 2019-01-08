.DEFAULT_GOAL := binaries
IMAGE=usernetes

binaries: image _binaries

_binaries:
	rm -rf bin
	$(eval cid := $(shell docker create $(IMAGE)))
	docker cp $(cid):/home/user/usernetes/bin ./bin
	docker rm $(cid)

artifact: binaries _artifact

_artifact:
	rm -rf _artifact
	mkdir _artifact
	tar --transform 's@^\.@usernetes@' --exclude-vcs --exclude=./_artifact -cjvf ./_artifact/usernetes-x86_64.tbz .
	sha256sum _artifact/* | tee _artifact/SHA256SUM

image:
ifeq ($(DOCKER_BUILDKIT),1)
	./hack/translate-dockerfile-runopt-directive.sh < Dockerfile | docker build -t $(IMAGE) -f - $(DOCKER_BUILD_FLAGS) .
else
	docker build -t $(IMAGE) $(DOCKER_BUILD_FLAGS) .
endif

# test is still flaky, not executed on CI
test:
	./hack/smoketest.sh $(IMAGE) default-docker
	./hack/smoketest.sh $(IMAGE) default-containerd
	./hack/smoketest.sh $(IMAGE) default-crio

upload-artifact-to-transfer-sh:
	echo "Uploading usernetes-x86_64.tbz"
	curl --progress-bar --upload-file _artifact/usernetes-x86_64.tbz https://transfer.sh/usernetes-x86_64.tbz
	echo -e "\nUploading SHA256SUM"
	curl --progress-bar --upload-file _artifact/SHA256SUM https://transfer.sh/SHA256SUM
	echo -e "\nThe transfer.sh URL will expire in 14 days."

clean:
	rm -rf _artifact bin

ci: artifact upload-artifact-to-transfer-sh

.PHONY: binaries _binaries artifact image upload-artifact-to-transfer-sh clean ci
