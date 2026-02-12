# Spack-Stack Container Build for tier1/container site
#
# This Dockerfile builds a spack-stack environment using the tier1/container
# See building instructions in README.md
#
# Docker build args:
#    BUILD_JOBS: Build parallelism (default 4)
#    SPACK_STACK_TEMPLATE: Environment template from spack-stack (default unified-dev).
#    COMPILER: Compiler to install (default gcc).
#              - gcc: GCC 13.4.0
#              - intel: Intel OneAPI 2025.3.0

FROM ubuntu:24.04 AS ubuntu_base

ARG BUILD_JOBS=4
ARG SPACK_STACK_TEMPLATE=unified-dev
ARG COMPILER=gcc

SHELL ["/bin/bash", "-c"]


ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    LANGUAGE=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Install core packages.
RUN set -euo pipefail; \
    apt-get -yqq update && \
    apt-get -yqq upgrade && \
    apt-get -yqq install --no-install-recommends \
        # Core build tools.
        build-essential \
        gcc-13 \
        gcc++-13 \
        gfortran-13 \
        cpp-13 \
        make \
        llvm-14 \
        autoconf \
        # External dependencies.
        libcurl4-openssl-dev \
        libmysqlclient-dev \
        libqt5svg5-dev \
        qt5-qmake \
        qt5dxcb-plugin \
        qtbase5-dev \
        zstd \
        # Shell tools, source retrieval and networking.
        sed \
        file \
        less \
        bzip2 \
        unzip \
        ca-certificates \
        curl \
        git \
        git-lfs \
        gpg \
        environment-modules \
        tcl \
        tcl-dev \
        vim \
        wget \
        nano \
        locales && \
    locale-gen en_US.UTF-8 && \
    # Update alternatives for compilers and tools
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100 && \
    update-alternatives --install /usr/bin/gfortran gfortran /usr/bin/gfortran-13 100 && \
    update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-14 100 && \
    # Install the intel
    if [ "${COMPILER:-}" = "intel" ]; then \
        apt update && \
        apt install -y apt-utils gpg && \
        wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
          | gpg --dearmor \
          | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null && \
        echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" \
          | tee /etc/apt/sources.list.d/oneAPI.list && \
        apt update && \
        apt install -y \
            intel-oneapi-compiler-dpcpp-cpp-2025.3 \
            intel-oneapi-compiler-fortran-2025.3 \
            intel-oneapi-mpi-devel-2021.17 \
            intel-oneapi-tbb-devel-2022.3 \
            intel-oneapi-mkl-devel-2025.3 && \
        echo "source /etc/profile.d/modules.sh && module use /opt/intel/oneapi/modulefiles" > /etc/profile.d/z01_oneapi_modules.sh; \
    fi && \
    rm -rf /var/lib/apt/lists/*

#RUN source${SPACK_STACK_DIR}/setup.sh \
# && cp ${SPACK_ROOT}/share/spack/docker/modules.yaml \
#        /root/.spack/modules.yaml \


# TODO(evan): do I need this?
# https://superuser.com/questions/1241548/
#RUN [ -f ~/.profile ] \
# && sed -i 's/mesg n/( tty -s \&\& mesg n || true )/g' ~/.profile \
# || true


FROM ubuntu_base AS builder

ENV SPACK_STACK_DIR=/opt/spack-stack \
    SPACK_ROOT=/opt/spack-stack/spack


# copy spack-stack from build context
# The build context must be the spack-stack repo root (use
# "$(git rev-parse --show-toplevel)" as the context path).
# This copies the full checkout including the spack submodule,
# configs, spack-ext, templates, etc.
COPY . ${SPACK_STACK_DIR}

# Create spack-stack environment
WORKDIR /opt/spack-stack
RUN mkdir -p /tmp/spack-stack && \
    source setup.sh && \
    spack stack create env \
        --site container \
        --template ${SPACK_STACK_TEMPLATE} \
        --name container \
        --prefix /opt/spack-software/ \
        --compiler $COMPILER && \
    cd ${SPACK_STACK_DIR}/envs/container && \
    spack env activate . && \
    spack concretize 2>&1 | tee log.concretize && \
    spack install --fail-fast -j ${BUILD_JOBS} 2>&1 | tee log.install && \
    spack module tcl refresh -y && \
    spack stack setup-meta-modules && \
    # Save output of spack find.
    spack find 2>&1 | tee /opt/spack-software/spack_find.out

## ---------- record installed packages ----------
# FROM spack_base AS runtime
# COPY --from=builder /opt/view /opt/view
#RUN . ${SPACK_STACK_DIR}/setup.sh \

#
## ---------- clean build caches ----------
#RUN . ${SPACK_STACK_DIR}/setup.sh \
# && spack clean --all
#
## ---------- create nonroot user for MPI ----------
#RUN useradd -U -k /etc/skel -s /bin/bash -d /home/nonroot -m nonroot --uid 43891 \
# && echo "ulimit -s unlimited" >> /home/nonroot/.bashrc \
# && echo "ulimit -v unlimited" >> /home/nonroot/.bashrc \
# && echo "export CC=gcc" >> /home/nonroot/.bashrc \
# && echo "export CXX=g++" >> /home/nonroot/.bashrc \
# && echo "export FC=gfortran" >> /home/nonroot/.bashrc \
# && printf "[credential]\n    helper = cache --timeout=7200\n" >> /home/nonroot/.gitconfig \
# && mkdir /home/nonroot/.pmix \
# && echo "rmaps_default_mapping_policy=:oversubscribe" >> /home/nonroot/.pmix/mca-params.conf \
# && chown -R nonroot:nonroot /home/nonroot/.gitconfig /home/nonroot/.pmix
#
## ---------- container-wide rc script ----------
## Sourced by all shells: compiler defaults, MPI policy, module paths.
#RUN echo "ulimit -s unlimited" > /etc/spack_container_rc.sh \
# && echo "ulimit -v unlimited" >> /etc/spack_container_rc.sh \
# && echo "export CC=gcc" >> /etc/spack_container_rc.sh \
# && echo "export CXX=g++" >> /etc/spack_container_rc.sh \
# && echo "export FC=gfortran" >> /etc/spack_container_rc.sh \
# && echo "# OpenMPI settings for running as root and oversubscription." >> /etc/spack_container_rc.sh \
# && echo "export OMPI_ALLOW_RUN_AS_ROOT=1" >> /etc/spack_container_rc.sh \
# && echo "export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1" >> /etc/spack_container_rc.sh \
# && echo "export PRTE_MCA_rmaps_default_mapping_policy=:oversubscribe" >> /etc/spack_container_rc.sh \
# && echo "# TCL module path for the spack-stack environment." >> /etc/spack_container_rc.sh \
# && echo "export MODULEPATH=/opt/spack-stack/envs/unified-gcc/install/modules/Core" >> /etc/spack_container_rc.sh \
# && echo "source /etc/spack_container_rc.sh" >> /etc/bash.bashrc \
# && printf "[credential]\n    helper = cache --timeout=7200\n" >> /root/.gitconfig \
# && mkdir /root/.pmix \
# && echo "rmaps_default_mapping_policy=:oversubscribe" >> /root/.pmix/mca-params.conf
#
## Ensure the container rc is run by non-login shells too.
#ENV BASH_ENV=/etc/spack_container_rc.sh
#
#LABEL "app"="spack-stack" \
#      "mpi"="openmpi"
#
#CMD ["/bin/bash"]
#