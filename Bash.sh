#!/bin/bash

#Param1 run_id
#Param2 DISCOVER SCAN CLASSIFY ALL REDO

# ------------------------------------------------
#functions
# ------------------------------------------------


# print the header information
fn_header () {
echo "-------------------------------"
echo "Data-Sentinel Monitor Utility"
echo "v.20230114" 
echo "-------------------------------"
echo "Usage:"
echo "-------------------------------"
echo 
echo "sudo ./ds-monitor-{version}.sh (run_id) (action)"
echo "Option 1: run_id"
echo "Option 2: action ('DISCOVER', 'SCAN', 'CLASSIFY', 'ALL' or 'REDO' or 'RECLASSIFY')"
echo "Note: current 'run_id' and 'ALL' will default if not specified"
echo "-------------------------------"
}


# extract right element of delimted string
# val="$(fn_email "exchange joe@data-sentinel.com") --> returns joe@data-sentinel.com
fn_email () {
  input=$1
  echo $input | awk '{print $NF}'
}

# check status of data connection
fn_connection_test () {
  echo "$(date +%F-%H:%M:%S) Checking Connection Status: con_id: $con_id, agent_id: $agent_id"
  qry="select sentinelapi.get_test_connection($con_id,$agent_id)->>'status'"

  test='ERROR'

  i='0'
  while [[ "$test" == 'ERROR' ]] && [[ "$i" != '4' ]]
  do
    test=`$PSQL_CALL "$qry"`
    i=$((i+1))
    echo "Connection Test Result($i/10): $test"
    if [[ "$test" == 'ERROR' ]]; then sleep 15s; fi
  done
}

# remove and restart the scanner container
fn_start_scanner () {
    echo "$(date +%F-%H:%M:%S) Scanner Container Reset (Step 1/2)"
    echo "docker rm -->$DOCKRM_SCAN_CONTAINER"
    $DOCKRM_SCAN_CONTAINER
    sleep $SLEEP_RESTART
    echo "$(date +%F-%H:%M:%S) Scanner Container Reset (Step 1/2)"
    echo "Docker Run -->$DOCKRUN_SCAN_CONTAINER"
    $DOCKRUN_SCAN_CONTAINER
    sleep $SLEEP_RESTART
}



# ------------------------------------------------
# REFERENCE INFO
# ------------------------------------------------

# Database Connection Info
DATABASE=data-sentinel
USERNAME=postgres
HOSTNAME=127.0.0.1
pgpwd=`echo U3BlZWRvNjckCg== | base64 --decode`
export PGPASSWORD=$pgpwd

# Names of Primary or Secondary Log Files For the run_id
LOGDIR=/data/logs
DATADIR=/data

# Parameters From OS Command Line
MAX_RUN_ID=$1
OPERATION_TO_WATCH=$2

if [[ "$OPERATION_TO_WATCH" == '' ]]; then
  OPERATION_TO_WATCH='ALL'
fi

# ------------------------------------------------
# REDO or RECLASSIFY preparation (with warnings)
# ------------------------------------------------

# redo:  reprocess all steps
REDO=''
if [[ "$OPERATION_TO_WATCH" == 'REDO' ]]; then
  OPERATION_TO_WATCH='ALL'
  REDO='REDO'
fi

#  reclassify
if [[ "$OPERATION_TO_WATCH" == 'RECLASSIFY' ]]; then
  OPERATION_TO_WATCH='CLASSIFY'
  REDO='RECLASSIFY'
fi

# Postgres Command Syntax
# Convert to function
PSQL_CALL="psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "






# --------------------
# Start Process Monitoring
# --------------------
#read -p "start monitor [ENTER]"

clear

#show header info
fn_header

# Determine RUN_ID and Operation (if not specified) as these values are used within other variables
# If run_id is not specified as parameter --> find unprocessed discover or scan job
if [[ "$MAX_RUN_ID" == '' ]]; then
  RUN_ID_RESULT=''

  # look for run where discovery is not started
  if [[ $RUN_ID_RESULT = '' ]]; then
    RUN_ID="select max(run_id) from sentinel.process_runs where discovery_start_dt is null"
    RUN_ID_RESULT=`$PSQL_CALL "$RUN_ID"`
  fi

  # look for run where neither discovery or scan has started
  if [[ $RUN_ID_RESULT = '' ]]; then
    RUN_ID="select max(run_id) from sentinel.process_runs where discovery_end_dt is not null and scan_start_dt is null"
    RUN_ID_RESULT=`$PSQL_CALL "$RUN_ID"`
  fi

  # if no un-processed job exists, exit
  if [[ $RUN_ID_RESULT = '' ]]; then
    echo "Run_ID For New Discovery or New Scanning Not Found"
    echo "-------------------------------"
    OPERATION_TO_WATCH='FAIL'
  fi

  MAX_RUN_ID=$RUN_ID_RESULT
  echo  "RUN_ID Not Specified --> Processing run_id $MAX_RUN_ID (CTRL-C 10s to cancel)"
  echo "-------------------------------"
  sleep 10s

fi




# --------------------
# Pre-Scan Checks and Queries
# --------------------
#read -p "pre-scan checks [ENTER]"

# Location of system log files
DISCLOG=${LOGDIR}/ds_discrun_${MAX_RUN_ID}.log
CLASSLOG=${LOGDIR}/ds_classrun_${MAX_RUN_ID}.log
SCANLOG=${LOGDIR}/ds_scanrun_${MAX_RUN_ID}.log

# Check For Valid run_id and exit if needed
CHECK_RUN_ID="select run_id from sentinel.process_runs where run_id = $MAX_RUN_ID"
CHECK_RUN_ID_RESULT=`$PSQL_CALL "$CHECK_RUN_ID"`

if [[ "$CHECK_RUN_ID_RESULT" == '' ]];  then
  echo
  echo "Invalid run_id: $MAX_RUN_ID"
  echo "-------------------------------"
  OPERATION_TO_WATCH='FAIL'

#need to indent
else
#need to indent

echo "Summary:"
echo "-------------------------------"
echo

echo "Run ID: $MAX_RUN_ID"
echo "Activity: $OPERATION_TO_WATCH"

# Get Connection ID
qry="select min(con_id) from sentinel.process_runs where run_id=$MAX_RUN_ID"
con_id=`$PSQL_CALL "$qry"`
echo "Connection ID: $con_id"

# Get con_name
qry="select min(con_name) from sentinel.dataconnections where con_id=$con_id"
con_name=`$PSQL_CALL "$qry"`
echo "Connection Name: $con_name"

# Get con_type
qry="select min(con_type) from sentinel.dataconnections where con_id=$con_id"
con_type=`$PSQL_CALL "$qry"`
echo "Connection Type: $con_type"

# Get Agent ID
qry="select min(agent_id) from sentinel.dataconnections where con_id=$con_id"
agent_id=`$PSQL_CALL "$qry"`
echo "Agent ID: $agent_id"

# Get Port Number
qry="select agent_port from sentinel.agents where agent_id=$agent_id"
agent_port=`$PSQL_CALL "$qry"`
echo "Agent Port: $agent_port"
sleep 10s


# How Long to Wait for Files Before Seeing An Update
SLEEP_RESTART=20s

# set wait times for file/table to see a change and overall and max times
case $con_type in
 'exchange'|'sharepoint'|'onedrive')
   SLEEP_TIME=60s
   MAX_TIME=3600s
   ;;
 'directory')
   SLEEP_TIME=120s
   MAX_TIME=3600s
   ;;
 *)
  SLEEP_TIME=60s
  MAX_TIME=3600s
  ;;
