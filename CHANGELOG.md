# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Makefile Test**: Added a `make test` case covering a bind-mounted custom `options.json` (regression test for the startup failure below).

### Fixed
- **Bind-Mounted `options.json` Broke Startup**: the startup script rewrote the h5ai admin `passhash` with `sed -i`, whose rename fails (`EBUSY`) on a single-file bind mount; with `set -e` the init oneshot aborted and neither Angie nor PHP-FPM started. The file is now rewritten in place (temp file + `cat`). A read-only mounted `options.json` keeps its existing `passhash`; combining it with `H5AI_ADMIN_PASSWORD` aborts startup with an explicit error.
- **Basic Auth Fail-Open**: an `htpasswd` failure was silently ignored and the container started **without** the authentication requested through `ENV_U`/`ENV_P`. Startup now aborts with the `htpasswd` error instead (fail closed).

## [1.2.4] - 2026-06-26

### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.2.4`.

## [1.2.3] - 2026-06-26

### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.2.3`.
- **Content-Security-Policy**: Relaxed the CSP to support h5ai's WebAssembly-based features and media previews — added `'wasm-unsafe-eval'` to `script-src`, introduced `worker-src 'self' blob:` and `media-src 'self' blob:`.

## [1.2.2-1] - 2026-06-26

### Added
- **PUID/PGID Remapping**: Added `PUID`/`PGID` support so the runtime `angie` account is remapped at startup (via `usermod`/`groupmod -o`) to match the owner of bind-mounted shares. This prevents h5ai from silently hiding all entries (`hideIf403`) when shares are owned by a different uid/gid. Requires the newly added `shadow` package.

### Changed
- **Angie Upgrade**: Updated Angie to version `1.11.8`.
- **Angie Worker User**: Added `user angie;` to `angie.conf` so Angie workers run under the same account as php-fpm, ensuring direct file downloads also benefit from the PUID/PGID remapping.

### Fixed
- **Empty Listing Behind `clear_env`**: `clear_env = yes` in `php-fpm.conf` stripped `H5AI_ROOT_PATH` from worker environments, causing h5ai to fall back to the wrong directory and show an empty listing. Fixed by passing `env[H5AI_ROOT_PATH]` explicitly through `php-fpm.conf`.

## [1.2.2] - 2026-06-26

### Added
- **Real Client IP Behind Reverse Proxy**: Added the `REAL_IP_FROM` (and optional `REAL_IP_HEADER`, default `X-Forwarded-For`) environment variables to declare trusted proxies. When set, an `/etc/angie/conf.d/real_ip.conf` is generated at startup with `set_real_ip_from` directives so Angie substitutes the real client IP from the forwarded header.
- **`php` Command Symlink**: Symlinked `/usr/bin/php` to `php84` so tooling that invokes `php` directly resolves correctly.

### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.2.2`.
- **Access Log Format**: Switched the Angie access log to a `vhost_combined`-style format (vhost prefix `$host:$server_port`, `$remote_addr` as the first field) while preserving the `X-Forwarded-For` value and the existing upstream/timing fields.
- **PHP-FPM Hardening**: Set `clear_env = yes` so container environment variables (including secrets such as `ENV_P` and `H5AI_ADMIN_PASSWORD`) are no longer exposed to PHP worker processes.
- **Cache Permissions**: Refined the startup permission fixup to apply `755` to directories and `644` to files, instead of `755` across everything.
- **Makefile**: Added `--load` to `docker buildx build` so the built image is available to the local Docker store; added `make test` cases covering the health check with basic auth enabled and the `REAL_IP_FROM` configuration.

### Fixed
- **Health Check With Basic Authentication**: The `HEALTHCHECK` no longer marks the container as `unhealthy` when basic auth is enabled — it now treats both `200` and `401` as healthy while still failing when Angie is unreachable.
- **Init Script Logic**: Removed a no-op `$?` check after `htpasswd` (dead code under `set -e`) by guarding the command directly with the conditional.

## [1.2.0-1] - 2026-06-21

### Changed
- **CI Docker Image Upgrade**: Upgraded CI/CD Docker-in-Docker image from `24.0.5` to `28` across build, test, and publish stages.
- **CI Publish Refactor**: Extracted a reusable `.publish-template` job template for multi-platform image publishing, removing duplication between GitLab and Docker Hub publish jobs.
- **Security Headers**: Replaced deprecated `X-XSS-Protection` header with `Referrer-Policy` and `Content-Security-Policy` headers in Angie configuration.
- **PHP OPcache JIT**: Disabled JIT compilation (`jit=disable`) to improve stability.
- **PHP-FPM Configuration**: Added `[global]` section with explicit PID file and error log paths; tightened socket permissions from `0666` to `0660` with `angie` group ownership.
- **Cache Ownership**: Changed cache directory ownership from `angie:www-data` to `angie:angie` for consistent permission model.
- **s6-overlay Timeout**: Changed `S6_CMD_WAIT_FOR_SERVICES_MAXTIME` from `0` (infinite) to `30000` (30 seconds) to detect stuck services.
- **Makefile Improvements**: Replaced hardcoded `sleep` waits with retry-based HTTP polling helpers (`wait_for_http`, `wait_for_http_auth`); switched build command to `docker buildx build`.

