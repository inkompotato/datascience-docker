FROM gitpod/openvscode-server:latest AS vscode

FROM jupyter/base-notebook
LABEL author="inkompotato"
ARG OPENVSCODE_SERVER_ROOT="/home/.openvscode-server"

#get vscode server
COPY --from=vscode ${OPENVSCODE_SERVER_ROOT} ${OPENVSCODE_SERVER_ROOT}

USER root

# Rust Kernel
RUN apt-get update && apt-get install -yq --no-install-recommends \ 
  cmake \
  build-essential \
  curl
USER $NB_UID
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --component rust-src
ENV PATH="${HOME}/.cargo/bin:${PATH}"
RUN cargo install evcxr_jupyter
RUN evcxr_jupyter --install
USER root

# Kotlin Kernel
RUN apt-get update \
    && apt-get install -y openjdk-8-jre \
    && echo "Installed openjdk 8" \
    && apt-get install -y git unzip \
    && echo "Installed utilities"
RUN conda install -y -c jetbrains kotlin-jupyter-kernel && echo "Kotlin Jupyter kernel installed via conda"

# Jupyter Extension (not needed when running vscode)
# RUN conda install -y -c conda-forge jupyterlab jupyterlab-git jupyterlab_widgets ipywidgets && echo "Installed jupyter lab extensions"
RUN sysctl -w fs.inotify.max_user_watches=524288

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_UID

COPY environment.yml .

RUN conda env create -f environment.yml

ENV NOTEBOOK_ARGS="--no-browser"
ENV JUPYTER_TOKEN=${TOKEN}

# start vscode server and setup envs
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    HOME=/home/jovyan/ \
    EDITOR=code \
    VISUAL=code \
    GIT_EDITOR="code --wait" \
    OPENVSCODE_SERVER_ROOT=${OPENVSCODE_SERVER_ROOT} \
    PATH="${OPENVSCODE_SERVER_ROOT}/bin/remote-cli:${PATH}"

# install vscode extensions
RUN [ "/bin/sh", "-c", "exec ${OPENVSCODE_SERVER_ROOT}/bin/openvscode-server --install-extension ms-toolsai.jupyter --install-extension ms-python.python --install-extension matklad.rust-analyzer --install-extension mathiasfrohlich.kotlin", "--" ]

EXPOSE 3000
ENTRYPOINT [ "/bin/sh", "-c", "exec ${OPENVSCODE_SERVER_ROOT}/bin/openvscode-server --host 0.0.0.0 --connection-token ${TOKEN} \"${@}\"", "--" ]

