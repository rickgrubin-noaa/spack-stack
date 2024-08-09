#!/bin/bash

# Script to execute a specific test suite on the specific host using the specified compiler(s)

# INPUTS:
#   branch_name [defaults to 'develop']
#   machine_name [or auto-detect]
#   compiler [all|intel|gnu]
#   workspace [default to $PWD]
#   test_suite [... establish a default ...]

# Return Code: 0 on success, non-zero on failure