### Fixed
- **Reproducible Builds**: Pinned `php-rar` extension build to a specific git commit and copied the compiled `rar.so` via a stable intermediate path.
- **Init Script Safety**: Added `set -e` to the permissions initialization script for fail-fast behavior on errors.

## [1.2.0] - 2026-06-21

### Added
- **PHP Version Upgrade**: Upgraded base image PHP version to `8.4` (Alpine-based), including path updates for the `rar` extension and s6-overlay configurations.

### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.2.0`.

## [1.1.7] - 2026-06-21

### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.1.7` (adds audio thumbnail generation using ffmpeg/avconv, close/stop button to the audio player queue, and background/asynchronous foldersize caching via a CLI helper refresh script).

## [1.1.6] - 2026-06-21

### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.1.6` (rebuilds tree on refresh to prevent collapse while preserving node state, moves no-cache HTTP headers to list API response only, defaults unset ROOT_PATH to parent of H5AI_PATH, adds isContentFetched tracking, cleans dark theme CSS rules, and expands type mappings in configurations).

## [1.1.5] - 2026-06-20

### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.1.5` (resolves aggressive caching of directory data by adding HTTP cache control headers to API responses, fixes folder list refresh tree-view updates, fixes item model bug that marked parent content fetched prematurely, and restores search/filter colors/visibility in dark mode).
## [1.1.4] - 2026-06-20

### Added
- **SQLite3 Support**: Added `php83-sqlite3` and `php83-pdo_sqlite` extensions to enable database/SQLite3 caching support in PHP.
- **RAR Archive Support**: Compiled and installed the `rar` extension from git source to ensure compatibility with PHP 8.3.
- **Path Customization**: Added the `H5AI_ROOT_PATH=/share` environment variable to support customizable root folder mappings.

### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.1.4` (adds alternating list row colors / zebra striping, fixes dark mode link hover tone-on-tone readability issues, and introduces smooth hover highlights for lists).

### Fixed
- **Redundant Permissions Configuration**: Cleaned up build-time cache directories `chown` in the Dockerfile, relying entirely on the runtime s6-overlay permission setup.

## [1.1.3] - 2026-06-19
### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.1.3` (adds dynamic version display in the info page header/backlinks, adjusted build versioning logic, and CI/CD release pipeline fixes).

### Fixed
- **s6-overlay Startup Timeout**: Configured `S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0` to prevent s6-overlay from timing out during slow container startup.
- **Permissions Optimization**: Optimized the startup permissions initialization script to only run `chown` and `chmod` on files/directories with incorrect owner/group or permissions, significantly speeding up container boot times when cache volumes are populated.

## [1.1.2] - 2026-06-19
### Added
- **Administration Password Configuration**: Added support for a `H5AI_ADMIN_PASSWORD` environment variable to automatically set the SHA-512 `passhash` configuration in `options.json` at startup. If not provided, a random password is generated at boot and written to the startup logs.

### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.1.2` (adds dynamic version display in the topbar backlink, global repository migration to `pad92`, and new administrative documentation).
- **Process Manager Migration**: Migrated process management from Supervisor to s6-overlay (v3), providing robust process initialization, signal forwarding, and service supervision.
- **Image Size Optimization**: Reduced final unpacked image size from 391MB to 321MB (saving 70MB, or ~18% reduction) by removing Supervisord and its Python 3 runtime dependencies.
- **Multi-Platform Support**: Added dynamic architecture mapping in the Dockerfile builder stage to download the appropriate s6-overlay binaries depending on `TARGETARCH`, enabling seamless `amd64` and `arm64` builds.

## [1.1.1] - 2026-06-19
### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.1.1` (adds loop detection and symlink verification to prevent infinite recursion, and visited path tracking to prevent circular traversals).

## [1.1.0] - 2026-06-19
### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.1.0` (redesigned modern glassmorphic audio player with persistent playback and queue management, optimized folder size caching, secured CacheDB queries, and added new automated CI/CD and security audit checks).
- **Build Process Optimization**: Modified the Docker image builder stage to download the pre-compiled `h5ai` zip package directly from the public GitLab Generic Packages Registry instead of git cloning and compiling it from source.

