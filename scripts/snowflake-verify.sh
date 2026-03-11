#!/usr/bin/env bash
set -euo pipefail

for cmd in docker; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
done

env_file="${1:-.env.local.resolved}"

if [[ ! -f "$env_file" ]]; then
  echo "Missing env file: $env_file"
  echo "Run: make creds-rotate"
  exit 1
fi

docker run --rm --env-file "$env_file" lakehousing-dbt:latest python -u - <<'PY'
import os
import sys

import snowflake.connector

account = os.environ.get("SNOWFLAKE_ACCOUNT")
user = os.environ.get("SNOWFLAKE_USER")
password = os.environ.get("SNOWFLAKE_PASSWORD")
warehouse = os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH")
database = os.environ.get("SNOWFLAKE_DATABASE", "LAKEHOUSE")
schema = os.environ.get("SNOWFLAKE_SCHEMA", "RAW")
runtime_role = os.environ.get("SNOWFLAKE_ROLE", "TRANSFORMER")
quoted_user = '"' + user.replace('"', '""') + '"' if user else user

if not account or not user or not password:
    print("Missing required Snowflake credentials in env file")
    sys.exit(1)


def connect_with(role):
    kwargs = {
        "account": account,
        "user": user,
        "password": password,
        "warehouse": warehouse,
    }
    if role:
        kwargs["role"] = role
    return snowflake.connector.connect(**kwargs)


runtime_role_connected = False
conn = None
primary_error = None

try:
    conn = connect_with(runtime_role)
    runtime_role_connected = True
except Exception as exc:
    primary_error = exc

if conn is None:
    try:
        conn = connect_with(None)
        print(f"Connected using user's default role. Runtime role check for '{runtime_role}' will be validated explicitly.")
    except Exception as exc:
        print("Snowflake connectivity check failed.")
        print(f"Account: {account}")
        print(f"User: {user}")
        print(f"Configured runtime role: {runtime_role}")
        if primary_error is not None:
            print(f"Role-based connection error: {primary_error}")
        print(f"Fallback connection error: {exc}")
        sys.exit(1)

cur = conn.cursor()
missing = []


def has_rows(sql):
    cur.execute(sql)
    return len(cur.fetchall()) > 0

try:
    if not has_rows(f"show databases like '{database}'"):
        missing.append(f"Database missing: {database}")

    if not has_rows(f"show warehouses like '{warehouse}'"):
        missing.append(f"Warehouse missing: {warehouse}")

    if not has_rows(f"show roles like '{runtime_role}'"):
        missing.append(f"Role missing: {runtime_role}")

    if not has_rows(f"show external tables like 'ORDERS_EXT' in schema {database}.{schema}"):
        missing.append(f"External table missing: {database}.{schema}.ORDERS_EXT")

    if not has_rows(f"show external tables like 'CUSTOMERS_EXT' in schema {database}.{schema}"):
        missing.append(f"External table missing: {database}.{schema}.CUSTOMERS_EXT")

    cur.execute(f"show grants to user {quoted_user}")
    grant_rows = cur.fetchall()
    role_granted = any(
        len(row) > 1 and str(row[1]).upper() == runtime_role.upper()
        for row in grant_rows
    )

    if not role_granted:
        missing.append(f"Role '{runtime_role}' is not granted to user '{user}'")

    if not runtime_role_connected:
        missing.append(
            f"Unable to connect using runtime role '{runtime_role}'. Ensure role exists and user has role."
        )

    if missing:
        print("Snowflake verification failed. Fix the following before launching Kubernetes dbt jobs:")
        for item in missing:
            print(f"- {item}")
        print("Suggested action: run scripts/setup_snowflake.sql as ACCOUNTADMIN, then grant role to your user.")
        print(f"Example: grant role {runtime_role} to user {quoted_user};")
        sys.exit(1)

    print("Snowflake verification passed.")
    print(f"- Database: {database}")
    print(f"- Warehouse: {warehouse}")
    print(f"- Role exists and granted: {runtime_role}")
    print(f"- External tables: {database}.{schema}.ORDERS_EXT, {database}.{schema}.CUSTOMERS_EXT")
finally:
    cur.close()
    conn.close()
PY
