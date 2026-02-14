"""
Trino Query Client

Submits a SQL query to the Trino cluster and polls for results.
Requires: pip install trino

Usage:
    python scripts/query_trino.py "SELECT * FROM hive.default.users LIMIT 10"
    python scripts/query_trino.py --host localhost --port 8080 --catalog hive --schema default "SHOW SCHEMAS FROM hive"

Make sure to port-forward first:
    kubectl port-forward service/trino-coordinator 8080:8080
"""

import argparse
import sys
import time

import trino


def run_query(host, port, user, catalog, schema, query, poll_interval=0.5):
    """Submit a query to Trino and poll for results."""

    conn = trino.dbapi.connect(
        host=host,
        port=port,
        user=user,
        catalog=catalog,
        schema=schema,
    )

    cursor = conn.cursor()

    print(f"Submitting query to {host}:{port}...")
    print(f"Catalog: {catalog}, Schema: {schema}")
    print(f"Query: {query}")
    print("-" * 60)

    start_time = time.time()
    cursor.execute(query)

    # Poll for results
    print("Polling for results", end="", flush=True)
    rows = cursor.fetchall()
    elapsed = time.time() - start_time

    print(f"\rQuery completed in {elapsed:.2f}s")
    print("-" * 60)

    if not rows:
        print("(no results)")
        return

    # Print column headers
    columns = [desc[0] for desc in cursor.description]
    col_widths = [len(c) for c in columns]

    # Calculate column widths based on data
    for row in rows:
        for i, val in enumerate(row):
            col_widths[i] = max(col_widths[i], len(str(val)))

    # Cap column width
    col_widths = [min(w, 50) for w in col_widths]

    # Print header
    header = " | ".join(c.ljust(col_widths[i]) for i, c in enumerate(columns))
    print(header)
    print("-" * len(header))

    # Print rows
    for row in rows:
        line = " | ".join(
            str(val).ljust(col_widths[i])[:50] for i, val in enumerate(row)
        )
        print(line)

    print("-" * 60)
    print(f"Rows: {len(rows)}, Time: {elapsed:.2f}s")

    cursor.close()
    conn.close()


def main():
    parser = argparse.ArgumentParser(description="Query Trino cluster")
    parser.add_argument("query", help="SQL query to execute")
    parser.add_argument("--host", default="localhost", help="Trino host (default: localhost)")
    parser.add_argument("--port", type=int, default=8080, help="Trino port (default: 8080)")
    parser.add_argument("--user", default="admin", help="Trino user (default: admin)")
    parser.add_argument("--catalog", default="hive", help="Default catalog (default: hive)")
    parser.add_argument("--schema", default="default", help="Default schema (default: default)")

    args = parser.parse_args()

    try:
        run_query(args.host, args.port, args.user, args.catalog, args.schema, args.query)
    except trino.exceptions.TrinoQueryError as e:
        print(f"Query error: {e.message}", file=sys.stderr)
        sys.exit(1)
    except ConnectionError:
        print(
            "Connection failed. Is port-forward running?\n"
            "  kubectl port-forward service/trino-coordinator 8080:8080",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
