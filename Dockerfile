FROM nvcr.io/nvidia/pytorch:22.04-py3

RUN apt-get update
RUN apt-get install -y tini sudo locales
RUN echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

RUN conda install -y -c conda-forge mamba

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER="${NB_USER}" \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    LC_ALL=en_GB.UTF-8 \
    LANG=en_GB.UTF-8 \
    LANGUAGE=en_GB.UTF-8
ENV PATH="${CONDA_DIR}/bin:${PATH}" \
    HOME="/home/${NB_USER}"

# Copy a script that we will use to correct permissions after running certain commands
COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Create NB_USER with name jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -l -m -s /bin/bash -N -u "${NB_UID}" "${NB_USER}" && \
    mkdir -p "${CONDA_DIR}" && \
    chown "${NB_USER}:${NB_GID}" "${CONDA_DIR}" && \
    chmod g+w /etc/passwd

RUN fix-permissions "${HOME}" && \
    fix-permissions "${CONDA_DIR}"

ARG install_packages="ipywidgets nodejs numpy pandas dask[dataframe,distributed] pyproj netcdf4 basemap ipympl"

RUN mamba install -y -c conda-forge ${install_packages}

RUN eval "$(conda shell.bash hook)" && \
    mamba create -n xeus-python && \
    conda activate xeus-python && \
    mamba install -y -c conda-forge xeus-python jupyter ${install_packages} && \
    ipython kernel install --name "xeus-python" --user && \
    conda activate base

EXPOSE 8888

# Setup work directory for backward-compatibility
RUN mkdir "/home/${NB_USER}/work" && \
    fix-permissions "/home/${NB_USER}" && ln -s "/home/${NB_USER}/work" /workspace/work

USER ${NB_UID}

# Configure container startup
ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]

# Copy local files as late as possible to avoid cache busting
COPY start.sh start-notebook.sh start-singleuser.sh /usr/local/bin/
# Currently need to have both jupyter_notebook_config and jupyter_server_config to support classic and lab
COPY jupyter_notebook_config.py /etc/jupyter/

