FROM docker:test-dind
RUN apk --no-cache add bash make git
ARG MOBY_REPO
ARG MOBY_COMMIT
RUN echo MOBY_REPO=${MOBY_REPO} MOBY_COMMIT=${MOBY_COMMIT}
RUN git clone ${MOBY_REPO} /moby
WORKDIR /moby
RUN git checkout ${MOBY_COMMIT}
