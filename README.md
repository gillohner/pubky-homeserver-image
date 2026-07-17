# Pubky Homeserver Image

An independently maintained, multi-architecture container image for running a [Pubky homeserver](https://github.com/pubky/pubky-core/tree/main/pubky-homeserver). It packages the official `pubky-homeserver` release binary; it is not an official Pubky image.

Images are published to GitHub Container Registry for Linux `amd64` and `arm64`:

```text
ghcr.io/gillohner/pubky-homeserver:<version>
```

Use a specific release tag in production. `latest` follows the newest image release.

## Quick Start

Create persistent directories, configure the database password, and start the stack:

```bash
mkdir -p /mnt/pubky/data /mnt/pubky/postgres
cp .env.example .env
editor .env
docker compose -f stack.example.yml up -d
```

Set `PUBKY_DB_PASSWORD` in `.env` to a long, random password. On v0.9.x, the first boot creates `/mnt/pubky/data/config.toml` and `/mnt/pubky/data/secret`; it may fail until the generated configuration is edited.

Replace the generated `/mnt/pubky/data/config.toml` with this minimal working configuration. Replace both password placeholders and the public IP and hostname before restarting:

```toml
[general]
database_url = "postgres://pubky:REPLACE_DB_PASSWORD@pubky-db:5432/pubky_homeserver"
signup_mode = "token_required"

[drive]
pubky_listen_socket = "0.0.0.0:6287"
icann_listen_socket = "0.0.0.0:6286"

[storage]
type = "file_system"

[admin]
enabled = true
listen_socket = "0.0.0.0:6288"
admin_password = "REPLACE_ADMIN_PASSWORD"

[metrics]
enabled = true
listen_socket = "0.0.0.0:6289"

[pkdns]
public_ip = "YOUR_PUBLIC_IP"
public_pubky_tls_port = 6287
icann_domain = "homeserver.example.com"

[logging]
level = "info"
```

Restart the homeserver and verify each service:

```bash
docker compose -f stack.example.yml restart
docker ps --format 'table {{.Names}}\t{{.Status}}'
docker logs pubky-homeserver --tail 100
curl -I http://127.0.0.1:6286
curl -s http://127.0.0.1:6288/info -H 'X-Admin-Password: REPLACE_ADMIN_PASSWORD'
curl -I http://127.0.0.1:6289/metrics
```

Keep `secret`, `config.toml`, and the Postgres volume backed up. Losing the homeserver secret changes its identity.

## Networking

The container listens on these ports when configured as above:

| Port | Purpose | Exposure |
| --- | --- | --- |
| 6286 | ICANN HTTP | Reverse proxy with TLS on a public hostname |
| 6287 | Pubky TLS | Public TCP |
| 6288 | Admin API | Keep private |
| 6289 | Prometheus metrics | Keep private |

For a split-host deployment, forward HTTPS traffic from the reverse proxy to port 6286 and TCP traffic to port 6287. Do not expose the admin or metrics endpoints to the internet.

## Configuration and Upgrades

The image defaults to `pubky-homeserver --data-dir /data`; mount persistent storage at `/data`. The binary creates its default configuration and secret there when they are absent. See the [upstream sample configuration](https://github.com/pubky/pubky-core/blob/main/pubky-homeserver/config.sample.toml) for every option.

Before upgrading, back up `/data` and Postgres, review the upstream release notes, change the image tag, and recreate the container. Never put real credentials, configuration, secrets, or database dumps in this repository.

## Build Locally

Build an image for the current platform with a supported upstream release version:

```bash
docker build --build-arg PUBKY_CORE_VERSION=0.9.3 -t pubky-homeserver:0.9.3 .
docker run --rm pubky-homeserver:0.9.3 --version
```

Tags pushed to this repository trigger a GitHub Actions build and publish matching `ghcr.io/gillohner/pubky-homeserver` tags. The image is maintained separately from `pubky-core`; report homeserver bugs upstream and image packaging issues here.
