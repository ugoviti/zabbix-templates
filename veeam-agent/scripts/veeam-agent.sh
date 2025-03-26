#!/bin/bash
## Veeam Agent for Zabbix
## This script is designed to interact with Veeam Agent for Zabbix, providing functionalities such as discovering Veeam license information, checking job statuses, and retrieving detailed logs for Veeam backup jobs.
## author: Ugo Viti <u.viti@wearequantico.it>
version=20250326

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

convertSize() {
  local input="$@"
  # Remove any leading/trailing whitespace
  input=$(echo "$input" | xargs)

  # Use regex to extract the numeric value and the unit.
  # The regex accepts an optional space between the number and the unit.
  if [[ $input =~ ^([0-9]+(\.[0-9]+)?)\ ?([KMGTP]?B)$ ]]; then
    local value="${BASH_REMATCH[1]}"
    local unit=$(echo "${BASH_REMATCH[3]}" | tr '[:lower:]' '[:upper:]')

    # Determine multiplier based on unit (using 1024 as the conversion factor)
    local multiplier=1
    case "$unit" in
      B)   multiplier=1 ;;
      KB)  multiplier=1024 ;;
      MB)  multiplier=$((1024*1024)) ;;
      GB)  multiplier=$((1024*1024*1024)) ;;
      TB)  multiplier=$((1024*1024*1024*1024)) ;;
      PB)  multiplier=$((1024*1024*1024*1024*1024)) ;;
      *) echo "Unknown unit: $unit" >&2; return 1 ;;
    esac

    # Multiply the value by the multiplier using awk (for floating point math)
    local bytes
    bytes=$(awk -v val="$value" -v mult="$multiplier" 'BEGIN { printf "%.0f", val * mult }')
    echo "$bytes"
  else
    echo "Invalid format: '$input'" >&2
    return 1
  fi
}

veeam-agent.lld.jobs() {
  # Initialize RESULTS variable
  unset RESULTS

  # Get job list and format columns with semicolons
  JOB_LIST=$(veeamconfig job list | sed 's/  \+/;/g' | tail -n +2)

  # Check if there are no jobs
  if [[ -z "$JOB_LIST" ]]; then
    RESULTS="JOB_STATUS=FAILED;DESCRIPTION=No configured jobs found"
    printf "%s\n" "$RESULTS"
  else
    # Parse the job list
    while IFS=';' read -r JOB_NAME JOB_ID JOB_TYPE JOB_REPOSITORY; do
      RESULTS="JOB_NAME=$JOB_NAME"
      RESULTS+=";JOB_ID=$JOB_ID"
      RESULTS+=";JOB_TYPE=$JOB_TYPE"
      RESULTS+=";JOB_REPOSITORY=$JOB_REPOSITORY"

      # Print results
      printf "%s\n" "$RESULTS"
    done <<< "$JOB_LIST"
  fi
}


veeam-agent.lld.repos() {
  # Initialize RESULTS variable
  unset RESULTS

  # Get repository list and format columns with semicolons
  REPO_LIST=$(veeamconfig repository list | sed 's/  \+/;/g' | tail -n +2)

  # Check if there are no repositories
  if [[ -z "$REPO_LIST" ]]; then
    RESULTS="JOB_STATUS=FAILED;DESCRIPTION=No configured repositories found"
    printf "%s\n" "$RESULTS"
  else
    # Parse the repository list
    while IFS=';' read -r REPO_NAME REPO_ID REPO_LOCATION REPO_TYPE REPO_ACCESSIBLE REPO_BACKUP_SERVER; do
      RESULTS="REPO_NAME=$REPO_NAME"
      RESULTS+=";REPO_ID=$REPO_ID"
      RESULTS+=";REPO_LOCATION=$REPO_LOCATION"
      RESULTS+=";REPO_TYPE=$REPO_TYPE"
      RESULTS+=";REPO_ACCESSIBLE=$REPO_ACCESSIBLE"
      RESULTS+=";REPO_BACKUP_SERVER=$REPO_BACKUP_SERVER"

      # Print results
      printf "%s\n" "$RESULTS"
    done <<< "$REPO_LIST"
  fi
}


