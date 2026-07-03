# Docker h5ai

A Docker image for [h5ai](https://larsjung.de/h5ai/), a modern HTTP web server indexer. 

Built on top of **Angie 1.11+ (Alpine)** and **PHP 8.4** with **s6-overlay** for process management.

[![GitHub issues](https://img.shields.io/github/issues/pad92/docker-h5ai.svg)](https://github.com/pad92/docker-h5ai)
[![Docker Pulls](https://img.shields.io/docker/pulls/pad92/docker-h5ai.svg)](https://hub.docker.com/r/pad92/docker-h5ai/)

---

## Features

- **PHP 8.4 & Angie 1.11+** (Alpine-based, lightweight and secure).
- **Basic Authentication** (built-in wrapper protecting both the directory indexing page and direct static file downloads).
- **Hardened Security Headers** (`X-Frame-Options`, `X-Content-Type-Options`, `X-XSS-Protection` enabled).
- **Proper UNIX Signal Handling** (Graceful shutdowns under Docker).
- **s6-overlay Process Management** (Auto-restart of services on failure).

---

## Usage

### Basic Usage

Mount the directory you want to share to `/share`:

```bash
docker container run -d -p 80:80 \
  -v /path/to/sharing-file:/share \
  pad92/docker-h5ai
```

### With Basic Authentication

To secure the index page and all files under `/share`, define the username and password using the `ENV_U` and `ENV_P` environment variables:

```bash
docker container run -d -p 80:80 \
  -e ENV_U=admin \
  -e ENV_P=mysecretpassword \
  -v /path/to/sharing-file:/share \
  pad92/docker-h5ai
```

### With h5ai Info Page Password (Administration)

To secure the h5ai diagnostic/info page (located at `/_h5ai/public/index.php`), define the password using the `H5AI_ADMIN_PASSWORD` environment variable. The container will automatically generate the required SHA-512 hash and update `options.json` at startup:

```bash
docker container run -d -p 80:80 \
  -e H5AI_ADMIN_PASSWORD=myadminpassword \
  -v /path/to/sharing-file:/share \
  pad92/docker-h5ai
```

> [!NOTE]
> If `H5AI_ADMIN_PASSWORD` is not defined (or empty), a cryptographically secure random 32-character password is automatically generated at boot, written to the startup logs, and hashed in `options.json` to keep the info page secure by default.

### Permissions (PUID / PGID)

By default the services (Angie and PHP-FPM) run as the built-in `angie` user
(`uid 100`). If the files you mount under `/share` are owned by a different
uid/gid and are not world-readable, h5ai cannot read them and shows an **empty
listing**. Set `PUID`/`PGID` to the owner of your shared files so the runtime
account is remapped to match:

```bash
docker container run -d -p 80:80 \
  -e PUID=1030 \
  -e PGID=100 \
  -v /path/to/sharing-file:/share \
  pad92/docker-h5ai
```

- `PUID` / `PGID`: uid/gid the `angie` account is remapped to at startup. When
  unset, the defaults (`100`/`101`) are kept — fine for world-readable shares.

### Behind a Reverse Proxy (Real Client IP)

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

### With Custom h5ai Options

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

### Cache Paths (Thumbnails & Metadata)

The application caches generated thumbnails and metadata in the following paths within the container:

- **Public Cache (Thumbnails cache)**: `/usr/share/h5ai/_h5ai/public/cache/`
- **Private Cache**: `/usr/share/h5ai/_h5ai/private/cache/`

To persist these thumbnails across container restarts or recreations, mount volumes to these paths:

```bash
docker container run -d -p 80:80 \
  -v /path/to/sharing-file:/share \
  -v /path/to/public-cache:/usr/share/h5ai/_h5ai/public/cache \
  -v /path/to/private-cache:/usr/share/h5ai/_h5ai/private/cache \
  pad92/docker-h5ai
```

> [!NOTE]
> Upon container startup, an s6-overlay initialization task automatically ensures that the cache directories have the correct ownership (`angie:angie`) and permissions (`755` for directories, `644` for files) so that the PHP process can write to them.


---

## Docker Compose Example

Create a `docker-compose.yml` file:

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

A `Makefile` is provided to help with local development, testing, and security scans:

- **Build the image**:
  ```bash
  make build
  ```
- **Run functional tests** (spins up containers and verifies authentication behaviors):
  ```bash
  make test
  ```
- **Vulnerability scan** (uses Trivy to scan the local image):
  ```bash
  make trivy
  ```
- **Clean local containers and images**:
  ```bash
  make clean
  ```

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.
