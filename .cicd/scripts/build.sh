#!/bin/bash

# Script to build from dependent source code and branch on the specific host using the specified compiler(s)

# INPUTS:
#   branch_name [defaults to 'develop']
#   machine_name [or auto-detect]
#   compiler [all|intel|gnu]
#   workspace [default to $PWD]

# Return Code: 0 on success, non-zero on failure
