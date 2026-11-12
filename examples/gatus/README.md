# Gatus

Checks sites from outside and receives every server's nightly backup heartbeat.
Run it on a different server from the apps it watches: a dead server cannot
report itself.

- Dashboard: `ssh -L 8080:<GATUS_LISTEN>:8080 <server>`, then http://127.0.0.1:8080.
- For heartbeats, set `GATUS_LISTEN` to this server's private IP and allow TCP
  8080 from the other servers in the cloud firewall and the host firewall.
- For each app that backs up, add an external endpoint named `<host>-<app>`, and
  set `HEARTBEAT_URL` and `HEARTBEAT_TOKEN` in that server's `/etc/ops/alert.env`.
- After changing `config/config.yaml`, sync, then run `ops up gatus`.
