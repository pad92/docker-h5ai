# Changelog

All notable changes to this project will be documented in this file.

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
