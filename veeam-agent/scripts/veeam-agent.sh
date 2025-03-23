#!/bin/bash
## Veeam Agent for Zabbix
## This script is designed to interact with Veeam Agent for Zabbix, providing functionalities such as discovering Veeam license information, checking job statuses, and retrieving detailed logs for Veeam backup jobs.
## author: Ugo Viti <u.viti@wearequantico.it>
version=20250322

## INSTALL:
## gpasswd -a zabbix veeam

# veeam log dir
LOG_DIR="/var/log/veeam/Backup"

cmd="$1"
shift
args="$@"

if [ -z "$cmd" ];then
  echo "ERROR: missing command... exiting"
  echo
  echo "USAGE:"
  echo "$0 lld"
  echo "$0 check"
  exit 1
elif [ -z "$args" ];then
  echo "ERROR: missing args... exiting"
  exit 1
fi

# print CSV formatted list removing blank and commented lines
veeam-agent.lld.jobs() {
  # Initialize RESULTS variable
  unset RESULTS

  # Check if there are any jobs listed by veeamconfig
  JOB_LIST=$(veeamconfig job list)

  # Check if there are no jobs
  if [[ -z "$JOB_LIST" ]]; then
    RESULTS+="JOB_STATUS=FAILED"
    RESULTS+=";DESCRIPTION=No configured jobs found"
    # print results
    echo ${RESULTS}
  else
    # Parse the job list and extract Name, ID, Type, Repository
    echo "$JOB_LIST" | tail -n +2 | while read LINE; do
      # Extract each field
      JOB_NAME=$(echo "$LINE" | awk '{print $1}')
      JOB_ID=$(echo "$LINE" | awk '{print $2}')
      JOB_TYPE=$(echo "$LINE" | awk '{print $3}')
      JOB_REPOSITORY=$(echo "$LINE" | awk '{print $4}')

      RESULTS+="JOB_NAME=$JOB_NAME"
      RESULTS+=";JOB_ID=$JOB_ID"
      RESULTS+=";JOB_TYPE=$JOB_TYPE"
      RESULTS+=";JOB_REPOSITORY=$JOB_REPOSITORY"

      # print results
      echo ${RESULTS}
      unset RESULTS
    done
  fi
}

# print CSV formatted list removing blank and commented lines
veeam-agent.check.info() {
  # Initialize RESULTS variable
  unset RESULTS

  VEEAM_LICENSE=$(veeamconfig license show)
  VEEAM_LICENSE_SOURCE=$(echo "$VEEAM_LICENSE" | grep -i "License source" | sed 's/.*License source: \(.*\)/\1/')
  VEEAM_MODE=$(echo "$VEEAM_LICENSE" | grep -i "Mode" | sed 's/.*Mode: \(.*\)/\1/')
  VEEAM_LICENSE_EXPIRATION=$(echo "$VEEAM_LICENSE" | grep -i "Support expiration" | sed 's/.*Support expiration: \(.*\)/\1/')
  VEEAM_LICENSE_STATUS=$(echo "$VEEAM_LICENSE" | grep -i "Status" | sed 's/.*Status: \(.*\)/\1/')
  VEEAM_LICENSE_OWNER=$(echo "$VEEAM_LICENSE" | grep -i "Issued to" | sed 's/.*Issued to: \(.*\)/\1/')
  VEEAM_LICENSE_EMAIL=$(echo "$VEEAM_LICENSE" | grep -i "E-mail" | sed 's/.*E-mail: \(.*\)/\1/')

  RESULTS+="VEEAM_LICENSE_SOURCE=$VEEAM_LICENSE_SOURCE"
  RESULTS+=";VEEAM_MODE=$VEEAM_MODE"
  RESULTS+=";VEEAM_LICENSE_EXPIRATION=$VEEAM_LICENSE_EXPIRATION"
  RESULTS+=";VEEAM_LICENSE_STATUS=$VEEAM_LICENSE_STATUS"
  RESULTS+=";VEEAM_LICENSE_OWNER=$VEEAM_LICENSE_OWNER"
  RESULTS+=";VEEAM_LICENSE_EMAIL=$VEEAM_LICENSE_EMAIL"

  # print results
  echo ${RESULTS}
  unset RESULTS
}