esac

echo "Time Allowance: For $con_type: $SLEEP_TIME  Total Time: $MAX_TIME"



# ---------------------------------------------
# Docker Restart Commands (Command Line)
# ---------------------------------------------

#classifier
RESTART_CLASS_CONTAINER="sudo docker container restart ds-classify"
STOP_CLASS_CONTAINER="sudo docker container stop ds-classify"
START_CLASS_CONTAINER="sudo docker container start ds-classify"

#repository
RESTART_REPOSITORY="sudo docker container restart ds-repository"

#scanner image and tag
scan_image_tag=$(sudo docker images --format '{{.Repository}}:{{.Tag}}' | grep "scan")

# default commands
RESTART_SCAN_CONTAINER="sudo docker container restart ds-scanner-$agent_port"
STOP_SCAN_CONTAINER="sudo docker container stop ds-scanner-$agent_port"
START_SCAN_CONTAINER="sudo docker container start ds-scanner-$agent_port"

DOCKRUN_SCAN_CONTAINER="sudo docker run -d -it --name ds-scanner-$agent_port -p $agent_port:9000 -v /tmp:/tmp -v /home:/home -v $DATADIR:/mnt -v $DATADIR/logs:/mnt/logs -v $DATADIR/datasets:/mnt/datasets -v $DATADIR/config:/mnt/config $scan_image_tag"

#DOCKRUN_SCAN_CONTAINER="sudo docker run -rm -it --name ds-scanner-$agent_port -p $agent_port:9000 -v /tmp:/tmp -v /home:/home -v $DATADIR:/mnt -v $DATADIR/logs:/mnt/logs -v $DATADIR/datasets:/mnt/datasets -v $DATADIR/config:/mnt/config $scan_image_tag"

DOCKRM_SCAN_CONTAINER="sudo docker container rm --force ds-scanner-$agent_port"

# container ds-scanner does not have the port number as suffix on the name
if [[ "$agent_port" == '9000' ]];  then
  RESTART_SCAN_CONTAINER="sudo docker container restart ds-scanner"
  START_SCAN_CONTAINER="sudo docker container start ds-scanner"
  STOP_SCAN_CONTAINER="sudo docker container stop ds-scanner"
  DOCKRUN_SCAN_CONTAINER="sudo docker run -d -it --name ds-scanner -p 9000:9000 -v /tmp:/tmp -v /home:/home -v $DATADIR:/mnt -v $DATADIR/logs:/mnt/logs -v $DATADIR/datasets:/mnt/datasets -v $DATADIR/config:/mnt/config $scan_image_tag"
  DOCKRM_SCAN_CONTAINER="sudo docker container rm --force ds-scanner"
fi

# update number of rows to scan from default
SCAN_CONFIG_SQL_RECS="update sentinel.process_runs set config_list_json = jsonb_set(config_list_json,'{sample_size}','"${SQL_RECS}"') where run_id= ${MAX_RUN_ID}"

# Process initiation Commands (via Postgres)
POST_SUBMIT_DISCOVERY="select sentinelapi.post_submit_for_discovery(${MAX_RUN_ID})"
POST_SUBMIT_SCAN="select sentinelapi.post_submit_for_scan(${MAX_RUN_ID})"
POST_SUBMIT_CLASSIFY="select sentinelapi.post_submit_for_classify(${MAX_RUN_ID})"

# Check if Discovery is Done (via Postgres)
DISC_STARTED="select min(discovery_start_dt) from sentinel.process_runs where run_id=$MAX_RUN_ID"
DISC_COMPLETED="select min(discovery_end_dt) from sentinel.process_runs where run_id=$MAX_RUN_ID"

# Count Scan Items (via Postgres)
SCAN_TOTAL="select count(*) from sentinel.objects where to_scan=true and run_id=$MAX_RUN_ID" 
SCAN_TODO="select count(*) from sentinel.objects where to_scan=true and scanned_dt is null and run_id=$MAX_RUN_ID"
SCAN_DONE="select count(*) from sentinel.objects where to_scan=true and scanned_dt is not null and run_id=$MAX_RUN_ID"

# Count Classify Items (via Postgres)
CLASS_TOTAL="select count(*) from sentinel.objects where to_scan=true and scanned_dt is not null and run_id=$MAX_RUN_ID" 
CLASS_TODO="select count(*) from sentinel.objects where to_scan=true and scanned_dt is not null and classified_dt is null and run_id=$MAX_RUN_ID"
CLASS_DONE="select count(*) from sentinel.objects where to_scan=true and classified_dt is not null and run_id=$MAX_RUN_ID"

# Clean Up Commands (Postgres)
SCAN_BAD_OBJ_JSON="update sentinel.objects set status_json = null where to_scan = true and status_json = '{}' and run_id = ${MAX_RUN_ID}"

SCAN_ERROR_REMOVE_NEXT_OBJECT="update sentinel.objects set run_id= -1 * run_id where obj_id = (select min(obj_id) from sentinel.objects where to_scan=true and scanned_dt is null and obj_id > '${BAD_OBJ_ID}' and run_id = ${MAX_RUN_ID})"

CLASS_BAD_ZERO_RECS="update sentinel.objects set scanned_dt=null, to_scan=false where metadata_json->>'size/rows'='0' and run_id=${MAX_RUN_ID}"

CLASS_BAD_ZERO_RECS_COUNT="select count(*) from sentinel.objects where metadata_json->>'size/rows'='0' and scanned_dt is not null and run_id=${MAX_RUN_ID}"
CLASS_ERROR_REMOVE_NEXT_OBJECT="update sentinel.objects set run_id=-1*${MAX_RUN_ID} where obj_id = (select min(obj_id) from sentinel.objects where classified_dt is null and run_id = ${MAX_RUN_ID}"
CLASS_ERROR_REMOVE_CURRENT_OBJECT="update sentinel.objects set run_id=-1*${MAX_RUN_ID} where obj_id = (select min(obj_id) from sentinel.objects where classified_dt is null and run_id = ${MAX_RUN_ID}"
CLASS_ERROR_REMOVE_ZERO_RECS="update sentinel.objects set run_id=-1*run_id where metadata_json->> 'size/rows' = '0' and run_id=${MAX_RUN_ID}"
CLASS_ERROR_JSON_STATUS_EMPTY="update sentinel.objects set run_id = -1*run_id where run_id=${MAX_RUN_ID} and status_json='{}'"
SCAN_EMAIL_DUPES_COUNT="select count(*) from sentinel.objects dupes where exists (select * from sentinel.objects obj where obj.obj_id < dupes.obj_id and obj.run_id = dupes.run_id and obj.parent_obj_id = dupes.parent_obj_id and obj.obj_name = dupes.obj_name and obj.metadata_json = dupes.metadata_json) and dupes.subtype='email-attach' and dupes.run_id = ${MAX_RUN_ID}"
SCAN_EMAIL_DUPES="delete from sentinel.objects dupes where exists (select * from sentinel.objects obj where obj.obj_id < dupes.obj_id and obj.run_id = dupes.run_id and obj.parent_obj_id  = dupes.parent_obj_id and obj.obj_name = dupes.obj_name and obj.metadata_json = dupes.metadata_json) and dupes.subtype='email-attach' and dupes.run_id = ${MAX_RUN_ID}"
SCAN_REMOVE_IMAGES_COUNT="select count(*) from sentinel.objects where upper(right(obj_name,4)) in ('.JPG', '.GIF', 'JPEG', 'TIFF', '.PNG', '.RAW', '.PSD', '.EPS') and run_id=${MAX_RUN_ID} and to_scan=true"
SCAN_REMOVE_IMAGES="update sentinel.objects set to_scan = false, scanned_dt=null where upper(right(obj_name,4)) in ('.JPG', '.GIF', 'JPEG', 'TIFF', '.PNG', '.RAW', '.PSD', '.EPS') and run_id=${MAX_RUN_ID} and to_scan=true"