## [1.0.0] - 2026-06-18
### Changed
- **h5ai Base Upgrade**: Upgraded default h5ai base version to `1.0.0` (migrated build system from ghu to gulp, added WebP thumbnail support, limited image previews to 80% screen width, and fixed CacheDB/filesize check errors).

## [0.30.0-17] - 2026-06-18
### Changed
- **Web Server Migration**: Migrated web server from Nginx to Angie (version 1.11.7-minimal, Alpine-based).
- **Configuration & Paths Updates**: Migrated configuration paths and files to `/etc/angie/angie.conf`, updated supervisord task definitions, and adjusted file ownership/permissions to use the `angie` user.

## [0.30.0-16] - 2026-06-18
### Changed
- **Base Image Upgrade**: Upgraded `nginx` base image from `1.26` to `1.30`.
- **PHP Version Upgrade**: Upgraded `php` base image to version `8.3` (Alpine).
- **OpenSSL Update**: Upgraded OpenSSL to version `3.3.7-r0` to resolve security vulnerabilities and build compatibility issues.

## [0.30.0-15] - 2026-06-14
### Changed
- **h5ai Base Upgrade**: Upgraded built h5ai base version to `0.30.0-pad92.8`.
  - Integrated Pull Request #765 for improved video thumbnail generation and prevention of thumbnail DoS exploit.
  - Used ffprobe/avprobe to query total video duration and seek into a configurable percentage (default 50%).
  - Limited client control over generated thumbnail sizes to prevent resource exhaustion exploits.
  - Configured CSS object-fit on thumbnails for responsive square cropping.

## [0.30.0-14] - 2026-06-13
### Changed
- **h5ai Base Upgrade**: Upgraded built h5ai base version to `0.30.0-pad92.7`.
  - Added persistent folder size caching and background cache warming (`warm-cache.php`).
  - Added cache options in `options.json` and updated configuration documentation.

## [0.30.0-13] - 2026-06-13
### Changed
- **h5ai Base Upgrade**: Upgraded built h5ai base version to `0.30.0-pad92.6`.
- **Raw Image Support**: Added `imagemagick-raw` and `libraw` packages to enable previews for RAW photos.

## [0.30.0-12] - 2026-06-12
### Changed
- **h5ai Base Upgrade**: Upgraded built h5ai base version to `0.30.0-pad92.5`.
  - Added configuration documentation file `doc/configuration.md`.
  - Modernized photo preview to display EXIF metadata in a responsive glassmorphic panel.

## [0.30.0-11] - 2026-06-12
### Changed
- **h5ai Base Upgrade**: Upgraded built h5ai base version to `0.30.0-pad92.4`.
  - Optimized and standardized UI icon SVG markup and structure.

## [0.30.0-10] - 2026-06-12
### Fixed
- **Startup Warnings & Cache Safety**:
  - Silenced Supervisord critical warning when running as root without dropped privileges.
  - Silenced PHP command checks warning `sh: where: not found` and muted other shell check outputs.
  - Hardened permissions initialization script by creating cache folders dynamically before configuring their permissions.

## [0.30.0-9] - 2026-06-12
### Added
- **Automatic Cache Permissions**: Added a Supervisor initialization task (`init_perms.sh`) to automatically set the correct ownership (`nginx:www-data`) and write permissions (`755`) on cache directories at startup.

## [0.30.0-8] - 2026-06-12
### Changed
- **h5ai Base Upgrade**: Upgraded built h5ai base version to `0.30.0-pad92.3`.

## [0.30.0-7] - 2026-06-12
### Added
- **Resource Limits**: Configured CPU limits (`cpus: '1.0'`) and memory limits (`memory: 1G`) with reservations in `docker-compose.yml`.
- **PHP Custom Configuration**: Added `custom.ini` with custom memory limits (`memory_limit = 512M`), execution time (`max_execution_time = 120`), and optimised realpath cache and output buffering.

### Changed
- **h5ai Base Upgrade**: Upgraded built h5ai base version to `0.30.0-pad92.2`.
- **PHP-FPM Tuning**: Tuned pool concurrency (up to 20 workers) and process recycling after 1000 requests to avoid memory leaks.
- **OPcache Tuning**: Enabled optimized OPcache parameters and disabled file status checks (`validate_timestamps = 0`) since the image filesystem is immutable.
- **Docker Compose Cleanup**: Removed obsolete version parameter and adjusted volume structure.

## [0.30.0-6] - 2026-06-12
### Added
- **Persistent Cache Documentation**: Added instructions in `README.md` to persist public (thumbnails) and private cache across container restarts via volume mounts.

