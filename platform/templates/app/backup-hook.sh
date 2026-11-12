# shellcheck shell=bash
# Sourced by `ops backup`. Write a consistent copy of the data to $STAGE.
# Available: $APP, $APP_DIR, $APP_DATA (/srv/apps/<app>), $STAGE, and
# `compose`, which runs docker compose for this app.
# The app's .env is added by ops; do not copy it here.

cp -a "$APP_DATA/data" "$STAGE/"