echo "-------------------------------"
echo

# --------------------
# REDO
# --------------------
#read -p "redo [ENTER]"

if [[ "$REDO" == 'REDO' ]]; then

  START_TIME=$(date +%F-%H:%M:%S)

  echo
  echo "-------------------------------"
  echo "REDO: ${MAX_RUN_ID}"
  echo "Start: $START_TIME"
  echo "-------------------------------"

  echo "Warning:  Scan data for run_id $MAX_RUN_ID will be removed [CTRL-C to cancel]"
  sleep 15s

  echo "Rename existing logfiles ..."
  if [[ -f "$DISCLOG" ]]; then echo `mv $DISCLOG $DISCLOG_REDO$(date +%F-%H:%M:%S)`; fi
  if [[ -f "$SCANLOG" ]]; then echo `mv $SCANLOG $SCANLOG_REDO$(date +%F-%H:%M:%S)`; fi
  if [[ -f "$CLASSLOG" ]]; then echo `mv $CLASSLOG $CLASSLOG_REDO$(date +%F-%H:%M:%S)`; fi

  echo "Reset database entries ..."
  echo "Reset process_runs based on run_id..."

  qry="update sentinel.process_runs set discovery_start_dt=null, discovery_end_dt=null, scan_start_dt=null, classify_start_dt=null, profile_start_dt=null where run_id=$MAX_RUN_ID"
#  echo `$PSQL_CALL "$qry"`
  echo `$PSQL_CALL "$qry">/dev/null 2>&1 &`
  sleep 2s

  qry="select discovery_start_dt, discovery_end_dt from sentinel.process_runs where run_id=$MAX_RUN_ID"
  echo `$PSQL_CALL "$qry">/dev/null 2>&1 &`
#  echo `$PSQL_CALL "$qry"`
  sleep 2s

  echo "Delete tags based on run_id..."
  qry="delete from sentinel.tags where run_id=$MAX_RUN_ID or run_id=-1*$MAX_RUN_ID"
  echo `$PSQL_CALL "$qry">/dev/null 2>&1 &`
#  echo `$PSQL_CALL "$qry"`
  sleep 1s

  echo "Delete objects based on run_id ..."
  qry="delete from sentinel.objects where run_id=$MAX_RUN_ID or run_id=-1*$MAX_RUN_ID"
#  echo `$PSQL_CALL "$qry"`
  echo `$PSQL_CALL "$qry">/dev/null 2>&1 &`
  sleep 1s

  echo  
  echo "REDO Preparation Steps Completed"
  echo
  sleep 1s

fi


# --------------------
# RECLASSIFY
# --------------------
#read -p "redo [ENTER]"

if [[ "$REDO" == 'RECLASSIFY' ]]; then

  START_TIME=$(date +%F-%H:%M:%S)

  echo
  echo "-------------------------------"
  echo "RECLASSIFY: ${MAX_RUN_ID}"
  echo "Start: $START_TIME"
  echo "-------------------------------"

  echo "Warning: Classification data for run_id $MAX_RUN_ID will be removed [CTRL-C to cancel]"
  sleep 15s

  echo "Rename existing logfiles ..."
  if [[ -f "$CLASSLOG" ]]; then echo `mv $CLASSLOG $CLASSLOG_REDO$(date +%F-%H:%M:%S)`; fi

  echo "Reset database entries ..."
  echo "Reset process_runs based on run_id..."
  qry="update sentinel.process_runs set classify_start_dt=null, profile_start_dt=null where run_id=$MAX_RUN_ID"
  echo `$PSQL_CALL "$qry">/dev/null 2>&1 &`
#  echo `$PSQL_CALL "$qry"`
  sleep 1s

  echo "Update objects to clear classified_dt where it was populated and based on run_id..."
  qry="update sentinel.objects set classified_dt = null where classified_dt is not null and run_id=$MAX_RUN_ID"
#  echo `$PSQL_CALL "$qry"`
  echo `$PSQL_CALL "$qry">/dev/null 2>&1 &`
  sleep 1s

  echo "Delete tags based on run_id..."
  qry="delete from sentinel.tags where run_id=$MAX_RUN_ID or run_id=-1*$MAX_RUN_ID"
  echo `$PSQL_CALL "$qry">/dev/null 2>&1 &`
#  echo `$PSQL_CALL "$qry"`
  sleep 1s

  echo "RECLASSIFY Preparation Steps Completed"
  echo
  echo
  sleep 1s

fi



# --------------------
# Discover
# --------------------
#read -p "Discover [ENTER]"

if [[ "$OPERATION_TO_WATCH" == 'DISCOVER' ]] || [[ "$OPERATION_TO_WATCH" == 'SCAN' ]] || [[ "$OPERATION_TO_WATCH" == 'ALL' ]];  then

  START_TIME=$(date +%F-%H:%M:%S)

  echo "-------------------------------"
  echo "Discover: ${MAX_RUN_ID}"
  echo "Start: $START_TIME"
  echo "-------------------------------"

  PROGRESS=0
  RESTARTS=0
  scanner_started=0
  scanner_running=0

  # Check if discovery logfile exists
  if [[ -f "$DISCLOG" ]]; then
    echo "Discovery Log File Exists"
    echo "Skipping Discovery Process (~3m)"
    sleep 5s
  else
    echo "Discovery Log File Does Not Exist"
    echo "Starting Discovery Process (~3m)"
    echo
    sleep 5s

    # start the scanner
    fn_start_scanner

    # establish a connection to the data source
    fn_connection_test

    # test data source connection and start scan if it succeeds
    if [[ "$test" != 'ERROR' ]]; then
      echo "Starting Discover Services (~3m)"
      scanner_started='1'
