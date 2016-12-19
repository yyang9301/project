#!/bin/bash

#-----------------------------------------------
#   This is a shell script for setting up a
# multi-sub ensemble tasks by perturbing the 
# initial T field with white noise. You should 
# set the basic parameters as below. Good Luck!
#
# 2015-11-17 Created
# 2016-12-18 Change to fit Tianhe2
#
#                      A L_Zealot Product
#-----------------------------------------------

#=========================================================
# 1. The following namelist variables must be set properly
# in your case env_run.xml
#
#   RUN_TYPE="hybrid" (and relavant configurations)
#
# 2. Please set "ncdata" namelist variable in user_nl_cam,
# which share the same name as NC_INIT_F
#
# 3. Please check your specific init conditions and restart
# files are in the proper dir, also provide your rpointers 
# in a separate dir
#=========================================================

#*************************************************************
#--------------Below for user defined part--------------------
#*************************************************************


# Workspace Path
WPATH=PRD-Trans-2015

# Case Name
CASENAME=`basename $WPATH`

# Storage Path
SPATH=PRD-Trans-2015

# Storage Dir Prefix 
SDPRE=ESM_

# Init Dir PATH (must be a separate dir)
INIT_DIR=init-pmctrl

# Init File Name (same as ncdata in user_nl_cam)
NC_INIT_F=PRD-Trans-2015.cam.i.0006-01-01-00000.nc

# Rpointer Dir (must be a separate dir)
RP_DIR=rpoint

# Ensemble Members
N_ESM=10

# Standard Divation of Normal Distributed Perturbation in T Field (Kelvin)
T_PURB=0.05

#*************Below to execute the changes*********************
# WARNING:
#   If you are willing to change anything below, you need to be
# VERY CAREFUL to do so.
#*************************************************************
echo "                                                              "
echo "*******************CESM ENSEMBLE RUN SCRIPT*******************"
echo "You may use this script with full access, and any kind of     "
echo "redistribution. It's totally Open-sourced!                    "
echo "                                                              "
echo "     Contact: http://met.sysu.edu.cn/GloCli/Team/?page_id=1008"
echo "                                            A L_Zealot Product"
echo "                                                    2016/12/18"
echo "**************************************************************"
echo "                                                              "

echo "Current working PATH: ${WPATH}"
# Init DIR Validation
if [ $INIT_DIR == "" ] || [ ! -d $INIT_DIR ]; then
    echo "PATH: \"${INIT_DIR}\" NO FOUND! Please check it!"
    exit 1
fi

# Backup rpointer files and initial files 
$RP_DIR=${WPATH}/rpoint
if [ ! -d $RP_DIR ]; then
    mkdir $RP_DIR
fi
cp ${WPATH}/run/rpoint* $RP_DIR
cp $INIT_DIR/$INIT_NAME $INIT_DIR/${INIT_NAME}.org


NCL_INIT_PATH=\"${INIT_DIR}${INIT_NAME}/\"


# Main Loop
for II in `seq 1 $N_ESM`
do
    echo "ESM${II}/${N_ESM}, with init condition: ${INIT_NAME}, is processing!"
    
    # Perturb initial filed
    ncl -nQ pre_dir=$NCL_INIT_PATH  \
        t_purb=$T_PURB              \
        ../ncl/perturb_init_T-161219.ncl

    
    # Submit task
    $WPATH/$CASENAME.run >& /dev/null
    echo "ESM${II}/${N_ESM}, with perturbated init condition: ${INIT_NAME}, has been submitted!"
    sleep 60
    
    #Check status
    if [ -f "$WPATH/run/cesm.log" ]; then 
        echo "Found cesm.log!"

    else
        echo "cesm.log not found, problem may occured, please check the run."    
        exit
    fi
    
    # Loop until finished
    while [ "1" == "1" ]
    do
        
        # Check status
        $LOG_SIZE0=`ls -l ${WPATH}/run/cesm.log | awk '{ print $5 }'`
        echo "cesm.log with size ${LOG_SIZE0} byte detected."
        TIMER=$(date)" ${CASENAME} ESM${II}/${N_ESM} is still running..."
        echo $TIMER

        sleep 180
        
        $LOG_SIZE1=`ls -l ${WPATH}/run/cesm.log | awk '{ print $5 }'`
        
        if [ "$LOG_SIZE0" -eq "$LOG_SIZE1" -a $LOG_SIZE1 -gt 102400 ]; then
            
            FINISH=$(date)" ESM${II}/${N_ESM} finished!!! "
            echo "                                  "
            echo "**********************************"
            echo $FINISH
            echo "**********************************"
            echo "                                  "
            
            # post process the output
            echo "Post process, moving history files..."
            if [ ! -d $SPATH ]; then
                mkdir $SPATH
            fi
            mkdir $SPATH/${SDPRE}${II}
            mv $WPATH/run/*cam.h* $SPATH/${SDPRE}${II}
            break

        else
            if [ "$LOG_SIZE0" -eq "$LOG_SIZE1" ]; then
                echo "Log file size increment stopped, please check if ESM${II}/${N_ESM} failed."
                exit
            fi
        fi
    done
    
       
    # Move back the init file
    cp  $INIT_DIR/${INIT_NAME}.org $INIT_DIR/$INIT_NAME
    if [ $II == $N_ESM ]; then
        echo "                                                              "
        echo "*******************CESM ENSEMBLE RUN SCRIPT*******************"
        echo "                                                              "
        echo "                                                              "
        echo "              CONGRATULATIONS!!! ALL TASKS DONE!!!            "
        echo "                                                              "
        echo "                                                              "
        echo "                                            A L_Zealot Product"
        echo "                                                    2016/12/18"
        echo "**************************************************************"
        echo "                                                              "
    fi

done


