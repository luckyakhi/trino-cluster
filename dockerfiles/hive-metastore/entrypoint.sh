#!/bin/bash
set -e

echo "Starting Hive Metastore initialization..."

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
RETRIES=30
until pg_isready -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} 2>/dev/null || [ $RETRIES -eq 0 ]; do
  echo "Waiting for PostgreSQL to be ready... ($RETRIES attempts remaining)"
  RETRIES=$((RETRIES - 1))
  sleep 2
done

if [ $RETRIES -eq 0 ]; then
  echo "ERROR: PostgreSQL is not ready after 60 seconds"
  exit 1
fi

echo "PostgreSQL is ready!"

# Generate core-site.xml from template
echo "Generating Hadoop core-site.xml configuration..."
envsubst < ${HADOOP_HOME}/etc/hadoop/core-site.xml.template > ${HADOOP_HOME}/etc/hadoop/core-site.xml

# Generate metastore-site.xml from template
echo "Generating Hive metastore-site.xml configuration..."
envsubst < ${METASTORE_HOME}/conf/metastore-site.xml.template > ${METASTORE_HOME}/conf/metastore-site.xml

# Verify configuration files were created
if [ ! -f ${HADOOP_HOME}/etc/hadoop/core-site.xml ]; then
  echo "ERROR: core-site.xml was not generated"
  exit 1
fi

if [ ! -f ${METASTORE_HOME}/conf/metastore-site.xml ]; then
  echo "ERROR: metastore-site.xml was not generated"
  exit 1
fi

echo "Configuration files generated successfully"

# Initialize Hive Metastore schema in PostgreSQL (if not already initialized)
echo "Initializing Hive Metastore schema..."
${METASTORE_HOME}/bin/schematool -dbType postgres -initSchema || echo "Schema already initialized or initialization failed (will continue)"

# Optionally upgrade schema if needed
# ${METASTORE_HOME}/bin/schematool -dbType postgres -upgradeSchema || echo "Schema upgrade not needed"

echo "Starting Hive Metastore service..."
exec ${METASTORE_HOME}/bin/start-metastore
