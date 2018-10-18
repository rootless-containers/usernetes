FROM golang:1.11
ADD https://github.com/bazelbuild/bazel/releases/download/0.18.0/bazel-0.18.0-linux-x86_64 /usr/local/bin/bazel
RUN chmod +x /usr/local/bin/bazel
RUN git clone https://github.com/kubernetes/kubernetes.git /kubernetes
WORKDIR /kubernetes
ARG KUBERNETES_COMMIT
RUN git pull && git checkout ${KUBERNETES_COMMIT}
COPY ./patches/kubernetes /patches
# `git am` requires user info to be set
RUN git config user.email "nobody@example.com" && \
  git config user.name "Usernetes Build Script" && \
  git am /patches/* && git show --summary
