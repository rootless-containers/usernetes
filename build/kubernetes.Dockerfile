FROM golang:latest
ADD https://github.com/bazelbuild/bazel/releases/download/0.15.2/bazel-0.15.2-linux-x86_64 /usr/local/bin/bazel
RUN chmod +x /usr/local/bin/bazel
ARG KUBERNETES_REPO
ARG KUBERNETES_COMMIT
RUN echo KUBERNETES_REPO=${KUBERNETES_REPO} KUBERNETES_COMMIT=${KUBERNETES_COMMIT}
RUN git clone ${KUBERNETES_REPO} /kubernetes
WORKDIR /kubernetes
RUN git checkout ${KUBERNETES_COMMIT}
