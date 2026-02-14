FROM eclipse-temurin:11-jre-jammy

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    procps \
    postgresql-client \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV HIVE_VERSION=3.1.3 \
    METASTORE_HOME=/opt/hive-metastore \
    HADOOP_HOME=/opt/hadoop \
    JAVA_HOME=/opt/java/openjdk

# Create Hadoop directory structure (config + bin + lib)
RUN mkdir -p ${HADOOP_HOME}/etc/hadoop ${HADOOP_HOME}/lib ${HADOOP_HOME}/bin

# Create a stub 'hadoop' script so Hive's schematool and start-metastore
# can find a valid Hadoop installation. Hive validates HADOOP_HOME/bin/hadoop
# and parses 'hadoop version' output expecting the format "Hadoop X.Y.Z".
# The 'jar' subcommand is used by start-metastore to launch the JVM.
RUN { echo '#!/bin/bash'; \
      echo 'case "$1" in'; \
      echo '  classpath) echo "/opt/hadoop/lib/*:/opt/hadoop/etc/hadoop" ;;'; \
      echo '  version)'; \
      echo '    echo "Hadoop 3.3.6"'; \
      echo '    echo "Compiled with individual JARs for Hive Metastore"'; \
      echo '    ;;'; \
      echo '  jar)'; \
      echo '    shift'; \
      echo '    JAR_FILE="$1"; shift'; \
      echo '    CLASS_NAME="$1"; shift'; \
      echo '    exec java $HADOOP_CLIENT_OPTS $HADOOP_OPTS -cp "$JAR_FILE:$HADOOP_CLASSPATH" $CLASS_NAME "$@"'; \
      echo '    ;;'; \
      echo '  *) echo "Hadoop 3.3.6" ;;'; \
      echo 'esac'; \
    } > ${HADOOP_HOME}/bin/hadoop && \
    chmod +x ${HADOOP_HOME}/bin/hadoop

# Download individual Hadoop JARs from Maven Central (replaces full Hadoop tarball)
COPY download-hadoop-jars.sh /tmp/
RUN sed -i 's/\r$//' /tmp/download-hadoop-jars.sh && \
    chmod +x /tmp/download-hadoop-jars.sh && \
    /tmp/download-hadoop-jars.sh ${HADOOP_HOME}/lib && \
    rm /tmp/download-hadoop-jars.sh

# Download and install Hive Metastore standalone
RUN curl -sfL https://repo1.maven.org/maven2/org/apache/hive/hive-standalone-metastore/${HIVE_VERSION}/hive-standalone-metastore-${HIVE_VERSION}-bin.tar.gz \
    | tar -xz -C /opt/ && \
    ln -s /opt/apache-hive-metastore-${HIVE_VERSION}-bin ${METASTORE_HOME}

# Download PostgreSQL JDBC driver
RUN curl -sfL https://jdbc.postgresql.org/download/postgresql-42.7.1.jar \
    -o ${METASTORE_HOME}/lib/postgresql-42.7.1.jar

# Set up classpath and PATH so Hive scripts find the hadoop stub
ENV HADOOP_CLASSPATH="${HADOOP_HOME}/lib/*" \
    PATH="${HADOOP_HOME}/bin:${PATH}"

# Create metastore user and directories
RUN useradd -m -u 1000 -s /bin/bash metastore && \
    mkdir -p ${METASTORE_HOME}/data && \
    mkdir -p ${METASTORE_HOME}/conf

# Copy configuration templates (with correct ownership)
COPY --chown=metastore:metastore config/core-site.xml.template ${HADOOP_HOME}/etc/hadoop/
COPY --chown=metastore:metastore config/metastore-site.xml.template ${METASTORE_HOME}/conf/

# Copy entrypoint script (strip Windows CRLF line endings)
COPY entrypoint.sh /usr/local/bin/
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# Set ownership on real directories AFTER copying all files
RUN chown -R metastore:metastore \
    /opt/apache-hive-metastore-${HIVE_VERSION}-bin \
    ${HADOOP_HOME}

# Switch to metastore user
USER metastore
WORKDIR ${METASTORE_HOME}

# Expose metastore port
EXPOSE 9083

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
