# Docker h5ai

A Docker image for [h5ai](https://larsjung.de/h5ai/), a modern HTTP web server indexer. 

Built on top of **Nginx 1.26+ (Alpine)** and **PHP 8.3** with **Supervisor** for process management.

[![GitHub issues](https://img.shields.io/github/issues/pad92/docker-h5ai.svg)](https://github.com/pad92/docker-h5ai)
[![Docker Pulls](https://img.shields.io/docker/pulls/pad92/docker-h5ai.svg)](https://hub.docker.com/r/pad92/docker-h5ai/)

---

## Features

- **PHP 8.3 & Nginx 1.26+** (Alpine-based, lightweight and secure).
- **Basic Authentication** (built-in wrapper protecting both the directory indexing page and direct static file downloads).
- **Hardened Security Headers** (`X-Frame-Options`, `X-Content-Type-Options`, `X-XSS-Protection` enabled).
- **Proper UNIX Signal Handling** (Graceful shutdowns under Docker).
- **Supervisor Process Management** (Auto-restart of services on failure).

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

### With Custom h5ai Options

To override the default [options.json](https://raw.githubusercontent.com/lrsjng/h5ai/v0.29.0/src/_h5ai/private/conf/options.json) file, mount your custom file into `/usr/share/h5ai/_h5ai/private/conf/options.json`:

```bash
docker container run -d -p 80:80 \
  -v /path/to/sharing-file:/share \
  -v $PWD/options.json:/usr/share/h5ai/_h5ai/private/conf/options.json \
  pad92/docker-h5ai
```

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
