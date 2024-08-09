#!/bin/bash

# Script to setup the working directory with dependent source code, branch, data, and any host-specific settings before build.sh

# INPUTS:
#   branch_name [defaults to 'develop']
#   machine_name [or auto-detect]
#   compiler [all|intel|gnu]
#   workspace [default to $PWD]
#   clean [boolean weather to first clear out any previous build, cache, data, ...]

# Return Code: 0 on success, non-zero on failure
