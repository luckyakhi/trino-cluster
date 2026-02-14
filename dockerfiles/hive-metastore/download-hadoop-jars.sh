#!/bin/bash

# Downloads individual Hadoop JARs and their transitive dependencies
# from Maven Central. Replaces the need for the full Hadoop distribution
# tarball or a Maven build stage.

MAVEN_REPO="https://repo1.maven.org/maven2"
TARGET_DIR="${1:-/opt/hadoop/lib}"
FAILED=0

mkdir -p "${TARGET_DIR}"

download() {
  local url="${MAVEN_REPO}/$1"
  local filename=$(basename "$1")
  if curl -fSL --retry 2 "${url}" -o "${TARGET_DIR}/${filename}" 2>/dev/null; then
    echo "  OK: ${filename}"
  else
    echo "  FAILED: ${url}"
    FAILED=$((FAILED + 1))
  fi
}

echo "Downloading Hadoop JARs to ${TARGET_DIR}..."

# ---------------------------------------------------------------------------
# Hadoop Core
# ---------------------------------------------------------------------------
echo "[Hadoop Core]"
download "org/apache/hadoop/hadoop-common/3.3.6/hadoop-common-3.3.6.jar"
download "org/apache/hadoop/hadoop-auth/3.3.6/hadoop-auth-3.3.6.jar"
download "org/apache/hadoop/hadoop-aws/3.3.6/hadoop-aws-3.3.6.jar"
download "org/apache/hadoop/hadoop-hdfs-client/3.3.6/hadoop-hdfs-client-3.3.6.jar"
download "org/apache/hadoop/hadoop-mapreduce-client-core/3.3.6/hadoop-mapreduce-client-core-3.3.6.jar"
download "org/apache/hadoop/hadoop-annotations/3.3.6/hadoop-annotations-3.3.6.jar"

# ---------------------------------------------------------------------------
# Hadoop Shaded Libraries
# ---------------------------------------------------------------------------
echo "[Hadoop Shaded]"
download "org/apache/hadoop/thirdparty/hadoop-shaded-guava/1.1.1/hadoop-shaded-guava-1.1.1.jar"
download "org/apache/hadoop/thirdparty/hadoop-shaded-protobuf_3_7/1.1.1/hadoop-shaded-protobuf_3_7-1.1.1.jar"

# ---------------------------------------------------------------------------
# AWS SDK (single bundle JAR for S3 access)
# ---------------------------------------------------------------------------
echo "[AWS SDK]"
download "com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar"

# ---------------------------------------------------------------------------
# Jackson (JSON processing)
# ---------------------------------------------------------------------------
echo "[Jackson]"
download "com/fasterxml/jackson/core/jackson-annotations/2.12.7/jackson-annotations-2.12.7.jar"
download "com/fasterxml/jackson/core/jackson-core/2.12.7/jackson-core-2.12.7.jar"
download "com/fasterxml/jackson/core/jackson-databind/2.12.7.1/jackson-databind-2.12.7.1.jar"
download "org/codehaus/jackson/jackson-core-asl/1.9.13/jackson-core-asl-1.9.13.jar"
download "org/codehaus/jackson/jackson-mapper-asl/1.9.13/jackson-mapper-asl-1.9.13.jar"

# ---------------------------------------------------------------------------
# Apache Commons
# ---------------------------------------------------------------------------
echo "[Apache Commons]"
download "commons-beanutils/commons-beanutils/1.9.4/commons-beanutils-1.9.4.jar"
download "commons-cli/commons-cli/1.2/commons-cli-1.2.jar"
download "commons-codec/commons-codec/1.15/commons-codec-1.15.jar"
download "commons-collections/commons-collections/3.2.2/commons-collections-3.2.2.jar"
download "org/apache/commons/commons-compress/1.21/commons-compress-1.21.jar"
download "org/apache/commons/commons-configuration2/2.8.0/commons-configuration2-2.8.0.jar"
download "commons-io/commons-io/2.8.0/commons-io-2.8.0.jar"
download "org/apache/commons/commons-lang3/3.12.0/commons-lang3-3.12.0.jar"
download "commons-logging/commons-logging/1.1.3/commons-logging-1.1.3.jar"
download "org/apache/commons/commons-math3/3.1.1/commons-math3-3.1.1.jar"
download "commons-net/commons-net/3.9.0/commons-net-3.9.0.jar"
download "org/apache/commons/commons-text/1.10.0/commons-text-1.10.0.jar"

