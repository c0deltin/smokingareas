#!/usr/bin/env bash
# Runs the database tests against a throw-away database on a plain
# PostgreSQL (no Supabase needed). Connection via the usual PG* variables.
#   PGHOST=localhost PGUSER=postgres supabase/tests/run_tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."

db="smokingareas_test_$$"
createdb "$db"
trap 'dropdb --if-exists "$db"' EXIT

psql -q -v ON_ERROR_STOP=1 -d "$db" -f tests/supabase_stub.sql
for f in migrations/*.sql; do
  psql -q -v ON_ERROR_STOP=1 -d "$db" -f "$f"
done
psql -q -v ON_ERROR_STOP=1 -d "$db" -f tests/community_test.sql
