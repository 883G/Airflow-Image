ARG IMG_AIRFLOW_VERSION=2.10.2
ARG IMG_PYTHON_VERSION=3.8
FROM apache/airflow:slim-${IMG_AIRFLOW_VERSION}-python${IMG_PYTHON_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-e", "-u", "-x", "-c"]

USER 0

# Install Java
RUN apt install ca-certificates curl gnupg \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg \
    && chmod a+r /etc/apt/keyrings/adoptium.gpg \
    && echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list \
    && apt update -y \
    && apt install -y temurin-8-jdk

ENV JAVA_HOME=/usr/lib/jvm/temurin-8-jdk-amd64

# Install Apache Hadoop
ARG HADOOP_VERSION=3.1.1
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV MULTIHOMED_NETWORK=1
ENV USER=root

RUN HADOOP_URL="https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz" \
    && curl 'https://dist.apache.org/repos/dist/release/hadoop/common/KEYS' | gpg --import - \
    && curl -fSL "$HADOOP_URL" -o /tmp/hadoop.tar.gz \
    && curl -fSL "$HADOOP_URL.asc" -o /tmp/hadoop.tar.gz.asc \
    && gpg --verify /tmp/hadoop.tar.gz.asc \
    && mkdir -p "${HADOOP_HOME}" \
    && tar -xvf /tmp/hadoop.tar.gz -C "${HADOOP_HOME}" --strip-components=1 \
    && rm /tmp/hadoop.tar.gz /tmp/hadoop.tar.gz.asc \
    && ln -s "${HADOOP_HOME}/etc/hadoop" /etc/hadoop \
    && mkdir "${HADOOP_HOME}/logs" \
    && mkdir /hadoop-data

ENV PATH="$HADOOP_HOME/bin/:$PATH"

# Install Apache Hive
ARG HIVE_VERSION=3.1.3
ENV HIVE_HOME=/opt/hive
ENV HIVE_CONF_DIR=/etc/hive

RUN HIVE_URL="https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz" \
    && curl -fSL 'https://downloads.apache.org/hive/KEYS' | gpg --import - \
    && curl -fSL "$HIVE_URL" -o /tmp/hive.tar.gz \
    && curl -fSL "$HIVE_URL.asc" -o /tmp/hive.tar.gz.asc \
    && gpg --verify /tmp/hive.tar.gz.asc \
    && mkdir -p "${HIVE_HOME}" \
    && tar -xf /tmp/hive.tar.gz -C "${HIVE_HOME}" --strip-components=1 \
    && rm /tmp/hive.tar.gz /tmp/hive.tar.gz.asc \
    && ln -s "${HIVE_HOME}/etc/hive" "${HIVE_CONF_DIR}" \
    && mkdir "${HIVE_HOME}/logs"

ENV PATH="$HIVE_HOME/bin/:$PATH"

# For installtion of `apache-airflow[apache-hdfs]` it's install the python package `gssapi`
# and for this it's requires the following packages to be installed.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
         gcc \
         libgssapi-krb5-2 \
         libkrb5-dev \
         libsasl2-modules-gssapi-mit \
  && apt-get autoremove -yqq --purge \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# For installtion of `python-ldap` it's requires the following packages.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
        libsasl2-dev \
        python-dev-is-python3 \
        libldap2-dev \
        libssl-dev \
  && apt-get autoremove -yqq --purge \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# For installtion of `sasl` it's requires the following package.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
        g++ \
  && apt-get autoremove -yqq --purge \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

USER ${AIRFLOW_UID}

COPY requirements.txt /
RUN pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" --constraint "${HOME}/constraints.txt" -r /requirements.txt
RUN pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" \
    apache-airflow-providers-cncf-kubernetes==8.4.2
