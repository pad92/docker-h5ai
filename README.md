# Docker h5ai

A Docker image for [h5ai](https://larsjung.de/h5ai/), a modern file indexer for HTTP web servers.

Built on Angie 1.11+ (Alpine) and PHP 8.4, with s6-overlay as the process supervisor.

[![GitHub issues](https://img.shields.io/github/issues/pad92/docker-h5ai.svg)](https://github.com/pad92/docker-h5ai)
[![Docker Pulls](https://img.shields.io/docker/pulls/pad92/docker-h5ai.svg)](https://hub.docker.com/r/pad92/docker-h5ai/)

---

## Features

- PHP 8.4 and Angie 1.11+ on an Alpine base.
- Optional basic authentication covering both the listing page and direct file downloads.
- Security headers set by default: `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy` and a `Content-Security-Policy` tuned for h5ai.
- Correct UNIX signal handling, so `docker stop` shuts the services down cleanly.
- s6-overlay restarts a crashed service instead of leaving a half-dead container.
- All logs go to stdout/stderr; nothing is written inside the container.

---

## Usage

### Basic usage

Mount the directory you want to share to `/share`:

```bash
docker container run -d -p 80:80 \
  -v /path/to/sharing-file:/share \
  pad92/docker-h5ai
```

### Basic authentication

To protect the index page and all files under `/share`, set a username and password with the `ENV_U` and `ENV_P` environment variables:

```bash
docker container run -d -p 80:80 \
  -e ENV_U=admin \
  -e ENV_P=mysecretpassword \
  -v /path/to/sharing-file:/share \
  pad92/docker-h5ai
```

### h5ai info page password (administration)

To protect the h5ai diagnostic/info page (at `/_h5ai/public/index.php`), set the `H5AI_ADMIN_PASSWORD` environment variable. At startup the container hashes it (SHA-512) and writes the hash into `options.json`:

```bash
docker container run -d -p 80:80 \
  -e H5AI_ADMIN_PASSWORD=myadminpassword \
  -v /path/to/sharing-file:/share \
  pad92/docker-h5ai
```

> [!NOTE]
> If `H5AI_ADMIN_PASSWORD` is unset or empty, the container generates a random 32-character password at boot and prints it to the startup logs, so the info page is never left unprotected.

### Permissions (PUID / PGID)

By default the services (Angie and PHP-FPM) run as the built-in `angie` user
(`uid 100`). If the files you mount under `/share` are owned by a different
uid/gid and are not world-readable, h5ai cannot read them and shows an empty
listing. Set `PUID`/`PGID` to the owner of your shared files so the runtime
account is remapped to match:

```bash
docker container run -d -p 80:80 \
  -e PUID=1030 \
  -e PGID=100 \
  -v /path/to/sharing-file:/share \
  pad92/docker-h5ai
```

- `PUID` / `PGID`: uid/gid the `angie` account is remapped to at startup. When
  unset, the defaults (`100`/`101`) are kept, which is fine for world-readable
  shares.

### Behind a reverse proxy (real client IP)

When the container runs behind a reverse proxy, `$remote_addr` (and the access log) would
otherwise show the proxy's IP. Set `REAL_IP_FROM` to the trusted proxy network(s) so Angie
substitutes the real client IP from the `X-Forwarded-For` header:

```bash
docker container run -d -p 80:80 \
  -e REAL_IP_FROM="10.0.0.0/8, 192.168.0.0/16" \
  -v /path/to/sharing-file:/share \
  pad92/docker-h5ai
```

- `REAL_IP_FROM`: comma- or space-separated list of trusted proxy IPs/CIDRs. When unset, the
  feature is disabled.
- `REAL_IP_HEADER` (optional): header carrying the client IP, defaults to `X-Forwarded-For`.

> [!WARNING]
> Only enable this for proxies you trust. `X-Forwarded-For` can be spoofed by any client that
> reaches Angie directly, so listing untrusted networks lets clients forge their logged IP.

### Custom h5ai options

To override the default [options.json](https://raw.githubusercontent.com/lrsjng/h5ai/v0.29.0/src/_h5ai/private/conf/options.json) file, mount your custom file into `/usr/share/h5ai/_h5ai/private/conf/options.json`:

```bash
docker container run -d -p 80:80 \
  -v /path/to/sharing-file:/share \
  -v $PWD/options.json:/usr/share/h5ai/_h5ai/private/conf/options.json \
  pad92/docker-h5ai
```

> [!NOTE]
> If you mount your `options.json` **read-only** (`:ro`), the startup script keeps your
> `passhash` untouched instead of generating a random admin password. Setting
> `H5AI_ADMIN_PASSWORD` together with a read-only `options.json` is an error and aborts startup.

### Cache paths (thumbnails and metadata)

h5ai caches generated thumbnails and metadata in two places inside the container:

- Public cache (thumbnails): `/usr/share/h5ai/_h5ai/public/cache/`
- Private cache: `/usr/share/h5ai/_h5ai/private/cache/`

To keep thumbnails across container restarts or recreations, mount volumes on these paths:

```bash
docker container run -d -p 80:80 \
  -v /path/to/sharing-file:/share \
  -v /path/to/public-cache:/usr/share/h5ai/_h5ai/public/cache \
  -v /path/to/private-cache:/usr/share/h5ai/_h5ai/private/cache \
  pad92/docker-h5ai
```

> [!NOTE]
> At startup an init task fixes ownership (`angie:angie`) and permissions (`755` for
> directories, `644` for files) on the cache directories so the PHP process can write to them.

---

## Docker Compose example

A ready-to-use example is provided in [docker-compose.yml](docker-compose.yml)
(`docker-compose.dev.yml` is the development harness). Minimal version:

```yaml
services:
  h5ai:
    image: pad92/docker-h5ai
    ports:
      - "8888:80"
    environment:
      - ENV_U=admin
      - ENV_P=mysecretpassword
      - H5AI_ADMIN_PASSWORD=myadminpassword
    volumes:
      - /path/to/sharing-file:/share:ro
    restart: unless-stopped
```

Then start the container:

```bash
docker compose up -d
```

---

## Development

A `Makefile` covers local development, testing and security scans:

```bash
make build   # build the image
make test    # build, then run the container test suite (auth, passhash, real_ip, healthcheck)
make trivy   # build, then scan the image with Trivy
make clean   # remove test containers and the built image
```

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.
