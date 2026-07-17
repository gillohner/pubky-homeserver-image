# Pubky Homeserver Image

An independently maintained, multi-architecture container image for running a [Pubky homeserver](https://github.com/pubky/pubky-core/tree/main/pubky-homeserver). It packages the official `pubky-homeserver` release binary; it is not an official Pubky image.

Images are published to GitHub Container Registry for Linux `amd64` and `arm64`:

```text
ghcr.io/gillohner/pubky-homeserver:<version>
```

Use a specific release tag in production. `latest` follows the newest image release.

## Quick Start

Create a directory for the homeserver's persistent state, then start it with Postgres. `stack.example.yml` is a complete Compose/Portainer example:

```bash
mkdir -p /srv/pubky/data /srv/pubky/postgres
export PUBKY_DB_PASSWORD='use-a-long-random-password'
docker compose -f stack.example.yml up -d
```

The first start creates `/srv/pubky/data/config.toml` and `/srv/pubky/data/secret`. Stop the stack, edit `config.toml`, then start it again:

```bash
docker compose -f stack.example.yml down
editor /srv/pubky/data/config.toml
docker compose -f stack.example.yml up -d
```

At minimum, configure the database, public listeners, and DHT advertisement:

```toml
[general]
database_url = "postgres://pubky:YOUR_DATABASE_PASSWORD@pubky-db:5432/pubky_homeserver"

[drive]
icann_listen_socket = "0.0.0.0:6286"
pubky_listen_socket = "0.0.0.0:6287"

[admin]
listen_socket = "0.0.0.0:6288"
admin_password = "use-a-long-random-password"

[metrics]
enabled = true
listen_socket = "0.0.0.0:6289"

[pkdns]
public_ip = "YOUR_PUBLIC_IP"
icann_domain = "homeserver.example.com"
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
