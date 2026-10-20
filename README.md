# Pubky Homeserver Image

An independently maintained, multi-architecture container image for running a [Pubky homeserver](https://github.com/pubky/pubky-core/tree/main/pubky-homeserver). It packages the official `pubky-homeserver` release binary; it is not an official Pubky image.

Images are published to GitHub Container Registry for Linux `amd64` and `arm64`:

```text
ghcr.io/gillohner/pubky-homeserver:<version>
```

Use a specific release tag in production. `latest` follows the newest image release.

## Quick Start

`stack.example.yml` runs a homeserver with the official admin dashboard. It is adapted from the [Pubky Umbrel app](https://github.com/pubky/umbrel-app-store/tree/master/pubky-homeserver) and uses the upstream `synonymsoft/*` images, pinned by digest:

| Service | Image | Role |
| --- | --- | --- |
| `postgres` | `postgres:18` | Homeserver database |
| `homeserver-config-wrapper` | `synonymsoft/homeserver-umbrel-config-wrapper` | One-shot: writes `config.toml` on first boot and syncs `admin_password` from the env |
| `homeserver` | `synonymsoft/homeserver` | The homeserver; stdout is tee'd to `homeserver.log` for the dashboard |
| `dashboard` | `synonymsoft/homeserver-dashboard` | Admin UI on port 8812 (users, invites with Pubky Ring QR, files, logs, config) |

The Umbrel-only pieces (`app_proxy`, the Cloudflare tunnel containers) are left out: bring your own reverse proxy.

```bash
mkdir -p /mnt/pubky/data /mnt/pubky/postgres
cp .env.example .env
editor .env
docker compose -f stack.example.yml --env-file .env up -d
```

On first boot the wrapper generates `/mnt/pubky/data/config.toml` (token-required signups, admin and metrics enabled, `icann_domain` = `PUBKY_DOMAIN`, `public_ip` = `PUBKY_PUBLIC_IP`), and the homeserver creates its `secret`. An existing `config.toml` is never overwritten: only `admin_password` is reconciled with the env, and `public_icann_http_port = 443` is added if missing. The database service also answers as `pubky-db`, so configs from the previous version of this stack keep working.

Open the dashboard at `http://<host>:8812` and log in with `PUBKY_ADMIN_PASSWORD` (or `PUBKY_DASHBOARD_PASSWORD`). Then check the homeserver:

```bash
docker compose -f stack.example.yml logs homeserver --tail 100
curl -s http://127.0.0.1:6288/info -H "X-Admin-Password: $PUBKY_ADMIN_PASSWORD"
curl -I https://homeserver.example.com
```

Keep `secret`, `config.toml`, and the Postgres directory backed up. Losing the homeserver secret changes its identity.

## Networking

| Port | Purpose | Exposure |
| --- | --- | --- |
| 6286 | ICANN HTTP | Reverse proxy with TLS on `PUBKY_DOMAIN` (443) |
| 6287 | Pubky TLS | Public TCP, forwarded from `PUBKY_PUBLIC_IP` |
| 6288 | Admin API | Host loopback only |
| 6289 | Prometheus metrics | Container network only |
| 8812 | Dashboard | LAN or VPN; never expose without the login set |

Preserve upstream `Cache-Control` and `Vary` headers in the reverse proxy. Use a static public IP: the PKARR record embeds it.

## Configuration and Upgrades

This repository's own image (`ghcr.io/gillohner/pubky-homeserver`) defaults to `pubky-homeserver --data-dir /data`; mount persistent storage at `/data`. The binary creates its default configuration and secret there when they are absent. See the [upstream sample configuration](https://github.com/pubky/pubky-core/blob/main/pubky-homeserver/config.sample.toml) for every option.

Before upgrading, back up `/data` and Postgres, review the upstream release notes, change the image tag, and recreate the container. Never put real credentials, configuration, secrets, or database dumps in this repository.

## Build Locally

Build an image for the current platform with a supported upstream release version:

```bash
docker build --build-arg PUBKY_CORE_VERSION=0.9.3 -t pubky-homeserver:0.9.3 .
docker run --rm pubky-homeserver:0.9.3 --version
```

Tags pushed to this repository trigger a GitHub Actions build and publish matching `ghcr.io/gillohner/pubky-homeserver` tags. The image is maintained separately from `pubky-core`; report homeserver bugs upstream and image packaging issues here.
