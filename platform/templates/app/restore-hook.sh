# shellcheck shell=bash
# Sourced by `ops restore` while the app is stopped. Put the files from
# $RESTORE_DIR back. ops starts the app afterwards.

rm -rf "$APP_DATA/data"
cp -a "$RESTORE_DIR/data" "$APP_DATA/"
