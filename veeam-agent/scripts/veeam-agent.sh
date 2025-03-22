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
  echo "$0 discovery"
  echo "$0 check"
  exit 1
elif [ -z "$args" ];then
  echo "ERROR: missing args... exiting"
  exit 1
fi

# print CSV formatted list removing blank and commented lines
veeam.discovery.info() {
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
veeam.discovery.jobs() {
  # Initialize RESULTS variable
  unset RESULTS

  # Check if there are any directories in $LOG_DIR
  if [ $(find "$LOG_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l) -eq 0 ]; then
    RESULTS+="JOB_STATUS=FAILED"
    RESULTS+=";DESCRIPTION=No configured jobs found"
    # print results
    echo ${RESULTS}
  else
    ls -t "$LOG_DIR" | while read JOB_NAME; do
      SESSIONS_DIR="$LOG_DIR"/"$JOB_NAME"

      RESULTS+="JOB_NAME=$JOB_NAME"
      RESULTS+=";SESSIONS_DIR=$SESSIONS_DIR"

      # print results
      echo ${RESULTS}
      unset RESULTS
    done
  fi
}


# print CSV formatted list removing blank and commented lines
veeam.check.job() {
  JOB_NAME=$1

  # Initialize RESULTS variable
  unset RESULTS

  # Check if there are any directories in $LOG_DIR
  if [ $(find "$LOG_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l) -eq 0 ]; then
    RESULTS+="JOB_STATUS=FAILED"
    RESULTS+=";DESCRIPTION=No configured jobs found"
    # print results
    echo ${RESULTS}
  else
    #ls -t "$LOG_DIR" | while read JOB_NAME; do
      SESSION_DIR=$(find "$LOG_DIR"/"$JOB_NAME" -mindepth 1 -maxdepth 1 -type d -not -name "*.tar.gz" -printf "%T@ %f\n" | sort -nr | awk 'NR==1{print $2}')
      LOG_FILE="$LOG_DIR/$JOB_NAME/$SESSION_DIR/Job.log"

      RESULTS+="JOB_NAME=$JOB_NAME"
      RESULTS+=";LOG_FILE=$LOG_FILE"

      # Search for JOB STATUS and extract the value
      JOB_STATUS_LINE=$(grep -P 'JOB STATUS:\s*\K\w+' "$LOG_FILE")
      JOB_STATUS=$(echo "$JOB_STATUS_LINE" | grep -oP 'JOB STATUS:\s*\K\w+')

      if [ -z "$JOB_STATUS" ]; then
        RESULTS+=";JOB_STATUS=FAILED"
        RESULTS+=";DESCRIPTION=Job status result not found"
      else
        JOB_TIME=$(echo "$JOB_STATUS_LINE" | sed 's/^\[\([^]]*\)\].*/\1/')
        JOB_TIME_REFORMATTED=$(echo "$JOB_TIME" | sed 's/\([0-9]\{2\}\)\.\([0-9]\{2\}\)\.\([0-9]\{4\}\) \([0-9]\{2\}\):\([0-9]\{2\}\):\([0-9]\{2\}\)/\3-\2-\1 \4:\5:\6/')
        JOB_TIME_ISO8861=$(date -d "$JOB_TIME_REFORMATTED" +"%Y-%m-%dT%H:%M:%S")
        JOB_TIME_UNIX=$(date -d "$JOB_TIME_REFORMATTED" +%s)

        #VEEAM_VERSION=$(grep "Version:" "$LOG_FILE" | sed 's/.*: \([0-9\.]*\).*/\1/')
        #VEEAM_REPOSITORY_TYPE=$(grep "RepositoryType" "$LOG_FILE" | head -n1 | sed -n 's/.*RepositoryType = \([^ ]*\).*/\1/p' | sed 's/\\n$//')
        #VEEAM_SERVICE_NAME=$(grep "ServiceName" "$LOG_FILE" | head -n1 | sed -n 's/.*ServiceName = \([^ ]*\).*/\1/p' | sed 's/\\n$//')
        #VEEAM_LICENSE_STATUS=$(grep "Status:" "$LOG_FILE" | sed -n 's/.*: \([^]]*\)/\1/p')
        #VEEAM_LICENSE_OWNER=$(grep "Issued to:" "$LOG_FILE" | sed -n 's/.*: \([^]]*\)/\1/p')

        # get other info
        RESULTS+=";JOB_STATUS=$JOB_STATUS"
        RESULTS+=";JOB_TIME=$JOB_TIME_ISO8861"
        RESULTS+=";JOB_TIME_UNIX=$JOB_TIME_UNIX"
        #RESULTS+=";VEEAM_VERSION=$VEEAM_VERSION"
        #RESULTS+=";VEEAM_REPOSITORY_TYPE=$VEEAM_REPOSITORY_TYPE"
        #RESULTS+=";VEEAM_SERVICE_NAME=$VEEAM_SERVICE_NAME"
        #RESULTS+=";VEEAM_LICENSE_STATUS=$VEEAM_LICENSE_STATUS"
        #RESULTS+=";VEEAM_LICENSE_OWNER=$VEEAM_LICENSE_OWNER"

        if [ "$JOB_STATUS" == "SUCCESS" ]; then
          RESULTS+=";DESCRIPTION=Job ended with success"
        else
          RESULTS+=";DESCRIPTION=Job ended with errors"
        fi
      fi

      # print results
      echo ${RESULTS}
      unset RESULTS
    #done
  fi
}

printJSON() {
  local cmd="$1"
  shift
  local args="$@"
  echo "{
\"data\":
  ["
  $cmd $args | while IFS=';' read -ra FIELDS; do
    unset JSON

    # Process each field
    for FIELD in "${FIELDS[@]}"; do
      IFS='=' read -r KEY VALUE <<< "$FIELD"
      KEY=$(echo "$KEY" | tr '[:lower:]' '[:upper:]')

      # Aggiungi la coppia chiave-valore al JSON
      JSON+="\"{#${KEY}}\":\"${VALUE}\","
    done

    # Rimuovi la virgola finale e stampa il JSON
    echo -e "    {${JSON%,}},"
  done | sed 'H;1h;$!d;x;s/\(.*\),/\1/'
  echo " ]
}"
}


## discovery rules
veeam.discovery() {
  local method="$1"
  shift
  [ ! -z "$1" ] && local LOG_DIR="$1"

  [ ! -e "$LOG_DIR" ] && echo "ERROR: LOG DIR doesn't exist: $LOG_DIR" && exit 1

  case $method in
    jobs)
      printJSON veeam.discovery.${method}
    ;;
    info)
      printJSON veeam.discovery.${method}
    ;;
    *)
      echo "ERROR: wrong discovery method specified... exiting"
      exit 1
      ;;
  esac
}

## jobs check
veeam.check() {
  local job="$1"
  shift
  [ ! -z "$1" ] && local LOG_DIR="$1"

  [ ! -e "$LOG_DIR" ] && echo "ERROR: LOG DIR doesn't exist: $LOG_DIR" && exit 1

  printJSON veeam.check.job ${job}
}



# execute the given command
#set -x
veeam.${cmd} ${args}
exit $?
