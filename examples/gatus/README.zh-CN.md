# Gatus

[English](README.md)

从外部检查网站，并接收每台服务器每晚的备份心跳。要部署在与被监控应用不同的服务器上：宕机的服务器无法报告自己。

- 面板：`ssh -L 8080:<GATUS_LISTEN>:8080 <server>`，然后打开 http://127.0.0.1:8080。
- 接收心跳：把 `GATUS_LISTEN` 设为本服务器的内网 IP，并在云防火墙和主机防火墙里允许其他服务器访问 TCP 8080。
- 每个需要备份的应用，添加一个名为 `<host>-<app>` 的外部端点，并在那台服务器的 `/etc/ops/alert.env` 里设置 `HEARTBEAT_URL` 和 `HEARTBEAT_TOKEN`。
- 修改 `config/config.yaml` 后，同步，然后运行 `ops up gatus`。
