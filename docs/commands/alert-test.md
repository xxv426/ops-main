# ops alert-test

[中文](alert-test.zh-CN.md)

```text
ops alert-test
```

Sends a test alert email, to check `/etc/ops/alert.env`. `ops init` runs it as
its last step.

## Flow

1. Requires root, loads `ops.conf`.
2. Requires `/etc/ops/alert.env`; without it warns and fails.
3. In a subshell, loads `alert.env` and requires `SMTP_URL`, `ALERT_FROM` and
   `ALERT_TO`.
4. Builds the message: subject `[ops <OPS_HOST>] test`, UTF-8 plain text.
5. Sends it with curl: `--ssl-reqd` (TLS required: `smtps://` on 465, or
   `smtp://` on 587 upgraded with STARTTLS), `--sasl-ir` (AUTH PLAIN in one step;
   QQ Mail rejects curl's default two-step form), 60-second timeout. The
   password is passed through a netrc file on a pipe, never on the command line.
6. Logs `test alert sent; check the inbox of ALERT_TO`, or warns
   `could not send alert email` and exits 1.

Real alerts take the same path: `backup failed` from `ops backup`, `backup check
failed` from `ops check`.

## Common usage

```bash
ops alert-test                   # after editing /etc/ops/alert.env or changing the SMTP password
```

If it fails, run the same curl by hand with `-v` to see the SMTP conversation.
Use the provider's app password, not the account password.
