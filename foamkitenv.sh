#!/bin/sh
#
# FOAMkit: Project management for OpenFOAM
#
# foamkitenv.sh - Environment variables for FOAMkit.
#

###############################################################################
# GENERAL KIT SETTINGS                                                        #
###############################################################################

#
# The directory foamkit is in, i.e. the directory containing this file (foamkitenv.sh).
#
export FOAMKIT_ROOT=$HOME/foamkit

#
# The directory where simulation and output data should go. It should
# not have spaces in it.
#
export FOAMKIT_SIM=%%CASE_DIR%%/sim

#
# The directory OpenFOAM is in.
#
export FOAMKIT_OF_ROOT=$WM_PROJECT_DIR

#
# The OpenFOAM version to target.
#
export FOAMKIT_OF_VERSION=$WM_PROJECT_VERSION

#
# The number of processors to use for commands that can be parallelized.
#
export FOAMKIT_NUM_PROCS=$(nproc)

###############################################################################
# The lines below should not need to be changed.                              #
###############################################################################

alias foamkit="$FOAMKIT_ROOT/foamkit.pl"

