#!/bin/bash

#set -ex
set -e
set +x

export SPACK_STACK_MODULEFILES=modulefiles

function load_spack_modules() {
  local PLATFORM_NAME="$1"
  echo ""
  echo "## Load Modules ..."
  if [[ ${PLATFORM_NAME} == orion ]] ; then
    LOCAL_MODULES_DIR=/work/noaa/epic/role-epic/spack-stack/${PLATFORM_NAME}
    module purge
    module use ${LOCAL_MODULES_DIR}/modulefiles
    module load ecflow/5.8.4
    module load mysql/8.0.31
    module load python/3.10.8
    
  elif [[ ${PLATFORM_NAME} == hercules ]] ; then
    LOCAL_MODULES_DIR=/work/noaa/epic/role-epic/spack-stack/${PLATFORM_NAME}
    module purge
    module use ${LOCAL_MODULES_DIR}/modulefiles
    module load ecflow/5.8.4
    module load mysql/8.0.31
    module load python/3.10.8

  #elif [[ ${PLATFORM_NAME} == gaea-c5 ]] ; then
    # currently in flux with respect to c5 and c6; the following will not work
    #LOCAL_MODULES_DIR=/lustre/f2/dev/wpo/role.epic/contrib/spack-stack/c5
    #module load PrgEnv-intel/8.3.3
    #module load intel-classic/2023.1.0
    #module load cray-mpich/8.1.25
    #module load python/3.9.12
    #module use ${LOCAL_MODULES_DIR}/modulefiles
    #module load qt/5.15.2
    #module load ecflow/5.8.4
    #module load mysql/8.0.31

  elif [[ ${PLATFORM_NAME} == derecho ]]; then
    LOCAL_MODULES_DIR=/glade/work/epicufsrt/contrib/spack-stack/derecho/
    module purge
    #ignore that the sticky module ncarenv/... is not unloaded
    export LMOD_TMOD_FIND_FIRST=yes
    module load ncarenv/23.09
    #module use /glade/work/epicufsrt/contrib/spack-stack/derecho/modulefiles
    module use ${LOCAL_MODULES_DIR}/modulefiles
    module load ecflow/5.8.4
    module load mysql/8.0.33

  elif [[ ${PLATFORM_NAME} == hera ]]; then
    LOCAL_MODULES_DIR=/scratch1/NCEPDEV/nems/role.epic
    module purge
    module use ${LOCAL_MODULES_DIR}/modulefiles
    module load miniconda3/4.12.0
    module load ecflow/5.8.4
    module load mysql/8.0.36

  #elif [[ ${PLATFORM_NAME} == jet ]]; then
    # currently broken?
    #LOCAL_MODULES_DIR=/lfs4/HFIP/hfv3gfs/role.epic/modulefiles
    #module purge
    #module use ${LOCAL_MODULES_DIR}/modulefiles
    #module load miniconda3/4.12.0
    #module load ecflow/5.8.4
    #module load mysql/8.0.36

      #elif [[ ]] # Add others as we go ...

  else
    echo "unsupported platform: ${PLATFORM_NAME}"
    return 99
  fi

  echo ""
  ( set -x; ls -al ${LOCAL_MODULES_DIR}; )
  echo "## Spack modules loaded."
  echo "LOCAL_MODULES_DIR=${LOCAL_MODULES_DIR}"
  module -t available

  return 0
}

echo "#### Create Env  ####################################################################"

