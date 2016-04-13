#!/bin/sh
#
# FOAMkit: Project management for OpenFOAM
#
# runtools.sh - Functions for running OpenFOAM applications.
#

getApplication()
{
    sed -ne 's/^ *application\s*\([a-zA-Z]*\)\s*;.*$/\1/p' system/controlDict
}

runInBackground()
{
    APP_NAME=$1
    shift

    APP_RUN=$1
    shift

    # Run in the background and save the pid
    $APP_RUN "$@" &

    PID=$!

    echo "$APP_NAME $PID" > currentapp.txt

    wait
    rm currentapp.txt
}

runApplication()
{
    APP_RUN=$1
    APP_NAME=${1##*/}
    shift

    SIM_DIR=$1
    shift

    echo "Begin $APP_RUN"
    start=$SECONDS

    runInBackground $APP_RUN $APP_RUN "$@" >> $SIM_DIR/log.$APP_NAME 2>&1

    diff=$((SECONDS - start))
    echo "End $APP_RUN in $(($diff / 3600))h $((($diff / 60) % 60))m $(($diff % 60))s"
}

runCustom()
{
    APP_RUN=$1
    APP_NAME=${1##*/}
    shift

    SIM_DIR=$1
    shift

    SIM_OUTFILE=$1
    shift

    runApplication $APP_RUN $SIM_DIR "$@"

    mv $SIM_DIR/log.$APP_NAME $SIM_DIR/log.$SIM_OUTFILE
}

runParallel()
{
    APP_RUN=$1
    APP_NAME=${1##*/}
    shift

    SIM_DIR=$1
    shift

    nProcs=$1
    shift

    echo "Begin $APP_RUN in parallel on $PWD using $nProcs processes"
    start=$SECONDS

    ( runInBackground $APP_RUN mpirun -np $nProcs $APP_RUN -parallel "$@" < /dev/null >> $SIM_DIR/log.$APP_NAME 2>&1 )

    diff=$((SECONDS - start))
    echo "End $APP_RUN in $(($diff / 3600))h $((($diff / 60) % 60))m $(($diff % 60))s"
}

endApplication()
{
    APP_NAME=$1
    shift

    # See if the app is running
    line=$(cat currentapp.txt | grep $APP_NAME)

    if [ $? != "0" ]; then
        CURRENT_APP=$(echo "$line" | grep -o '$[^ ]')
        echo "Application $APP_NAME not running."
    else
        PID=$(echo "$line" | grep -o '[0-9]*$')
        foamEndJob $PID
    fi
}

