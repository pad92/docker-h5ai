# Changelog

All notable changes to this project will be documented in this file.

## [0.30.0-5] - Upcoming Release
### Changed
- **CI/CD Optimization**: Configured build caching (`cache-from`/`cache-to` with `type=gha`) in the GitHub Actions workflow to speed up compilation.
- **CI/CD Security Scanner**: Resolved local scanning image availability in GitHub Actions by adding `load: true` to the scanner stage, and upgraded `aquasecurity/trivy-action` to `v0.35.0` to avoid resolution issues with deleted upstream tags.
- **GitLab CI Cleanups**: Simplified GitLab CI pipeline by reordering stages (running test/vulnerability scanning before building production images) and consolidating the four redundant build jobs into a single parameterized `build_image` job. Corrected host resolution in the test runner container by using DinD hostname configuration (`TEST_HOST=docker`).
- **Warnings Fix**: Declared missing global and stage-specific `ARG` inputs (`BUILD_DATE`, `BUILD_VCSREF`, `H5AI_VERSION`) in `Dockerfile` to fix warnings about undefined label variables.
- **Makefile Improvements**: Declared build target dependencies for `test` and `trivy` targets to automate image compilation. Parameterized the target host (`TEST_HOST`) to support both local development (`localhost`) and DinD (`docker`).

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
