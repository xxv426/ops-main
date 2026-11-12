# shellcheck shell=bash
# pg_dump takes a consistent snapshot while Umami keeps running. --clean makes
# the dump replace existing objects when it is restored.

compose exec -T umami-db pg_dump -U umami -d umami --clean --if-exists </dev/null |
  gzip >"$STAGE/umami.sql.gz"
gunzip -t "$STAGE/umami.sql.gz"
