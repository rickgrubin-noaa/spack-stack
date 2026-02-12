# Container Site

This site config is used to build the official Spack-stack containers. This new tier-1 container site superceedes the legacy spack-based container builds and orients the container builder around common configs and a common site definition. The motivation for this site is to have our shared containers more closely match sites with loadable modules and developer tools-pre installed.

# Outline of plan for implementation.
1) Review current docker-ubuntu-gcc-openmpi.yaml
2) Review content of //configs/sites/tier2/aws-ubuntu2404
3) Create a new site based on the assumption that the site will be similar to the ubuntu2404 site and built with a dockerfile. Initially target only the gcc13 build system. Modules should be TCL

## Notes
  - compilers.yaml is no longer needed and is part of spack < 1.0. New compilers ARE packages and are segregated into the "packages_buildstack.yaml" config.


# Agent questions or notes
- The `--site container` argument to `spack stack create env` resolves by searching `configs/sites/tier1/` then `configs/sites/tier2/` for a directory named `container`. Since this site lives at `tier1/container/`, it will be found as a tier1 site. Confirmed via reading `stack_env.py:site_configs_dir()`.
- The `--compiler gcc` argument causes `packages_gcc.yaml` to be merged with `packages.yaml` for both the common and site configs. This is handled automatically by `_copy_site_includes()` and `_copy_common_includes()` in `stack_env.py`.
- The external package versions in `packages.yaml` are taken from Ubuntu 24.04 (Noble Numbat) and must match what is installed via `apt` in the Dockerfile. If the base image changes, these versions need to be updated.
- The `mysql@8.0.40` version was carried over from the old `docker-ubuntu-gcc-openmpi.yaml`. Verify this is the correct version for the Ubuntu 24.04 apt package `mysql-server`.
- The `qt@5.15.3` version was also carried over from the old container config. The actual version in Ubuntu 24.04 may differ slightly. Verify with `dpkg -l qtbase5-dev` in the container.
- The `git-lfs@3.4.1` version should be verified against the Ubuntu 24.04 apt package.
- `BUILD_JOBS` defaults to 4 in the Dockerfile. This is conservative for CI runners. Adjust via `--build-arg BUILD_JOBS=N` for faster builds on larger machines.
- The old container config had `checksum: false` in the spack config. This was NOT carried over to the new site as it is a security concern. If build mirrors are trusted, this can be re-added to `config.yaml`.
- The old container config used `concretizer: unify: true`. The unified-dev template uses `unify: when_possible`. The template setting takes precedence and should be correct for the full unified environment.
- The Dockerfile uses a single-stage build. All build tooling, spack assets, and runtime libraries remain in the final image. This keeps the image larger but ensures the spack installation, modules, and developer tools are all usable together. A future optimization could strip `.git` directories and source caches to reduce size.
- The `met` package variants `+python +grib2 +graphics +lidar2nc +modis` are set in the site `packages.yaml` to match the old container config and tier2 ubuntu2404 site.
- The `MODULEPATH` in the container rc script points to `$SPACK_STACK_DIR/envs/unified-gcc/install/modules/Core`. This assumes the environment name is `unified-gcc` as specified in the `spack stack create env --name unified-gcc` command.
- I did not add `gcc-runtime` as an external. The old `Dockerfile.edits` had it but the tier2 aws-ubuntu2404 site does not. If concretization complains about gcc-runtime, add it to `packages_gcc.yaml`.


# Building

This container is not a typical site config and is installed slightly differently to accomodate the use of a dockerfile. Please follow the instructions here to build it.

## Prerequisites

- Docker (or Podman) installed
- At least 50GB of disk space for the build
- Sufficient RAM (8GB+ recommended)

## Quick Build

The build context is the spack-stack repository root.  The Dockerfile
copies the entire local checkout (including the submodules) into
the image, so any local changes to configs, templates, or spack-ext
are automatically reflected in the container.

```bash
docker build \
    -t spack-stack-gcc:test \
    -f "$(git rev-parse --show-toplevel)/configs/sites/tier1/container/Dockerfile" \
    --build-arg SPACK_STACK_TEMPLATE=unified-dev \
    --build-arg BUILD_JOBS=10 \
    --build-arg COMPILER=gcc \
    "$(git rev-parse --show-toplevel)"


docker build \
    -t spack-stack-intel:test \
    -f "$(git rev-parse --show-toplevel)/configs/sites/tier1/container/Dockerfile" \
    --build-arg SPACK_STACK_TEMPLATE=unified-dev \
    --build-arg BUILD_JOBS=10 \
    --build-arg COMPILER=intel \
    "$(git rev-parse --show-toplevel)"
```

### Build Arguments

| Argument | Default | Description |
|---|---|---|
| `BUILD_JOBS` | `4` | Number of parallel build jobs |

## Running the Container

```bash
# Run as root (for quick testing)
docker run -it spack-stack:unified-gcc

# Run as nonroot user (recommended for MPI jobs)
docker run -it --user nonroot spack-stack:unified-gcc
```

Once inside the container, load modules:

```bash
# Modules are automatically available via MODULEPATH set in /etc/spack_container_rc.sh
module avail

# Example: load the stack compiler and MPI, then a JEDI environment
module load stack-gcc/13.3.0
module load stack-openmpi/5.0.8
module load jedi-fv3-env
```

## File Inventory

| File | Purpose |
|---|---|
| `Dockerfile` | Single-stage Docker build for the container |
| `packages.yaml` | External system packages + container preferences (target arch, MPI provider) |
| `packages_gcc.yaml` | GCC 13.3.0 compiler definition (merged when `--compiler gcc` is used) |
| `modules.yaml` | Enables TCL module system |
| `config.yaml` | Container-specific spack config (build jobs, cache paths) |
| `README.md` | This file |

## Relationship to Other Configs

This site config is designed to work with the `spack stack create env` workflow. When the environment is created, spack-stack automatically:

1. Copies and merges `configs/common/packages.yaml` + `configs/common/packages_gcc.yaml` into `common/packages.yaml`
2. Copies and merges `configs/common/modules.yaml` + `configs/common/modules_tcl.yaml` into `common/modules.yaml`
3. Copies and merges this site's `packages.yaml` + `packages_gcc.yaml` into `site/packages.yaml`
4. Copies this site's `modules.yaml` (with TCL enable) into `site/modules.yaml`
5. Uses the `unified-dev` template's `spack.yaml` as the base spec list

The site configs take precedence over common configs. The template `spack.yaml` has the highest precedence.
