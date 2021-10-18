FROM tensorflow/tensorflow:latest-gpu-jupyter

USER root

ARG DOCKER_USER="docker_user"
ARG DOCKER_UID="1000"
ARG DOCKER_GID="100"

ENV SHELL=/bin/bash \
    DOCKER_USER=$DOCKER_USER \
    DOCKER_UID=$DOCKER_UID \
    DOCKER_GID=$DOCKER_GID

ENV HOME=/home/$DOCKER_USER

COPY apt.txt /tmp/
RUN useradd -m -s /bin/bash -N -u $DOCKER_UID $DOCKER_USER && \
    chmod g+w /etc/passwd && \
    apt-get update -y && \
    xargs -a /tmp/apt.txt apt-get install -y && \
    apt-get clean && \
    rm /tmp/apt.txt

USER $DOCKER_UID

WORKDIR $HOME