# ---------------------------------------------------------------------------
# Google Libraries (Guava, Guice, Gson, etc.)
# ---------------------------------------------------------------------------
echo "[Google Libraries]"
download "com/google/guava/guava/27.0-jre/guava-27.0-jre.jar"
download "com/google/guava/failureaccess/1.0/failureaccess-1.0.jar"
download "com/google/guava/listenablefuture/9999.0-empty-to-avoid-conflict-with-guava/listenablefuture-9999.0-empty-to-avoid-conflict-with-guava.jar"
download "com/google/code/gson/gson/2.9.0/gson-2.9.0.jar"
download "com/google/inject/guice/4.0/guice-4.0.jar"
download "com/google/inject/extensions/guice-servlet/4.0/guice-servlet-4.0.jar"
download "com/google/j2objc/j2objc-annotations/1.1/j2objc-annotations-1.1.jar"
download "com/google/code/findbugs/jsr305/3.0.2/jsr305-3.0.2.jar"
download "com/google/protobuf/protobuf-java/2.5.0/protobuf-java-2.5.0.jar"
download "com/google/re2j/re2j/1.1/re2j-1.1.jar"

# ---------------------------------------------------------------------------
# HTTP Clients
# ---------------------------------------------------------------------------
echo "[HTTP Clients]"
download "org/apache/httpcomponents/httpclient/4.5.13/httpclient-4.5.13.jar"
download "org/apache/httpcomponents/httpcore/4.4.13/httpcore-4.4.13.jar"
download "com/squareup/okhttp3/okhttp/4.9.3/okhttp-4.9.3.jar"
download "com/squareup/okio/okio/2.8.0/okio-2.8.0.jar"

# ---------------------------------------------------------------------------
# XML Processing
# ---------------------------------------------------------------------------
echo "[XML Processing]"
download "com/fasterxml/woodstox/woodstox-core/5.4.0/woodstox-core-5.4.0.jar"
download "org/codehaus/woodstox/stax2-api/4.2.1/stax2-api-4.2.1.jar"
download "javax/xml/stream/stax-api/1.0-2/stax-api-1.0-2.jar"
download "org/codehaus/jettison/jettison/1.1/jettison-1.1.jar"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
echo "[Logging]"
download "org/slf4j/slf4j-api/1.7.36/slf4j-api-1.7.36.jar"
download "org/slf4j/slf4j-reload4j/1.7.36/slf4j-reload4j-1.7.36.jar"
download "ch/qos/reload4j/reload4j/1.2.22/reload4j-1.2.22.jar"

# ---------------------------------------------------------------------------
# Other Dependencies
# ---------------------------------------------------------------------------
echo "[Other Dependencies]"
download "javax/activation/activation/1.1/activation-1.1.jar"
download "jakarta/activation/jakarta.activation-api/1.2.1/jakarta.activation-api-1.2.1.jar"
download "javax/inject/javax.inject/1/javax.inject-1.jar"
download "javax/xml/bind/jaxb-api/2.2.2/jaxb-api-2.2.2.jar"
download "com/sun/xml/bind/jaxb-impl/2.2.3-1/jaxb-impl-2.2.3-1.jar"
download "aopalliance/aopalliance/1.0/aopalliance-1.0.jar"
download "org/apache/avro/avro/1.7.7/avro-1.7.7.jar"
download "org/checkerframework/checker-qual/2.5.2/checker-qual-2.5.2.jar"
download "com/github/stephenc/jcip/jcip-annotations/1.0-1/jcip-annotations-1.0-1.jar"
download "com/sun/jersey/jersey-json/1.19.4/jersey-json-1.19.4.jar"
download "dnsjava/dnsjava/2.1.7/dnsjava-2.1.7.jar"
download "com/jcraft/jsch/0.1.55/jsch-0.1.55.jar"
download "org/jetbrains/kotlin/kotlin-stdlib/1.4.10/kotlin-stdlib-1.4.10.jar"
download "org/jetbrains/kotlin/kotlin-stdlib-common/1.4.10/kotlin-stdlib-common-1.4.10.jar"
download "io/dropwizard/metrics/metrics-core/3.2.4/metrics-core-3.2.4.jar"
download "com/nimbusds/nimbus-jose-jwt/9.8.1/nimbus-jose-jwt-9.8.1.jar"
download "com/thoughtworks/paranamer/paranamer/2.3/paranamer-2.3.jar"
download "org/xerial/snappy/snappy-java/1.1.8.2/snappy-java-1.1.8.2.jar"
download "org/wildfly/openssl/wildfly-openssl/1.1.3.Final/wildfly-openssl-1.1.3.Final.jar"
download "org/codehaus/mojo/animal-sniffer-annotations/1.17/animal-sniffer-annotations-1.17.jar"

JAR_COUNT=$(ls -1 "${TARGET_DIR}"/*.jar 2>/dev/null | wc -l)
echo ""
if [ ${FAILED} -gt 0 ]; then
  echo "ERROR: ${FAILED} JAR(s) failed to download!"
  exit 1
fi
echo "Done! Downloaded ${JAR_COUNT} JARs to ${TARGET_DIR}"
