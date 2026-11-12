# shellcheck shell=bash
dump=$RESTORE_DIR/umami.sql.gz
gunzip -t "$dump"
gunzip -c "$dump" | grep -q "PostgreSQL database dump complete"
echo "tables: $(gunzip -c "$dump" | grep -c '^CREATE TABLE')"
