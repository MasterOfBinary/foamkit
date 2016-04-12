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
# CONTROL SETTINGS                                                            #
###############################################################################

#
# Whether to use a variable timestep (based on a maximum Courant number). 0/1
# or true/false.
#
export FOAMKIT_CONTROL_VARIABLE_TIMESTEP=1

#
# Timestep (in seconds).
#
export FOAMKIT_CONTROL_TIMESTEP="1e-4"

#
# The amount of time to simulate (in seconds). NOTE: if this is more than 10
# the postproc.sh script will need to be fixed.
#
export FOAMKIT_CONTROL_SIM_TIME=5

###############################################################################
# The lines below should not need to be changed.                              #
###############################################################################

alias foamkit="$FOAMKIT_ROOT/foamkit.pl"