# UpdateBuildCache is a Jenkins pipeline Boolean Parameter.
# For standalone scripts, options:
#   1. Create a variable to control this operation / determine a default value
#   2. Force this operation, e.g. spack buildcache push --unsigned --force [...] as part of a build
if [[ ${UpdateBuildCache} == true ]]; then
  echo ""
  echo "PLATFORM_NAME=${PLATFORM_NAME}"
  echo "COMPILER_CHOICE=${COMPILER_CHOICE}"
  echo "BRANCH=${BRANCH}"

  # If not running within a pipeline, need to set this otherwise
  echo "BUILD_DAY=${BUILD_DAY}" # daily | weekly
  BUILD_DIR_DOW=${APP_DIR}/${BUILD_DAY}

  set -x

  load_spack_modules "${PLATFORM_NAME}" || exit $?

  cd ${BUILD_DIR_DOW}
  pwd

  rm -f *-log.txt
  rm -rf envs/${ENV_NAME} # clear out any prior ENV_NAME

  # Save these values in an artifact file
  # For standalone scripts, as in init.sh, need to set these values
  echo "BUILD_DATE=$(date +'%Y/%m/%d-%H:%M')"                                           | tee    ${WORKSPACE}/${NODE_CHOICE}-properties.txt
  echo "PLATFORM_NAME=${PLATFORM_NAME}"                                                 | tee -a ${WORKSPACE}/${NODE_CHOICE}-properties.txt
  echo "COMPILER_CHOICE=${COMPILER_CHOICE}"                                             | tee -a ${WORKSPACE}/${NODE_CHOICE}-properties.txt
  echo "BUILD_DAY=${BUILD_DAY}"                                                         | tee -a ${WORKSPACE}/${NODE_CHOICE}-properties.txt
  echo "BRANCH=${BRANCH}"                                                               | tee -a ${WORKSPACE}/${NODE_CHOICE}-properties.txt
  echo "ENV_NAME=${ENV_NAME}"                                                           | tee -a ${WORKSPACE}/${NODE_CHOICE}-properties.txt
  echo "BUILD_CACHE_MODULEFILES=${APP_DIR}/weekly/envs/${ENV_NAME}/install/modulefiles" | tee -a ${WORKSPACE}/${NODE_CHOICE}-properties.txt
  echo "WORKING_DIR=${WORKING_DIR}"                                                     | tee -a ${WORKSPACE}/${NODE_CHOICE}-properties.txt
  echo "BUILD_CACHE_DIR=${BUILD_CACHE_DIR}"                                             | tee -a ${WORKSPACE}/${NODE_CHOICE}-properties.txt

  ls -al
  git log -1 --oneline || exit 1      # If there is no clone (i.e. no ./.git/), then the job status will return fail here.
  git status
  set +x

  echo "#### Setup ####################################################################"
  echo "#### run: spack stack create env --site ${PLATFORM_NAME} --template ${ENV_TEMPLATE} --name ${ENV_NAME} --compiler ${COMPILER_CHOICE} ####"

  # Use "dot" so as to not launch a new bash instance, and preserve environment variables.
  #source ./setup.sh
  . ./setup.sh

  umask 0022

  spack stack create env --site ${PLATFORM_NAME} --template ${ENV_TEMPLATE} --name ${ENV_NAME} --compiler ${COMPILER_CHOICE}
  status=$?
  echo "## status create=$status" ; echo ""

  spack env activate -p envs/${ENV_NAME}
  status=$?
  echo "## status activate=$status" ; echo ""

  [[ -n ${COMPILER_CHOICE} ]] && [[ ${COMPILER_CHOICE} != "all" ]] \
    && sed "s|'%aocc', '%apple-clang', '%gcc', '%intel'|'%${COMPILER_CHOICE}' |1"  -i envs/${ENV_NAME}/spack.yaml \
    || sed "s|'%aocc', '%apple-clang', '%gcc', '%intel'|'%gcc', '%intel' |1"       -i envs/${ENV_NAME}/spack.yaml

  if [[ -n ${SINGLE_PACKAGE} ]] ; then
    sed "/^  - packages:/,/^  specs:/{/^  - packages:/!{/^  specs:/!d}}" -i envs/${ENV_NAME}/spack.yaml
    sed "s/^  - packages:/  - packages:\n    - ${SINGLE_PACKAGE}\n/1"    -i envs/${ENV_NAME}/spack.yaml
  fi

  echo "#### Build ####################################################################"

  ###############################################################################################################################################
  # (1) at the start of each week (Sunday) - create a new build_cache of the unified-env environment in a specified directory on each machine
  #  To do this, after the spack install step, add:
  #    spack buildcache create -a -u ${BUILD_CACHE_DIR}
  #    spack mirror add build-cache ${BUILD_CACHE_DIR}
  #    spack buildcache update-index ${BUILD_CACHE_DIR}
  # (2) for nightly build and check
  #       make a fresh clone of spack-stack in the testing directory different than ${BUILD_CACHE_DIR}
  #       follow the usual spack env create steps, then:
  #         spack mirror add build-cache ${BUILD_CACHE_DIR}
  #         spack install --no-check-signature
  ###############################################################################################################################################

  ##below commands are to create a new buildcache
  set -x

  verbose="--verbose"              # for debugging
  jobs="--jobs 6"                  # for concretize and install steps

  [[ -n ${BUILD_CACHE_DIR} ]] || exit 1  # Each platform has a different path

  #spack config add "config:install_tree:padded_length:${PADDED_LENGTH:-256}"

  if [[ ${BUILD_DAY} == weekly ]]; then

    (
    # delete the old weekly buildcache, so we can start fresh
    set -x
    rm -rf ${BUILD_CACHE_DIR}/build_cache
    ls -al $(dirname ${BUILD_CACHE_DIR})
    )

    spack concretize $jobs 2>&1 | tee log.concretize
    status=${PIPESTATUS[0]}
    echo "## status concretize=$status" ; echo ""

    ##only needs to run after a new installation is done (e.g. for the weekly cache creation)
    opt=""
    spack install -y --no-check-signature $verbose $opt $jobs 2>&1 | tee log.install
    status=${PIPESTATUS[0]}
    echo "## status install=$status [weekly]" ; echo ""

    spack clean -a

    spack buildcache create -a -u ${BUILD_CACHE_DIR}
    status=${PIPESTATUS[0]}
    echo "## status create=$status [weekly]" ; echo ""

    ## run these commands if creating a new buildcache OR if utilizing an existing cache
    ## add the buildcache as a mirror first
    spack mirror add build-cache ${BUILD_CACHE_DIR}
    status=${PIPESTATUS[0]}
    echo "## status mirror=$status" ; echo ""

    spack buildcache update-index build-cache
    status=${PIPESTATUS[0]}
    echo "## status update-index=$status" ; echo ""

  fi

  if [[ ${BUILD_DAY} == daily ]]; then
    ## install from the buildcache we just added as a mirror
    ## "--use-buildcache only" arg. can be used to ensure only tarballs from
    ## the buildcache are used; it's good for checking if things are working,
    ## we really only need to use --no-check-signature, and let packages that are not
    ## in the most recently used cache be installed from source
    ## this is what we NEED to go to after testing ->>!! spack install -y --no-check-signature

    spack concretize 2>&1 | tee log.concretize
    status=${PIPESTATUS[0]}
    echo "## status concretize=$status" ; echo ""

    ##run these commands if creating a new buildcache OR if utilizing an existing cache
    ## add the buildcache as a mirror first
    spack mirror add build-cache ${BUILD_CACHE_DIR}
    status=${PIPESTATUS[0]}
    echo "## status mirror=$status" ; echo ""

    spack buildcache update-index build-cache
    status=${PIPESTATUS[0]}
    echo "## status update-index=$status" ; echo ""

    opt="--no-check-signature"
    #[[ -d ${BUILD_CACHE_DIR}/build_cache ]] && opt="--use-buildcache only --no-check-signature"
    spack install -y $verbose $opt 2>&1 | tee log.install
    status=${PIPESTATUS[0]}
    echo "## status install=$status [daily]" ; echo ""

    spack clean -a

    spack buildcache create -a -u ${BUILD_CACHE_DIR}
    status=${PIPESTATUS[0]}
    echo "## status create=$status [daily]" ; echo ""

  fi

  # Because log.install can be huge and not suitable for email:
  egrep "   ${WORKSPACE}|^==> " log.install | egrep -v "^==> Fetching " > log.install-sum

  echo "## spack mirror list"
  spack mirror list

  if [[ ${PLATFORM_NAME} == derecho ]]; then
      exit $status
  fi

  yes "y" 2>/dev/null | spack module lmod refresh -y | tee log.refresh
  status=${PIPESTATUS[1]}
  echo "## status refresh=$status" ; echo ""

  yes "y" 2>/dev/null | spack stack setup-meta-modules | tee log.meta-modules
  status=${PIPESTATUS[1]}
  echo "## status meta-modules=$status" ; echo ""

  spack env deactivate

fi
set +x

(
  set -x
  ls -al ${APP_DIR}/*/envs/.
  ls -al $(dirname ${BUILD_CACHE_DIR})/..
  ls -al $(dirname ${BUILD_CACHE_DIR})
  #find ${BUILD_CACHE_DIR} -type f -ls
)

exit $status