#      echo `$PSQL_CALL "$POST_SUBMIT_DISCOVERY" >/dev/null 2>&1 &`

      $PSQL_CALL "$POST_SUBMIT_DISCOVERY" &

      # wait for discovery log file to be created
      i=0
      while [[ ! -f "$DISCLOG" ]] && [[ "$i" != '10' ]] 
      do
        echo "Waiting For Discovery To Start ($i/10)"
        sleep $SLEEP_RESTART 
        i=$((i+1))
      done
    fi

    # if a discovery log is not created then process has failed
    if [[ ! -f "$DISCLOG" ]] || [[ "$test" = 'ERROR' ]]; then
      echo "$(date +%F-%H:%M:%S) Discover Could Not Complete (Check Logs)"
      OPERATION_TO_WATCH='FAIL'
      DISC_COMPLETED_RESULT='FAIL'
    fi

    # check if discovery has started or maybe completed quickly
    if [[ "$OPERATION_TO_WATCH" != 'FAIL' ]]; then
      echo "Checking 1.shDiscovery Start & End Dates"
      DISC_STARTED_RESULT=`$PSQL_CALL "$DISC_STARTED"`
      DISC_COMPLETED_RESULT=`$PSQL_CALL "$DISC_COMPLETED"`
    fi




    # Discovery is not complete, track the process and see if it is already running 
    while [[ "$DISC_COMPLETED_RESULT" == '' ]]
    do

      #snapshot log
      DISCLOG_T1=`tail -n 50 $DISCLOG`
      #count items in objects tables
      DISC_ITEMS_T1=`$PSQL_CALL "$SCAN_TOTAL"`
      echo "$(date +%F-%H:%M:%S) Items Discovered: $DISC_ITEMS_T1"
      #check if discover is done
      DISC_COMPLETED_RESULT=`$PSQL_CALL "$DISC_COMPLETED"`

      sleep $SLEEP_TIME

      #snapshot log
      DISCLOG_T2=`tail -n 50 $DISCLOG`
      DISC_ITEMS_T2=`$PSQL_CALL "$SCAN_TOTAL"`
      echo "$(date +%F-%H:%M:%S) Items Discovered: $DISC_ITEMS_T2"

      # if log file is updating or number of items discovered has changed, we are making progress
      if [[ "$DISCLOG_T1" != "$DISCLOG_T2" ]] || [[ "$DISC_ITEMS_T1" != "$DISC_ITEMS_T2" ]];  then
        PROGRESS=$((PROGRESS+1))
      else
        RESTARTS=$((RESTARTS+1))

        if [[ "$test" == 'ERROR' ]]; then
          echo "Starting Discover Services (~3m)"
          scanner_started='1'
          echo `$DOCKRM_SCAN_CONTAINER`
          sleep $SLEEP_RESTART
          echo `$DOCKRUN_SCAN_CONTAINER`
          sleep $SLEEP_RESTART
        else
          scanner_running='1'
    #      echo `$PSQL_CALL "$POST_SUBMIT_DISCOVERY"`
#          echo `$PSQL_CALL "$POST_SUBMIT_DISCOVERY" >/dev/null 2>&1 &`
          $PSQL_CALL "$POST_SUBMIT_DISCOVERY" &
          echo "$(date +%F-%H:%M:%S) Scanner Running and Discover Process Started"
        fi

        #exit if no discovery progress is being made or could not connect
        if [[ "$RESTARTS" == '10' ]]; then
          echo "$(date +%F-%H:%M:%S) Discover Could Not Complete (Check Logs)"
          OPERATION_TO_WATCH='FAIL'
          DISC_COMPLETED_RESULT='FAIL'
        fi

      fi

      #stability check for connection
      fn_stability_check

    done





    if [[ "$OPERATION_TO_WATCH" == 'DISCOVER' ]] || [[ "$OPERATION_TO_WATCH" == 'SCAN' ]] || [[ "$OPERATION_TO_WATCH" == 'ALL' ]];  then

