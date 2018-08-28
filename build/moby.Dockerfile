FROM docker:18.06-dind
RUN apk --no-cache add bash make git
ARG MOBY_COMMIT
RUN echo MOBY_COMMIT=${MOBY_COMMIT}
RUN git clone https://github.com/moby/moby.git /moby
WORKDIR /moby
RUN git checkout ${MOBY_COMMIT}
COPY ./patches/moby /patches
# `git am` requires user info to be set
RUN git config user.email "nobody@example.com" && \
  git config user.name "Usernetes Build Script" && \
  git am /patches/* && git show --summary
