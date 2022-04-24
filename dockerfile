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
  curl \
  libarchive-dev \
  pkg-config \
  libssl-dev \
  libclang-dev \
  libpcap-dev
  
USER $NB_UID
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --component rust-src
ENV PATH="${HOME}/.cargo/bin:${PATH}"
RUN cargo install evcxr_jupyter
RUN evcxr_jupyter --install
USER root

# Kotlin Kernel
RUN apt-get update \
    && apt-get install -y openjdk-11-jre ca-certificates-java  \
    && echo "Installed openjdk 11" \
    && apt-get install -y git unzip \
    && echo "Installed utilities"
RUN conda install -y -c jetbrains kotlin-jupyter-kernel && echo "Kotlin Jupyter kernel installed via conda"

# Spark
ARG spark_version="3.2.1"
ARG hadoop_version="3.2"

ENV APACHE_SPARK_VERSION="${spark_version}" \
    HADOOP_VERSION="${hadoop_version}"

WORKDIR /tmp
RUN wget -q "https://archive.apache.org/dist/spark/spark-${APACHE_SPARK_VERSION}/spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" && \
    tar xzf "spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" -C /usr/local --owner root --group root --no-same-owner && \
    rm "spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz"
    
WORKDIR /usr/local
ENV SPARK_HOME=/usr/local/spark
ENV SPARK_OPTS="--driver-java-options=-Xms1024M --driver-java-options=-Xmx4096M --driver-java-options=-Dlog4j.logLevel=info" \
    PATH="${PATH}:${SPARK_HOME}/bin"

RUN ln -s "spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}" spark && \
    mkdir -p /usr/local/bin/before-notebook.d && \
    ln -s "${SPARK_HOME}/sbin/spark-config.sh" /usr/local/bin/before-notebook.d/spark-config.sh
RUN cp -p "${SPARK_HOME}/conf/spark-defaults.conf.template" "${SPARK_HOME}/conf/spark-defaults.conf" && \
    echo 'spark.driver.extraJavaOptions -Dio.netty.tryReflectionSetAccessible=true' >> "${SPARK_HOME}/conf/spark-defaults.conf" && \
    echo 'spark.executor.extraJavaOptions -Dio.netty.tryReflectionSetAccessible=true' >> "${SPARK_HOME}/conf/spark-defaults.conf"
    
RUN conda install -c conda-forge spylon-kernel

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_UID

COPY environment.yml .

RUN conda env create -f environment.yml
RUN python -m spylon_kernel install

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