veeam-agent.check.repo() {
  REPO_NAME=$1

  # Initialize RESULTS variable
  unset RESULTS

  # Get repository list and format columns with semicolons
  REPO_LIST=$(veeamconfig repository list | sed 's/  \+/;/g' | tail -n +2 | grep "^$REPO_NAME")

  # Check if there are no repositories
  if [[ -z "$REPO_LIST" ]]; then
    RESULTS="JOB_STATUS=FAILED;DESCRIPTION=No configured repositories found"
    printf "%s\n" "$RESULTS"
  else
    # Parse the repository list
    while IFS=';' read -r REPO_NAME REPO_ID REPO_LOCATION REPO_TYPE REPO_ACCESSIBLE REPO_BACKUP_SERVER; do
      RESULTS="REPO_NAME=$REPO_NAME"
      RESULTS+=";REPO_ID=$REPO_ID"
      RESULTS+=";REPO_LOCATION=$REPO_LOCATION"
      RESULTS+=";REPO_TYPE=$REPO_TYPE"
      RESULTS+=";REPO_ACCESSIBLE=$REPO_ACCESSIBLE"
      RESULTS+=";REPO_BACKUP_SERVER=$REPO_BACKUP_SERVER"

      # Print results
      printf "%s\n" "$RESULTS"
    done <<< "$REPO_LIST"
  fi
}

