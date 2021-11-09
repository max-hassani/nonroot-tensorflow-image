FROM tensorflow/tensorflow:latest-gpu

USER root

ARG DOCKER_USER="docker_user"
ARG DOCKER_UID="1000"
ARG DOCKER_GID="100"

ENV SHELL=/bin/bash \
    DOCKER_USER=$DOCKER_USER \
    DOCKER_UID=$DOCKER_UID \
    DOCKER_GID=$DOCKER_GID \
    CONDA_DIR=/opt/conda \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

ENV PATH="${CONDA_DIR}/bin:${PATH}" 

ENV HOME=/home/$DOCKER_USER

COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc && \
   # Add call to conda init script see https://stackoverflow.com/a/58081608/4413446
   echo 'eval "$(command conda shell.bash hook 2> /dev/null)"' >> /etc/skel/.bashrc

COPY apt.txt /tmp/
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    useradd -m -s /bin/bash -N -u $DOCKER_UID $DOCKER_USER && \
    mkdir -p "${CONDA_DIR}" && \
    chown "${DOCKER_USER}:${DOCKER_GID}" "${CONDA_DIR}" && \
    chmod g+w /etc/passwd && \
    apt-get update -y && \
    xargs -a /tmp/apt.txt apt-get install -y && \
    apt-get clean && \
    rm /tmp/apt.txt && \
    fix-permissions "${HOME}" && \
    fix-permissions "${CONDA_DIR}"

USER ${DOCKER_UID}

ARG PYTHON_VERSION=default

WORKDIR /tmp
ARG CONDA_MIRROR=https://github.com/conda-forge/miniforge/releases/latest/download

RUN set -x && \
    # Miniforge installer
    miniforge_arch=$(uname -m) && \
    miniforge_installer="Mambaforge-Linux-${miniforge_arch}.sh" && \
    wget --quiet "${CONDA_MIRROR}/${miniforge_installer}" && \
    /bin/bash "${miniforge_installer}" -f -b -p "${CONDA_DIR}" && \
    rm "${miniforge_installer}" && \
    # Conda configuration see https://conda.io/projects/conda/en/latest/configuration.html
    conda config --system --set auto_update_conda false && \
    conda config --system --set show_channel_urls true && \
    if [[ "${PYTHON_VERSION}" != "default" ]]; then mamba install --quiet --yes python="${PYTHON_VERSION}"; fi && \
    mamba list python | grep '^python ' | tr -s ' ' | cut -d ' ' -f 1,2 >> "${CONDA_DIR}/conda-meta/pinned" && \
    # Using conda to update all packages: https://github.com/mamba-org/mamba/issues/1092
    conda update --all --quiet --yes && \
    conda clean --all -f -y && \
    rm -rf "/home/${DOCKER_USER}/.cache/yarn" && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${DOCKER_USER}"

RUN mamba install --quiet --yes \
    'notebook' \
    'jupyterhub' \
    'jupyterlab' && \
    mamba clean --all -f -y && \
    npm cache clean --force && \
    jupyter notebook --generate-config && \
    jupyter lab clean && \
    rm -rf "/home/${DOCKER_USER}/.cache/yarn" && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${DOCKER_USER}"

ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]

# Copy local files as late as possible to avoid cache busting
COPY start.sh start-notebook.sh start-singleuser.sh /usr/local/bin/
# Currently need to have both jupyter_notebook_config and jupyter_server_config to support classic and lab
COPY jupyter_notebook_config.py /etc/jupyter/

EXPOSE 8888

USER root

# Prepare upgrade to JupyterLab V3.0 #1205
RUN sed -re "s/c.NotebookApp/c.ServerApp/g" \
    /etc/jupyter/jupyter_notebook_config.py > /etc/jupyter/jupyter_server_config.py && \
    fix-permissions /etc/jupyter/ && \
    fix-permissions "${HOME}" && \
    fix-permissions "${CONDA_DIR}"

USER $DOCKER_UID

WORKDIR $HOME