### Changed
- **h5ai Base Upgrade**: Upgraded the compiled h5ai base version to `0.30.0-pad92.1` using the `pad92/h5ai` custom fork, which integrates `movi-player` for modernized video previews, upgrades the `marked` library, and enables cross-origin isolation.

## [0.30.0-5] - 2026-06-12
### Added
- **GitLab Release Automation**: Configured `release-cli` in the CI/CD pipeline to automatically generate GitLab Release pages from tag descriptions in `CHANGELOG.md`.
- **Security Headers**: Enabled `X-Frame-Options`, `X-Content-Type-Options`, and `X-XSS-Protection` headers in the Nginx configuration.
- **Access Control**: Explicitly blocked external access to the `/_h5ai/private` directory with a 403 Forbidden rule.

### Changed
- **Stack Upgrade**: Upgraded base image to Nginx 1.26 (Alpine-slim) and PHP to version 8.3 (upgraded from PHP 8.1), including path updates and packages optimization.
- **Node.js Build Environment**: Upgraded builder environment to Node 20 (Alpine) and enabled openssl legacy provider to compile dependencies.
- **Process Manager**: Changed Supervisord config to automatically restart (`autorestart=true`) PHP-FPM and Nginx processes on failure.
- **UNIX Signal Handling**: Added `exec` command to start Nginx to ensure proper signal forwarding and graceful container shutdowns.
- **GitLab CI Migration**: Migrated the pipeline from GitHub Actions to GitLab CI/CD, configuring a 5-stage workflow (lint, build, test, scan, publish) run on the `chataigne` runner.
- **CI/CD Build & Caching**: Replaced multiple build jobs with a parameterized, single-build pattern. Configured multi-platform compilation (`linux/amd64`, `linux/arm64`) using Docker Buildx and registry caching (`type=registry`) to speed up builds.
- **CI/CD Security Scanner**: Upgraded Trivy vulnerability scanning tool to scan built image tarballs locally, removing the need for a Docker daemon in the scan stage.
- **Dockerfile & Makefile Cleanups**: Standardized Dockerfile label inputs (`BUILD_DATE`, `BUILD_VCSREF`) and parameterized the target hostname (`TEST_HOST`) to ease local validation.

### Fixed
- **Basic Authentication scope**: Extended authentication protection to cover both the indexing layout page and direct static file downloads by moving the authentication config to the root block. Added safe checks to only enable authentication if both `ENV_U` and `ENV_P` variables are non-empty.
- **Functional Validation**: Rewrote authentication test scripts to resolve test runner gateways by dynamically querying internal container IP addresses on the bridge network.

## [0.30.0-4] - 2023-10-10
### Fixed
- HTTP Real IP configuration.
- HTTP logs redirection.

## [0.30.0-3] - 2023-10-03
### Changed
- Configure multi-platform builds in GitLab CI (supporting `linux/arm64`, `linux/amd64`, and `linux/arm/v7`).
- Configure Container Scanning and SAST in GitLab CI.
- Update node versions and enable OPcache.
### Fixed
- GitLab CI tagging behavior.

## [0.30.0-2] - 2023-05-14
### Changed
- Update supervisord configuration.
- Upgrade PHP to version 8.1.
- Security upgrade of Nginx base image from `1.22.0-alpine` to `1.22.1-alpine`.
### Fixed
- PHP 8.1 compatibility issues.
- Repository badge links.

## [0.30.0-1] - 2022-07-06
### Changed
- Upgrade base images and runtimes to PHP 8.0.
- Apply Dockerfile security upgrades to reduce package vulnerabilities.

## [0.30.0] - 2021-11-30
### Added
- Basic Authentication support via `ENV_U` (Username) and `ENV_P` (Password) environment variables.
- MIT License file.
### Changed
- Clean up CI configurations.

## [0.29.2-2] - 2019-10-27
### Changed
- Explicitly set docker image version labels.

## [0.29.2-1] - 2019-07-29
### Changed
- Switch base image to `nginx:stable-alpine`.

## [0.29.2] - 2019-07-29
### Added
- Process manager (Supervisord) to manage Nginx and PHP-FPM.
- Image processing (Imagick) and missing system dependencies.
### Changed
- Update h5ai version.
- Upgrade Alpine base to version 3.9.

## [0.29.0-2] - 2018-11-20
### Changed
- Clean up and optimize build and runtime dependencies.

## [0.29.0-1] - 2018-07-10
### Fixed
- PHP 7 error log paths.

## [0.29.0] - 2018-07-09
### Added
- Initial release with basic h5ai functionality on Nginx/PHP.
