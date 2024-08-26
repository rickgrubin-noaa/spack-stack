#!/bin/bash

# Script to setup the working directory with dependent source code, branch, data, and any host-specific settings before build.sh

# INPUTS:
#   branch_name [defaults to 'develop']
#   machine_name [or auto-detect]
#   compiler [all|intel|gnu]
#   workspace [default to $PWD]
#   clean [boolean weather to first clear out any previous build, cache, data, ...]

# Return Code: 0 on success, non-zero on failure
date
pwd
hostname -s

echo "#### Init #####################################################################"

# Future: allow a different repo from which to build"
export REPOSITORY="https://github.com/JCSDA/spack-stack.git"


# Many of these values are set within Jenkins. For standalone scripts, need to otherwise set them.
export WORKING_DIR=${NODE_CHOICE}-${COMPILER_CHOICE:-"dev"}
export PLATFORM_NAME=$(echo "${PLATFORM_NAME:-${NODE_NAME,,}}")   # lower case

# Need to account for c5 *and* c6?
[[ ${NODE_NAME} == Gaea ]] && export PLATFORM_NAME="gaea-c5"
[[ ${NODE_NAME} =~ clusternoaa ]] && export PLATFORM_NAME="noaacloud"
export ENV_TEMPLATE=unified-dev

# To do: if COMPILER_CHOICE == 'all' then require logic to create distinct compiler-specific envs
[[ -n ${COMPILER_CHOICE} ]] && export ENV_NAME=ci-${COMPILER_CHOICE} || export ENV_NAME=ci-dev

echo ""
echo "WORKSPACE=${WORKSPACE}"
echo "NODE_CHOICE=${NODE_CHOICE}"
echo "COMPILER_CHOICE=${COMPILER_CHOICE}"
echo "REPOSITORY=${REPOSITORY}"
echo "BRANCH=${BRANCH}"
echo "PLATFORM_NAME=${PLATFORM_NAME}"
echo "ENV_NAME=${ENV_NAME}"
echo "WORKING_DIR=${WORKING_DIR}"

if [ ${WORKSPACE::1} != "/" ]; then
  echo "FATAL: Directory must be an absolute path."
  exit 1
fi

set -x
export SPACK_DIR=$(dirname ${WORKSPACE})/${JOB_BASE_NAME}/${WORKING_DIR} # common location of cache, in case builds use temp space

export BUILD_CACHE_DIR=${SPACK_DIR} # Default for any platform. Redefine below, as needed.
[[ ${PLATFORM_NAME} == orion    ]] && BUILD_CACHE_DIR=/work2/noaa/epic/role-epic/spack-build-cache/jenkins-buildcache-Orion
[[ ${PLATFORM_NAME} == hercules ]] && BUILD_CACHE_DIR=/work2/noaa/epic/role-epic/spack-build-cache/jenkins-buildcache-Hercules
[[ ${PLATFORM_NAME} == gaea-c5  ]] && BUILD_CACHE_DIR=${SPACK_DIR}
[[ ${PLATFORM_NAME} == jet  ]] && BUILD_CACHE_DIR=/lfs4/HFIP/hfv3gfs/role.epic/jenkins/spack-build-cache/jenkins-buildcache-Jet
[[ ${PLATFORM_NAME} == hera  ]] && BUILD_CACHE_DIR=${SPACK_DIR}
[[ ${PLATFORM_NAME} == derecho  ]] && BUILD_CACHE_DIR=${SPACK_DIR}
echo "BUILD_CACHE_DIR=${BUILD_CACHE_DIR}"

# StartOver is a Jenkins parameter. For standalone scripts, need to otherwise set them.
# Remove any old, deprecated build_cache from prior tests
[[ $StartOver == true ]] && [[ -n ${BUILD_CACHE_DIR} ]] && rm -rf $(dirname ${BUILD_CACHE_DIR})/build_cache

[[ $StartOver == true ]] && rm -rf ${BUILD_CACHE_DIR}     # we want to clear out last week's build_cache ...
mkdir -pv ${BUILD_CACHE_DIR}

APP_DIR=${WORKSPACE}/${WORKING_DIR}           # work in a sub-dir based on machine and compiler
[[ $StartOver == true ]] && rm -rf ${APP_DIR} # in case we want to clear out any old set of working files ...
mkdir -pv ${APP_DIR}

# BUILD_DAY is a Jenkins parameter. For standalone scripts, need to otherwise set them.
echo "BUILD_DAY=${BUILD_DAY}" # daily | weekly
export BUILD_DIR_DOW=${APP_DIR}/${BUILD_DAY}

# Force a delete of the build directory; reconsider this as a choice?
keep=false
[[ $keep == true ]] || rm -rf ${BUILD_DIR_DOW} # clear out today's old working files and repo
# [[ -d ${BUILD_DIR_DOW}/.git ]] || git clone --quiet --recursive https://github.com/JCSDA/spack-stack.git ${BUILD_DIR_DOW} -b ${BRANCH};
[[ -d ${BUILD_DIR_DOW}/.git ]] || git clone --quiet --recurse-submodules ${REPOSITORY} ${BUILD_DIR_DOW} -b ${BRANCH};

exit 0

