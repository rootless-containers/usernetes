FROM docker:18.09.0-rc1-dind
RUN apk --no-cache add bash make git
RUN git clone https://github.com/moby/moby.git /moby
WORKDIR /moby
ARG MOBY_COMMIT
RUN git pull && git checkout ${MOBY_COMMIT}
COPY ./patches/moby /patches
# `git am` requires user info to be set
RUN git config user.email "nobody@example.com" && \
  git config user.name "Usernetes Build Script" && \
  git am /patches/* && git show --summary
