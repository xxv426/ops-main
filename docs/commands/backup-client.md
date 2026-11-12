# ops backup-client

[中文](backup-client.zh-CN.md)

```text
ops backup-client add <name> '<ssh public key>'
```

Runs on a server that stores **other** servers' backups over SFTP (for example
a small standby server). Creates one locked-down user
and directory per client, so a compromised client can reach only its own
repository.

## Flow

1. Requires root. Does not read `ops.conf`.
2. Checks the arguments: the action must be `add`, the name lowercase letters,
   digits and hyphens, and the key must start with `ssh-`.
3. Creates the user `backup-<name>` (with a home and bash) if it does not exist.
4. Creates `~backup-<name>/.ssh` (700) and **replaces** its `authorized_keys`
   with `restrict <key>` (600). `restrict` turns off port forwarding, agent
   forwarding, X11 and PTY allocation; SFTP still works. Running the command
   again with a new key replaces the old one.
5. Creates `/srv/backup` (755) and `/srv/backup/<name>` (700, owned by the
   user).
6. Logs the repository to use on the client:
   `sftp:backup-<name>@<this server>:/srv/backup/<name>`.

## Then, on the client

```bash
# /etc/ops/backup.env on the client
TARGET_REMOTE_REPOSITORY=sftp:backup-<name>@<backup server>:/srv/backup/<name>
```

Use root's key (`/root/.ssh/id_ed25519`), add the backup server to root's
`known_hosts`, then `ops init --init-missing`.

## Common usage

On the backup server:

```bash
ops backup-client add b "$(ssh server-b cat /root/.ssh/id_ed25519.pub)"
```