# print CSV formatted list removing blank and commented lines
veeam-agent.check.job() {
  JOB_NAME=$1

  # Initialize RESULTS variable
  unset RESULTS

  # create the RESULTS CSV
  RESULTS+="JOB_NAME=$JOB_NAME"

  # extract the unique job id using job name as source
  JOB_ID="$(veeamconfig job list | awk "/^$JOB_NAME/ {print \$2}")"

  if [ -z "$JOB_ID" ]; then
    RESULTS+=";JOB_STATUS=FAILED"
    RESULTS+=";DESCRIPTION=No configured jobs found"
    # print results
    echo ${RESULTS}
  else
    # Retrieve the last session id
    #JOB_LAST_SESSION_INFO="$(veeamconfig session list --jobid "$JOB_ID" --7 | grep "^$JOB_NAME" | tail -n1)"
    JOB_LAST_SESSION_ID="$(veeamconfig session list --jobid "$JOB_ID" | awk "/^$JOB_NAME/ {print \$3}" | tail -n1)"

    # Retrieve the last session informations
    JOB_LAST_SESSION_INFO=$(veeamconfig session info --id "$JOB_LAST_SESSION_ID" | sed 's/^[ \t]*//')

    # Extract values directly using grep with regex
    #JOB_SESSION_ID=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^ID:\s*\K.*')  # Extract the Session ID
    #JOB_NAME=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Job name:\s*\K.*')  # Extract the Job Name
    #JOB_ID=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Job ID:\s*\K.*')  # Extract the Job ID
    #JOB_OIB_ID=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^OIB ID:\s*\K.*')  # Extract the OIB ID
    JOB_STATUS=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^State:\s*\K.*')  # Extract the Session State
    JOB_CREATION_TIME=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Creation time:\s*\K.*')  # Extract the Creation Time
    JOB_START_TIME=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Start time:\s*\K.*')  # Extract the Start Time
    JOB_END_TIME=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^End time:\s*\K.*')  # Extract the End Time
    JOB_PROCESSED_DATA=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Processed:\s*\K.*')  # Extract the Processed Data
    JOB_TRANSFERRED_DATA=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Transferred:\s*\K.*')  # Extract the Transferred Data
    JOB_ATTEMPT=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Attempt:\s*\K.*')  # Extract the Retry Attempt Number
    #JOB_LAST_ATTEMPT=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Is last attempt:\s*\K.*')  # Extract if it's the last retry attempt

    # add results sets
    RESULTS+=";JOB_STATUS=$JOB_STATUS"
    RESULTS+=";JOB_SESSION_ID=$JOB_LAST_SESSION_ID"
    RESULTS+=";JOB_CREATION_TIME=$JOB_CREATION_TIME"
    RESULTS+=";JOB_START_TIME=$JOB_START_TIME"
    RESULTS+=";JOB_END_TIME=$JOB_END_TIME"
    RESULTS+=";JOB_PROCESSED_DATA=$JOB_PROCESSED_DATA"
    RESULTS+=";JOB_TRANSFERRED_DATA=$JOB_TRANSFERRED_DATA"
    RESULTS+=";JOB_ATTEMPT=$JOB_ATTEMPT"

    # search log file path
    SESSION_DIR=$(find "$LOG_DIR"/"$JOB_NAME" -mindepth 1 -maxdepth 1 -type d -not -name "*.tar.gz" -printf "%T@ %f\n" | sort -nr | awk 'NR==1{print $2}')
    LOG_FILE="$LOG_DIR/$JOB_NAME/$SESSION_DIR/Job.log"
    RESULTS+=";LOG_FILE=$LOG_FILE"

    if [ "$JOB_STATUS" == "Success" ]; then
      RESULTS+=";DESCRIPTION=Job ended with success"
    else
      RESULTS+=";DESCRIPTION=Job ended with errors"
    fi
    # print results
    echo ${RESULTS}
    unset RESULTS
  fi
}

printJSON() {
  local cmd="$1"
  shift
  local type="$1"
  shift
  echo "{
\"data\":
  ["
  $cmd $type | while IFS=';' read -ra FIELDS; do
    unset JSON

    # Process each field
    for FIELD in "${FIELDS[@]}"; do
      IFS='=' read -r KEY VALUE <<< "$FIELD"
      KEY=$(echo "$KEY" | tr '[:lower:]' '[:upper:]')

      # Aggiungi la coppia chiave-valore al JSON
      if [ "$type" == "lld" ]; then
          JSON+="\"{#${KEY}}\":\"${VALUE}\","
        else
          JSON+="\"${KEY}\":\"${VALUE}\","
      fi
    done

    # Rimuovi la virgola finale e stampa il JSON
    echo -e "    {${JSON%,}},"
  done | sed 'H;1h;$!d;x;s/\(.*\),/\1/'
  echo " ]
}"
}


## lld rules
veeam-agent.lld() {
  local method="$1"
  shift
  [ ! -z "$1" ] && local LOG_DIR="$1"
  [ ! -e "$LOG_DIR" ] && echo "ERROR: LOG DIR doesn't exist: $LOG_DIR" && exit 1

  case $method in
    jobs)
      printJSON veeam-agent.lld.${method} lld
    ;;
    *)
      echo "ERROR: wrong discovery method specified... exiting"
      exit 1
      ;;
  esac
}

## check rules
veeam-agent.check() {
  local method="$1"
  shift
  local job="$1"
  shift
  [ ! -z "$1" ] && local LOG_DIR="$1"
  [ ! -e "$LOG_DIR" ] && echo "ERROR: LOG DIR doesn't exist: $LOG_DIR" && exit 1

  case $method in
    job)
      [ -z "${job}" ] && echo "ERROR: job name to check not specified... exiting" && exit 1
      printJSON veeam-agent.check.${method} ${job}
    ;;
    info)
      printJSON veeam-agent.check.${method}
    ;;
    *)
      echo "ERROR: wrong check method specified... exiting"
      exit 1
      ;;
  esac
}



# execute the given command
#set -x
veeam-agent.${cmd} ${args}
exit $?