veeam-agent.check.job() {
  # define the job name
  JOB_NAME=$1

  # extract the unique job id using job name as source
  JOB_ID="$(veeamconfig job list | awk "/^$JOB_NAME/ {print \$2}")"

  # Initialize RESULTS variable
  unset RESULTS

  # create the RESULTS CSV
  RESULTS+="JOB_NAME=$JOB_NAME"

  if [ -z "$JOB_ID" ]; then
    RESULTS+=";JOB_STATUS=Failed"
    RESULTS+=";DESCRIPTION=No configured jobs found"
    # print results
    echo ${RESULTS}
  else
    # Retrieve the last session id
    #JOB_LAST_SESSION_INFO="$(veeamconfig session list --jobid "$JOB_ID" --7 | grep "^$JOB_NAME" | tail -n1)"
    JOB_LAST_SESSION_ID="$(veeamconfig session list --jobid "$JOB_ID" | awk "/^$JOB_NAME/ {print \$3}" | tail -n1)"

    # Retrieve the last session informations
    JOB_LAST_SESSION_INFO=$(veeamconfig session info --id "$JOB_LAST_SESSION_ID" | sed 's/^[ \t]*//')

    JOB_INFO="$(veeamconfig job info --id $JOB_ID | sed 's/^[ \t]*//')"

    # Extract values directly using grep with regex
    #JOB_SESSION_ID=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^ID:\s*\K.*')  # Extract the Session ID
    #JOB_NAME=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Job name:\s*\K.*')  # Extract the Job Name
    #JOB_ID=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Job ID:\s*\K.*')  # Extract the Job ID
    #JOB_OIB_ID=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^OIB ID:\s*\K.*')  # Extract the OIB ID
    JOB_STATUS=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^State:\s*\K.*')  # Extract the Session State
    JOB_TIME_CREATION=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Creation time:\s*\K.*')  # Extract the Creation Time
    JOB_TIME_START=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Start time:\s*\K.*')  # Extract the Start Time
    JOB_TIME_END=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^End time:\s*\K.*')  # Extract the End Time
    JOB_DATA_PROCESSED=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Processed:\s*\K.*')  # Extract the Processed Data
    JOB_DATA_TRANSFERRED=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Transferred:\s*\K.*')  # Extract the Transferred Data
    JOB_RETRY_ATTEMPT=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Attempt:\s*\K.*')  # Extract the Retry Attempt Number
    #JOB_RETRY_ATTEMPT_LAST=$(echo "$JOB_LAST_SESSION_INFO" | grep -oP '^Is last attempt:\s*\K.*')  # Extract if it's the last retry attempt

    JOB_INFO_MAX_POINTS=$(echo "$JOB_INFO" | grep -oP '^Max points:\s*\K.*')  # Extract the Max restore points
    JOB_INFO_INCLUDE_DIRS=$(echo "$JOB_INFO" | grep -oP '^Include directory:\s*\K.*' | paste -sd ',' -)
    JOB_INFO_EXCLUDE_DIRS=$(echo "$JOB_INFO" | grep -oP '^Exclude directory:\s*\K.*' | paste -sd ',' -)
    JOB_INFO_IMMUTABILITY=$(echo "$JOB_INFO" | awk '/^Repository immutability:/ {getline; print}')

    # calc other vars
    JOB_TIME_CREATION_UNIXTIME=$(date -d "$JOB_TIME_CREATION" +%s)
    JOB_TIME_START_UNIXTIME=$(date -d "$JOB_TIME_START" +%s)
    JOB_TIME_END_UNIXTIME=$(date -d "$JOB_TIME_END" +%s)
    JOB_TIME_DURATION_UNIXTIME=$(( JOB_TIME_END_UNIXTIME - JOB_TIME_START_UNIXTIME ))
    JOB_DATA_PROCESSED_BYTES=$(convertSize "$JOB_DATA_PROCESSED")
    JOB_DATA_TRANSFERRED_BYTES=$(convertSize "$JOB_DATA_TRANSFERRED")

    # add results sets
    RESULTS+=";JOB_STATUS=$JOB_STATUS"
    RESULTS+=";JOB_SESSION_ID=$JOB_LAST_SESSION_ID"
    RESULTS+=";JOB_TIME_CREATION=$JOB_TIME_CREATION_UNIXTIME"
    RESULTS+=";JOB_TIME_START=$JOB_TIME_START_UNIXTIME"
    RESULTS+=";JOB_TIME_END=$JOB_TIME_END_UNIXTIME"
    RESULTS+=";JOB_TIME_DURATION=$JOB_TIME_DURATION_UNIXTIME"
    RESULTS+=";JOB_DATA_PROCESSED=$JOB_DATA_PROCESSED_BYTES"
    RESULTS+=";JOB_DATA_TRANSFERRED=$JOB_DATA_TRANSFERRED_BYTES"
    RESULTS+=";JOB_RETRY_ATTEMPT=$JOB_RETRY_ATTEMPT"
    RESULTS+=";JOB_INFO_MAX_POINTS=$JOB_INFO_MAX_POINTS"
    RESULTS+=";JOB_INFO_INCLUDE_DIRS=$JOB_INFO_INCLUDE_DIRS"
    RESULTS+=";JOB_INFO_EXCLUDE_DIRS=$JOB_INFO_EXCLUDE_DIRS"
    RESULTS+=";JOB_INFO_IMMUTABILITY=$JOB_INFO_IMMUTABILITY"

    # test
    #JOB_TIME_ISO8861=$(date -d "$JOB_TIME_REFORMATTED" +"%Y-%m-%dT%H:%M:%S")
    #JOB_TIME_UNIX=$(date -d "$JOB_TIME_REFORMATTED" +%s)

    # search log file path
    if [ -e "${LOG_DIR}/${JOB_NAME}" ]; then
      SESSION_DIR=$(find "${LOG_DIR}/${JOB_NAME}" -mindepth 1 -maxdepth 1 -type d -not -name "*.tar.gz" -printf "%T@ %f\n" | sort -nr | awk 'NR==1{print $2}')
      LOG_FILE="$LOG_DIR/$JOB_NAME/$SESSION_DIR/Job.log"
      RESULTS+=";LOG_FILE=$LOG_FILE"
    else
      RESULTS+=";LOG_FILE=ERROR: LOG DIR doesn't exist: $LOG_DIR"
    fi

    VEEAM_LOG=$(veeamconfig session log --id "$JOB_LAST_SESSION_ID" | grep -v "\[info\]" | grep -v "Processing finished" | sed 's/^[^]]*\] //')

    case "$JOB_STATUS" in
      Success)
        RESULTS+=";DESCRIPTION=Job ended with success: $VEEAM_LOG"
        ;;
      Running)
        RESULTS+=";DESCRIPTION=Job is running: $VEEAM_LOG"
        ;;
      *)
        RESULTS+=";DESCRIPTION=Job ended with errors: $VEEAM_LOG"
        ;;
    esac

    # print results
    echo ${RESULTS}
    unset RESULTS
  fi
}

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

  case $method in
    jobs)
      printJSON veeam-agent.lld.${method} lld
    ;;
    repos)
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
  local obj="$1"

  case $method in
    job)
      [ -z "${obj}" ] && echo "ERROR: job name to check not specified... exiting" && exit 1
      printJSON veeam-agent.check.${method} ${obj}
    ;;
    repo)
      [ -z "${obj}" ] && echo "ERROR: repo name to check not specified... exiting" && exit 1
      printJSON veeam-agent.check.${method} ${obj}
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
