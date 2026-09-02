module --force purge
# for EPIC-installed oneAPI compiler
module use /apps/contrib/spack-stack/modulefiles
# for system-installed oneAPI MPI
module use /apps/spack-managed-x86_64_v3-v1.0/modulefiles/intel-oneapi-compilers/2025.3.1
# required for package recipes that rely on git-lfs
module load git-lfs