# remove images files from scan list
#      SCAN_REMOVE_IMAGES_COUNT_RESULT=`$PSQL_CALL "$SCAN_REMOVE_IMAGES_COUNT"`
#      SCAN_REMOVE_IMAGES_RESULT=`$PSQL_CALL "$SCAN_REMOVE_IMAGES"`
#      echo "Removed Images Files From Scan List:  $SCAN_REMOVE_IMAGES_COUNT_RESULT  -->  $SCAN_REMOVE_IMAGES_RESULT"

      if [[ "$con_type" == 'exchange' ]] && [[ "$con_name" == *'(EXT)' ]]; then

        echo "Exchange --> EXT"
        sleep 5s

        echo "Post-Process exchange discovery"
        qry="update sentinel.objects set to_scan='false' where run_id='${MAX_RUN_ID}'"
        test=`$PSQL_CALL "$qry"`


        echo "$con_name"
        sleep 5s
        con_name=${con_name// (EXT)/}
        echo "$con_name"

        con_name_email=$(fn_email "$con_name")
        echo "Specific Email To Scan:  $con_name_email"
        sleep 5s

#        echo '$con_name_email'
#        echo '$con_name_email'
#        sleep 5s



        echo "Set Email To Scan (1/2): $con_name_email"
        qry="update sentinel.objects set to_scan='true' where run_id=${MAX_RUN_ID} and obj_name = '$con_name_email'"
        echo "update qry:  $qry"
        sleep 5s
   
        test=`$PSQL_CALL "$qry"`
        sleep 5s


        echo "Set Email To Scan (2/2): $con_name_email"
        qry="delete from sentinel.objects where to_scan='false' and run_id='${MAX_RUN_ID}'"
        test=`$PSQL_CALL "$qry"`

      fi

    fi



    # if a container was started and it not a standard container and only a discover was requested then shut it down
    if [[ "$started_scanner" != '0' ]] && [[ "$agent_port" != *"900"* ]] && [[ "$OPERATION_TO_WATCH" == 'DISCOVER' ]]; then
      echo "Discover Container Shutdown (Extended Ports)"
#      echo `$DOCKRM_SCAN_CONTAINER >/dev/null 2>&1 &`
      $DOCKRM_SCAN_CONTAINER &
    else
      echo "Discover Container --> Skip Shutdown"
    fi

    # check that discovery found some items 
    DISC_ITEMS_FINAL=`$PSQL_CALL "$SCAN_TOTAL"`
    if [[ "$DISC_ITEMS_FINAL" == '0' ]]; then
      OPERATION_TO_WATCH='FAIL'
    fi

     
#    # duplicate identification
#    qry="delete from sentinel.objects obj1 where run_id=${MAX_RUN_ID} and exists (select * from sentinel.objects obj2 where obj1.run_id=obj2.run_id and obj1.obj_location=obj2.obj_location and obj1.obj_name=obj2.obj_name and obj2.obj_id<obj1.obj_id)"
#    dupe=`$PSQL_CALL "$qry"`



    echo "Final Discovery Total: run_id ${MAX_RUN_ID} has $DISC_ITEMS_FINAL object(s)"
    echo "Started: $START_TIME" 
    echo "Ended: $(date +%F-%H:%M:%S)"
    echo "Discovery Monitoring Completed  ..."
    echo

  fi

fi



# --------------------
# Scan
# --------------------
#read -p "Scan [ENTER]"

if [[ "$OPERATION_TO_WATCH" == 'SCAN' ]] || [[ "$OPERATION_TO_WATCH" == 'ALL' ]]; then

  START_TIME=$(date +%F-%H:%M:%S)
 
  echo
  echo "-------------------------------"
  echo "Scan: ${MAX_RUN_ID}"
  echo "Start: $START_TIME"
  echo "-------------------------------"

  if [[ ! -f "$DISCLOG" ]]; then
    echo "Discovery Log Does Not Exist"
    echo "Not Ready To Scan"
    OPERATION_TO_WATCH='FAIL'
  else

    PROGRESS=0
    CONSECUTIVE_PROGRESS=0
    CONSECUTIVE_ISSUES=0
    RESTART=0
    RESTART_FLAG=0
    BLOCKED_OBJECTS=0
    BAD_OBJ_PREVIOUS_ID=''
    BAD_OBJ_ID=''
    scanner_started='0'
    scanner_running='0'

    SCAN_REMOVE_IMAGES_COUNT_RESULT=`$PSQL_CALL "$SCAN_REMOVE_IMAGES_COUNT"`
    SCAN_REMOVE_IMAGES_RESULT=`$PSQL_CALL "$SCAN_REMOVE_IMAGES"`
    echo "Remove Image Files From Scan:  $SCAN_REMOVE_IMAGES_COUNT_RESULT  -->  $SCAN_REMOVE_IMAGES_RESULT"

    #check for prior blocked objects
    BLOCKED_OBJECTS_COUNT="select count(*) from sentinel.objects where run_id=-1*${MAX_RUN_ID}"
    BLOCKED_OBJECTS=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${BLOCKED_OBJECTS_COUNT}"`

    #count objects in scope for scan
 #   SCAN_TOTAL_RESULT=`$PSQL_CALL "$SCAN_TOTAL"`
    SCAN_TODO_RESULT=`$PSQL_CALL "$SCAN_TODO"`
 #   SCAN_DONE_RESULT=`$PSQL_CALL "$SCAN_DONE"`

    # correct malformed obj_json values {} ?? exchange ??
    SCAN_BAD_OBJ_JSON_RESULT=`$PSQL_CALL "${SCAN_BAD_OBJ_JSON}"`

    # remove any potential duplicate from discover process
  #  qry="delete from sentinel.objects obj1 where run_id=${MAX_RUN_ID} and exists (select * from sentinel.objects obj2 where obj1.run_id=obj2.run_id and obj1.obj_location=obj2.obj_location and obj1.obj_name=obj2.obj_name and obj2.obj_id<obj1.obj_id)"
  #  dupe=`$PSQL_CALL "$qry"`

#    echo "$(date +%F-%H:%M:%S) Total/ToDo/Done/Blocked: $SCAN_TOTAL_RESULT $SCAN_TODO_RESULT $SCAN_DONE_RESULT $BLOCKED_OBJECTS"

    # start scan if no logfiles exist and there are objects to scan
#    if [[ ! -f "$SCANLOG" ]] && [[ "$SCAN_TODO_RESULT" != '0' ]] ; then
    if [[ "$SCAN_TODO_RESULT" != '0' ]] ; then
      echo "Start or Restart Scan For run_id: ${MAX_RUN_ID}"

      # start scanner container
      fn_start_scanner

      #Perform connection test
      fn_connection_test

      #Start Scan if connection succeeded
      if [[ "$test" != 'ERROR' ]]; then
        echo "Starting Scanner Services (~3m)"
#        echo `$PSQL_CALL "$POST_SUBMIT_SCAN" >/dev/null 2>&1 &`
#        $PSQL_CALL "$POST_SUBMIT_SCAN" &
        $PSQL_CALL "$POST_SUBMIT_SCAN" &
      else
        OPERATION_TO_WATCH='FAIL'
        SCAN_TODO_RESULT='0'
      fi

    fi

  

  # main scan monitoring cycle 
    while [[ "$SCAN_TODO_RESULT" != '0' ]] && [[ "$OPERATION_TO_WATCH" != 'FAIL' ]]
    do

      #count loops
      PROGRESS=$((PROGRESS+1))

      # snapshot #1 for baseline
      SCAN_TOTAL_RESULT_T1=`$PSQL_CALL "$SCAN_TOTAL"`
      SCAN_TODO_RESULT=`$PSQL_CALL "$SCAN_TODO"`
      SCAN_DONE_RESULT_T1=`$PSQL_CALL "$SCAN_DONE"`
      SCANLOG_T1=`tail -n 50 $SCANLOG`
      echo "$(date +%F-%H:%M:%S) Total/ToDo/Done/Blocked: $SCAN_TOTAL_RESULT_T1 $SCAN_TODO_RESULT $SCAN_DONE_RESULT_T1 $BLOCKED_OBJECTS"

      sleep $SLEEP_TIME

      # snapshot #2 for comparison
      SCANLOG_T2=`tail -n 50 $SCANLOG`

      #stability check for connection (removed for 202212 version)
      # fn_stability_check


      # active log with object due to processing activity
      if [[ "$SCANLOG_T1" != "$SCANLOG_T2" ]];  then
        CONSECUTIVE_ISSUES=0
        CONSECUTIVE_PROGRESS=$((CONSECUTIVE_PROGRESS+1))
        echo "Total Progress: $PROGRESS Consecutive Progress/Issues:  $CONSECUTIVE_PROGRESS / $CONSECUTIVE_ISSUES"
      fi

      #frozen log with objects remaining
      if [[ "$SCANLOG_T1" == "$SCANLOG_T2" ]];  then

        BAD_OBJ_ID=''
        CONSECUTIVE_PROGRESS=0
        CONSECUTIVE_ISSUES=$((CONSECUTIVE_ISSUES+1))
        echo "Total Progress: $PROGRESS Consecutive Progress/Issues:  $CONSECUTIVE_PROGRESS / $CONSECUTIVE_ISSUES"

        #check if log file indicates process is completed (it might be right, it might be wrong)
        CHECK_DONE=''
        CHECK_DONE=$(tail -1 $SCANLOG | grep 'Scanner Processing complete')
        echo " ...Checking If Scanner Reports Complete While Objects Remain:  $CHECK_DONE" 
        echo


        #check unicode error conditions and restart if possible which also shows "complete"
        if [[ "$CHECK_DONE" != '' ]] && [[ "$BAD_OBJ_ID" == '' ]]; then 
          CHECK_UNICODE=$(tail -15 $SCANLOG | grep 'unsupported Unicode escape sequence')
          echo "...Checking Unicode Error following process complete Message:  $CHECK_UNICODE"
          if [[ "$CHECK_UNICODE" != '' ]]; then
            NEXT_OBJ_ID="select min(obj_id) from sentinel.objects where run_id=${MAX_RUN_ID} and to_scan=true and scanned_dt is null"
            NEXT_OBJ_ID_RESULT=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${NEXT_OBJ_ID}"`
            if [[ "$NEXT_OBJ_ID_RESULT" != '' ]]; then 
              BAD_OBJ_FIX="update sentinel.objects set run_id=-1*${MAX_RUN_ID} where obj_id=${NEXT_OBJ_ID_RESULT}"
              BAD_OBJ_FIX_RESULT=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${BAD_OBJ_FIX}"`
              echo "...Correcting Unicode Error (Next Object):  $NEXT_OBJ_ID_RESULT --> $BAD_OBJ_FIX_RESULT"
              BAD_OBJ_PREVIOUS_ID=$NEXT_OBJ_ID
              BLOCKED_OBJECTS=$((BLOCKED_OBJECTS+1))
              BAD_OBJ_ID=$NEXT_OBJ_ID_RESULT
            fi
          fi          
        fi

        #error message; log does not show complete; bad_obj not identified yet
        CHECK_ERROR=$(tail -3 $SCANLOG | grep 'ERROR')
        echo " ...Checking General Error Message: $CHECK_ERROR"
        


        i=1
        if [[ "$CHECK_DONE" != '' ]] && [[ "$CHECK_ERROR" != '' ]] && [[ "$BAD_OBJ_ID" == '' ]] ; then
          echo "...Checking General Error Message Following Process Complete Message: $CHECK_ERROR"

          while [[ "$BAD_OBJ_ID" == '' ]] && [[ "$i" != '30' ]]
          do
            BAD_OBJ_ID=`tail -$i $SCANLOG | grep -Eo '\b(Object ID: [0-9 ]+)' | tr -dc '0-9'`
            i=$((i+1))
          done 

          if [[ "$BAD_OBJ_ID" != '' ]]; then 
            BAD_OBJ_FIX="update sentinel.objects set run_id=-1*${MAX_RUN_ID} where obj_id=${BAD_OBJ_ID}"
            BAD_OBJ_RESULT=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${BAD_OBJ_FIX}"`
            echo "...Correcting General Error:  $BAD_OBJ_ID --> $BAD_OBJ_RESULT"
            BAD_OBJ_PREVIOUS_ID=$BAD_OBJ_ID
            BLOCKED_OBJECTS=$((BLOCKED_OBJECTS+1))
          else
            echo "...General Error Detected But Object Could Not Determined: Check Logs"
          fi


        fi

      echo "Note:  Reseting Spark Errors SharePoint"
      RESET_SPARK_ERROR="select count(*) from sentinel.objects where to_scan = 'true' and status_json->>'scan_status' like '%ERROR%' and status_json->>'scan_message' like '%SparkContext%' and run_id = ${MAX_RUN_ID}"
      RESET_SPARK_ERROR_RESULT=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${RESET_SPARK_ERROR}"`
      echo "Spark Error Count (SparkContext): $RESET_SPARK_ERROR_RESULT"

      RESET_SPARK_ERROR="update sentinel.objects set status_json = null, metadata_json = null where to_scan = 'true' and status_json->>'scan_status' like '%ERROR%' and status_json->>'scan_message' like '%SparkContext%' and run_id = ${MAX_RUN_ID}"
      RESET_SPARK_ERROR_RESULT=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${RESET_SPARK_ERROR}"`
      echo "Spark Error Fix (SparkContext): $RESET_SPARK_ERROR_RESULT"
      sleep 5s

      echo "Note:  Reseting Spark Errors (Exchange)"
      RESET_SPARK_ERROR="select count(*) from sentinel.objects where to_scan = 'true' and status_json->>'scan_status' like '%ERROR%' and status_json->>'scan_message' like '%org.apache.spark.sql.catalyst.errors.package$TreeNodeException%' and run_id = ${MAX_RUN_ID}"
      RESET_SPARK_ERROR_RESULT=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${RESET_SPARK_ERROR}"`
      echo "Spark Error Fix (Exchange): $RESET_SPARK_ERROR_RESULT"
      sleep 5s

      echo "Note:  Reseting Spark Errors (Exchange)"
      RESET_SPARK_ERROR="update sentinel.objects set status_json = null, metadata_json = null where to_scan = 'true' and status_json->>'scan_status' like '%ERROR%' and status_json->>'scan_message' like '%org.apache.spark.sql.catalyst.errors.package$TreeNodeException%' and run_id = ${MAX_RUN_ID}"
      RESET_SPARK_ERROR_RESULT=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${RESET_SPARK_ERROR}"`
      echo "Spark Error Fix (Exchange): $RESET_SPARK_ERROR_RESULT"
      sleep 5s


      # check for problematic status_json values ?? exchange
      BAD_OBJ_FIX="update sentinel.objects set status_json=null where to_scan=true and status_json = '{}' and run_id = ${MAX_RUN_ID}"
      BAD_OBJ_RESULT=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${BAD_OBJ_FIX}"`


      if [[ "$BAD_OBJ_ID" == "$BAD_OBJ_PREVIOUS_ID" ]] && [[ "$BAD_OBJ_ID" != '' ]]; then
        echo "Note: Repeated BAD_OBJ_ID: $BAD_OBJ_ID"
        sleep 5s
      fi

      if [[ "$CONSECUTIVE_ISSUES" == '5' ]]; then
           echo "Repeat Issues --> $CONSECUTIVE_ISSUES"
      fi

      if [[ "$CONSECUTIVE_ISSUES" == '10' ]]; then
         echo "Repeat Issues --> $CONSECUTIVE_ISSUES"
      fi

      if [[ "$CONSECUTIVE_ISSUES" == '10' ]]; then
         echo "Exit Scan: (ERROR)"
          OPERATION_TO_WATCH='FAIL'
          SCAN_TODO_RESULT='0'
      else
        echo "Restart Scanner Following Error Handling"

        # start scanner container
        fn_start_scanner

        #  echo `$PSQL_CALL "$POST_SUBMIT_SCAN" >/dev/null 2>&1 &`
        $PSQL_CALL "$POST_SUBMIT_SCAN" &
      fi
     
    fi

   done



   #check if log file indicates process is completed (it might be right, it might be wrong)
   CHECK_DONE=''
   CHECK_DONE=$(tail -1 $SCANLOG | grep 'Scanner Processing complete')
   echo "Scanner Processing Complete Validation:  $CHECK_DONE"



   if [[ "$con_type" == 'exchange' ]]; then
      SCAN_EMAIL_DUPES_COUNT_RESULT=`$PSQL_CALL "$SCAN_EMAIL_DUPES_COUNT"`
      echo "Exchange Duplicate Attachments Count: $SCAN_EMAIL_DUPES_COUNT_RESULT"
   fi

   if [[ "$agent_port" != *"900"* ]]; then
     echo "Scan Container Shutdown"
     echo `$DOCKRM_SCAN_CONTAINER`
     ## remove the scanner, don't just stop it
   else
     echo "Scanner 9000-9004 --> Skip Shutdown"
   fi

   SCAN_TOTAL_RESULT=`$PSQL_CALL "$SCAN_TOTAL"`
   SCAN_TODO_RESULT=`$PSQL_CALL "$SCAN_TODO"`
   SCAN_DONE_RESULT=`$PSQL_CALL "$SCAN_DONE"`


   echo "Final Total/ToDo/Done/Blocked:  $SCAN_TOTAL_RESULT $SCAN_TODO_RESULT $SCAN_DONE_RESULT $BLOCKED_OBJECTS"
   echo "Started: $START_TIME" 
   echo "Ended:   $(date +%F-%H:%M:%S)"
   echo "Scan Monitoring Completed  ..."

  fi

fi



# --------------------
# Classify
# --------------------

if [[ "$OPERATION_TO_WATCH" == 'CLASSIFY' ]] || [[ "$OPERATION_TO_WATCH" == 'ALL' ]]; then

  START_TIME=$(date +%F-%H:%M:%S)

  echo
  echo "-------------------------------"
  echo "Classify: ${MAX_RUN_ID}"
  echo "Start:    $START_TIME"
  echo "-------------------------------"

  # check if disocvery & scan logfile exists
  if [[ ! -f "$DISCLOG" ]] || [[ ! -f "$SCANLOG" ]]; then

    if [[ ! -f "DISCLOG" ]]; then echo "Discovery Log File Does Not Exist"; fi
    if [[ ! -f "SCANLOG" ]]; then echo "Scan Log File Does Not Exist"; fi
    echo "Not Ready To Classify"
    OPERATION_TO_WATCH='FAIL'

  else

    PROGRESS=0
    CONSECUTIVE_ISSUES=0
    CONSECUTIVE_PROGRESS=0
    RESTART=0
    RESTART_FLAG=0
    BLOCKED_OBJECTS=0
    BAD_OBJ_ID=''
    BAD_OBJ_PREVIOUS_ID=''
    CLASS_DONE_RESULT_T1=0
    CLASS_TOTAL_RESULT_T1=0
    CLASS_TODO_RESULT_T1=0
    CLASS_DONE_RESULT_T1=0
    CLASS_DONE_RESULT_T1=0
    CLASS_TOTAL_RESULT_T2=0
    CLASS_TODO_RESULT_T2=0
    CLASS_DONE_RESULT_T2=0


    ## remove records with zero rows to classify as the classifier never finishes them

    CLASS_BAD_ZERO_RECS_COUNT_RESULT=`$PSQL_CALL "${CLASS_BAD_ZERO_RECS_COUNT}"`
    CLASS_BAD_ZERO_RECS_RESULT=`$PSQL_CALL "${CLASS_BAD_ZERO_RECS}"`
    echo "Count & Ignore Objects with size/rows=0:  $CLASS_BAD_ZERO_RECS_COUNT_RESULT"
    sleep 5s

#    # remove duplicate email attachments and email images (if present)
#    if [[ "$con_type" == 'exchange' ]]; then

#      SCAN_EMAIL_DUPES_COUNT_RESULT=`$PSQL_CALL "$SCAN_EMAIL_DUPES_COUNT"`
#      SCAN_EMAIL_DUPES_RESULT=`$PSQL_CALL "$SCAN_EMAIL_DUPES"`
#      echo "Exchange Duplicate Attachments Count: $SCAN_EMAIL_DUPES_COUNT_RESULT"

#      SCAN_REMOVE_IMAGES_COUNT=`$PSQL_CALL "$SCAN_REMOVE_IMAGES_COUNT"`
#      SCAN_REMOVE_IMAGES=`$PSQL_CALL "$SCAN_REMOVE_IMAGES"`
#      echo "Exchange Image Attachment Count: $SCAN_REMOVE_IMAGES_COUNT"

#    fi



    # eliminate records that didn't scan correctly
    CLASS_SCAN_ERROR="select count(*) from sentinel.objects where status_json->>'scan_status' like '%ERROR%' and run_id=${MAX_RUN_ID}"
    CLASS_SCAN_ERROR_COUNT=`$PSQL_CALL "${CLASS_SCAN_ERROR}"`
    

    CLASS_SCAN_ERROR_REMOVE="update sentinel.objects set run_id=-1*${MAX_RUN_ID} where status_json->>'scan_status'='ERROR' and run_id=${MAX_RUN_ID}"
    CLASS_SCAN_ERROR_REMOVE_RESULT=`$PSQL_CALL "${CLASS_SCAN_ERROR_REMOVE}"`
    echo "Remove Objects with status_json->>scan_status of ERROR:  $CLASS_SCAN_ERROR_COUNT"
    sleep 5s


    # count blocked objects from scan phase
    BLOCKED_OBJECTS_COUNT="select count(*) from sentinel.objects where run_id=-1*${MAX_RUN_ID}"
    BLOCKED_OBJECTS=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${BLOCKED_OBJECTS_COUNT}"`

    # count objects
    CLASS_TOTAL_RESULT=`$PSQL_CALL "$CLASS_TOTAL"`
    CLASS_TODO_RESULT=`$PSQL_CALL "$CLASS_TODO"`
    CLASS_DONE_RESULT=`$PSQL_CALL "$CLASS_DONE"`

    echo "Initial Total/ToDo/Done/Blocked: $CLASS_TOTAL_RESULT $CLASS_TODO_RESULT $CLASS_DONE_RESULT $BLOCKED_OBJECTS"





    # check if logfile exists and objects to classify exist
    if [[ -f "$CLASSLOG" ]] && [[ "$CLASS_TODO_RESULT" != '0' ]]; then

      echo "Class Log Found ---> Monitor Running Classify or (Re)start Classify (~3m)"
      CLASS_TOTAL_RESULT_T1=`$PSQL_CALL "$CLASS_TOTAL"`
      CLASS_TODO_RESULT_T1=`$PSQL_CALL "$CLASS_TODO"`
      CLASS_DONE_RESULT_T1=`$PSQL_CALL "$CLASS_DONE"`
      CLASSLOG_T1=`tail $CLASSLOG`
      echo "$(date +%F-%H:%M:%S) Total/ToDo/Done/Blocked: $CLASS_TOTAL_RESULT_T1 $CLASS_TODO_RESULT_T1 $CLASS_DONE_RESULT_T2 $BLOCKED_OBJECTS"

      sleep $SLEEP_TIME

      CLASS_TOTAL_RESULT_T2=`$PSQL_CALL "$CLASS_TOTAL"`
      CLASS_TODO_RESULT_T2=`$PSQL_CALL "$CLASS_TODO"`
      CLASS_DONE_RESULT_T2=`$PSQL_CALL "$CLASS_DONE"`
      CLASSLOG_T2=`tail $CLASSLOG`
      echo "$(date +%F-%H:%M:%S) Total/ToDo/Done/Blocked: $CLASS_TOTAL_RESULT_T2 $CLASS_TODO_RESULT_T2 $CLASS_DONE_RESULT_T2 $BLOCKED_OBJECTS"

      sleep 10s

      #check on progress either by change in log files or classify objects being completed
      if [[ "$CLASSLOG_T1" == "$CLASSLOG_T2" ]] && [[ "$CLASS_DONE_RESULT_T1" == "$CLASS_DONE_RESULT_T2" ]] && [[ "$CLASS_TODO_RESULT_T1" == "$CLASS_TODO_RESULT_T2" ]];  then
        echo "Classify Log Present But Classify for ${MAX_RUN_ID} Is Not Running --> Starting Classify Process (~3m)"
        #DOCKRM_CLASS_CONTAINER_RESULT=`$DOCKRM_CLASS_CONTAINER >/dev/null 2>&1`
        #DOCKRUN_CLASS_CONTAINER_RESULT=`$DOCKRUN_CLASS_CONTAINER >/dev/null 2>&1`
##        echo `$PSQL_CALL "$POST_SUBMIT_CLASSIFY"`
        $PSQL_CALL "$POST_SUBMIT_CLASSIFY"
        echo "Classifier For ${MAX_RUN_ID} Started"
        sleep $SLEEP_RESTART
      else
        echo "Classify Log Present And Classify For ${MAX_RUN_ID} Is Running"
        CLASS_TODO_RESULT=`$PSQL_CALL "$CLASS_TODO"`
      fi

    fi



    # if logfile does not exist and objects to classify exist then start the classifier
    if [[ ! -f "$CLASSLOG" ]] && [[ "$CLASS_TODO_RESULT" != '0' ]] ; then
#    if [[ "$CLASS_TODO_RESULT" != '0' ]] ; then

      echo "Classify Log Not Found ---> Start Classify (~3m)"
#      echo `$PSQL_CALL "$POST_SUBMIT_CLASSIFY"`
      $PSQL_CALL "$POST_SUBMIT_CLASSIFY"

      echo "Classifier Container Reset (Step 3/3)"
#      sleep $SLEEP_RESTART
      echo "Classifier For ${MAX_RUN_ID} Started"

    fi



  fi



  CLASS_TOTAL_RESULT=`$PSQL_CALL "$CLASS_TOTAL"`
  CLASS_TODO_RESULT=`$PSQL_CALL "$CLASS_TODO"`
  CLASS_DONE_RESULT=`$PSQL_CALL "$CLASS_DONE"`






  echo "$(date +%F-%H:%M:%S) Total/ToDo/Done/Blocked:  $CLASS_TOTAL_RESULT $CLASS_TODO_RESULT $CLASS_DONE_RESULT $BLOCKED_OBJECTS"
  while [[ "$CLASS_TODO_RESULT" != '0' ]]
  do

    PROGRESS=$((PROGRESS+1))

    #check if log file indicates process is completed
    CHECK_DONE=''
    CHECK_DONE=$(tail -1 $CLASSLOG | grep 'Process Complete')
    if [[ "$CHECK_DONE" != '' ]]; then 
      CLASS_TODO_RESULT='0'
    else

      CLASS_TOTAL_RESULT_T1=`$PSQL_CALL "$CLASS_TOTAL"`
      CLASS_TODO_RESULT_T1=`$PSQL_CALL "$CLASS_TODO"`
      CLASS_DONE_RESULT_T1=`$PSQL_CALL "$CLASS_DONE"`
      CLASSLOG_T1=`tail $CLASSLOG`
      echo "$(date +%F-%H:%M:%S) Total/ToDo/Done/Blocked: $CLASS_TOTAL_RESULT_T1 $CLASS_TODO_RESULT_T1 $CLASS_DONE_RESULT_T2 $BLOCKED_OBJECTS"

      sleep $SLEEP_TIME

      CLASS_TOTAL_RESULT_T2=`$PSQL_CALL "$CLASS_TOTAL"`
      CLASS_TODO_RESULT_T2=`$PSQL_CALL "$CLASS_TODO"`
      CLASS_DONE_RESULT_T2=`$PSQL_CALL "$CLASS_DONE"`
      CLASSLOG_T2=`tail $CLASSLOG`
      echo "$(date +%F-%H:%M:%S) Total/ToDo/Done/Blocked: $CLASS_TOTAL_RESULT_T2 $CLASS_TODO_RESULT_T2 $CLASS_DONE_RESULT_T2 $BLOCKED_OBJECTS"

    fi

    if [[ "$CLASSLOG_T1" != "$CLASSLOG_T2" ]] || [[ "$CLASS_DONE_RESULT_T1" != "$CLASS_DONE_RESULT_T2" ]] || [[ "$CLASS_TODO_RESULT_T1" != "$CLASS_TODO_RESULT_T2" ]];  then
      CONSECUTIVE_ISSUES=0
      CONSECUTIVE_PROGRESS=$((CONSECUTIVE_PROGRESS+1))
      echo "Total Progress: $PROGRESS Consecutive Progress/Issues:  $CONSECUTIVE_PROGRESS / $CONSECUTIVE_ISSUES"
    else
      CONSECUTIVE_PROGRESS=0
      CONSECUTIVE_ISSUES=$((CONSECUTIVE_ISSUES+1))
      echo "Total Progress: $PROGRESS Consecutive Progress/Issues:  $CONSECUTIVE_PROGRESS / $CONSECUTIVE_ISSUES"

      BAD_OBJ_ID=`tail -1 ${CLASSLOG} | grep -Eo '\bDS[0-9]*.parquet' | tr -dc '0-9'`
      if [[ "$BAD_OBJ_ID" == '' ]] ; then
        BAD_OBJ_ID=`tail -2 ${CLASSLOG} | grep -Eo '\bDS[0-9]*.parquet' | tr -dc '0-9'`
      fi
      if [[ "$BAD_OBJ_ID" == '' ]] ; then
        BAD_OBJ_ID=`tail -3 ${CLASSLOG} | grep -Eo '\bDS[0-9]*.parquet' | tr -dc '0-9'`
      fi
      if [[ "$BAD_OBJ_ID" == '' ]] ; then
        BAD_OBJ_ID=`tail -4 ${CLASSLOG} | grep -Eo '\bDS[0-9]*.parquet' | tr -dc '0-9'`
      fi

      if [[ "$BAD_OBJ_ID" != '' ]] && [[ "$BAD_OBJ_ID" != "$BAD_OBJ_PREVIOUS_ID" ]] ; then
        BAD_OBJ_FIX="update sentinel.objects set run_id=-1*${MAX_RUN_ID} where obj_id=${BAD_OBJ_ID}"
        BAD_OBJ_RESULT=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${BAD_OBJ_FIX}"`
        echo "...Encountered Blocked Object:  $BAD_OBJ_ID --> $BAD_OBJ_RESULT"
        BAD_OBJ_PREVIOUS_ID=$BAD_OBJ_ID
        BLOCKED_OBJECTS=$((BLOCKED_OBJECTS+1))
      fi

      if [[ "$BAD_OBJ_ID" == "$BAD_OBJ_PREVIOUS_ID" ]]; then
        echo "Repeat BAD_OBJ_ID:  $BAD_OBJ_ID"  
      fi

      BAD_OBJ_ID=''

      echo "Resubmitting Classify Process"
      echo `$PSQL_CALL "$POST_SUBMIT_CLASSIFY"`
      sleep $SLEEP_RESTART

      #check for prior blocked objects
      BLOCKED_OBJECTS_COUNT="select count(*) from sentinel.objects where run_id=-1*${MAX_RUN_ID}"
      BLOCKED_OBJECTS=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${BLOCKED_OBJECTS_COUNT}"`

    fi

    CLASS_TOTAL_RESULT=`$PSQL_CALL "$CLASS_TOTAL"`
    CLASS_TODO_RESULT=`$PSQL_CALL "$CLASS_TODO"`
    CLASS_DONE_RESULT=`$PSQL_CALL "$CLASS_DONE"`

  done
 
  CLASS_TOTAL_RESULT=`$PSQL_CALL "$CLASS_TOTAL"`
  CLASS_TODO_RESULT=`$PSQL_CALL "$CLASS_TODO"`
  CLASS_DONE_RESULT=`$PSQL_CALL "$CLASS_DONE"`

  echo "Final Total/ToDo/Done/Blocked:  $CLASS_TOTAL_RESULT $CLASS_TODO_RESULT $CLASS_DONE_RESULT $BLOCKED_OBJECTS"
  echo "Started: $START_TIME" 
  echo "Ended:   $(date +%F-%H:%M:%S)"
  echo "Classify Monitoring Completed  ..."

fi



# --------------------
# Publish
# --------------------

if [[ "$OPERATION_TO_WATCH" == 'PUBLISH' ]] || [[ "$OPERATION_TO_WATCH" == 'ALL' ]]; then


  START_TIME=$(date +%F-%H:%M:%S)

  echo
  echo "-------------------------------"
  echo "Publish"
  echo "Start: $START_TIME"
  echo "-------------------------------"

  # check if disovery & scan & classify logfiles exist
  if [[ ! -f "$DISCLOG" ]] || [[ ! -f "$SCANLOG" ]] || [[ ! -f "$CLASSLOG" ]]; then

    if [[ ! -f "$DISCLOG" ]]; then echo "Discovery Log File Does Not Exist"; fi
    if [[ ! -f "$SCANLOG" ]]; then echo "Scan Log File Does Not Exist"; fi
    if [[ ! -f "$CLASSLOG" ]]; then echo "Classify Log File Does Not Exist"; fi

    echo "Not Ready To Publish"
    OPERATION_TO_WATCH='FAIL'
  fi


  if [[ "$OPERATION_TO_WATCH" == 'PUBLISH' ]] || [[ "$OPERATION_TO_WATCH" == 'ALL' ]]; then

    echo "Publish Process Started ..."
    echo "Started: $START_TIME" 

    POST_SUBMIT_PUBLISH="select sentinelapi.post_submit_for_publish()"
    POST_SUBMIT_PUBLISH_RESULT=`psql -X -A -d data-sentinel -U postgres -h localhost -p 5432 -t -c "${POST_SUBMIT_PUBLISH}"`

    echo "Ended:   $(date +%F-%H:%M:%S)"
    echo "Publish  Completed  ..."
  fi

fi

export PGPASSWORD=''
echo 'Done'


fi


#need to update indent


