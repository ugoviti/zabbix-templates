#!/bin/bash
# Zabbix Agent monitoring afor TurboSMTP service
# author: Ugo Viti <ugo.viti@initzero.it>
# version: 20210402

## INSTALLATION:
# dnf install curl jq -y

cmdCacheDir="/tmp/zabbix-turbosmtp"

# timeout expire for cache file (in seconds)
cmdCacheTime="3600"

cmd="$1"
shift

username="$1"
shift

password="$1"
shift


[ -z "$cmd" ] && echo "ERROR: missing COMMAND arguments... exiting" && exit 1
[ -z "$username" ] && echo "ERROR: missing USERNAME... exiting" && exit 1
[ -z "$password" ] && echo "ERROR: missing PASSWORD... exiting" && exit 1

## command cache

cmd_init() {
  COMMANDS="curl jq"

  # verify if all commands are installed in the system paths
  for COMMAND in $COMMANDS; do
      which $COMMAND >/dev/null 2>&1
      [ $? -ne 0 ] && echo "ERROR: the command '$COMMAND' doesn't exist in any path, please install it and retry. exiting..." && exit 1
  done
  
  [ ! -e "${cmdCacheDir}" ] && install -m 750 -d "${cmdCacheDir}"
  
  if [ ! -e "${cmdCacheDir}/auth.token" ];
    then
      auth > "${cmdCacheDir}/auth.token"
    else
      if [ "$(( $(date +"%s") - $(stat -c "%Y" "${cmdCacheDir}/auth.token") ))" -gt "$cmdCacheTime" ]; then
          auth > "${cmdCacheDir}/auth.token"
      fi
  fi
  
  auth="$(cat "${cmdCacheDir}/auth.token")"
}

## ref: https://www.serversmtp.com/turbo-api/

auth() {
  curl -s https://dashboard.serversmtp.com/api/authorize -d "email=${username}" -d "password=${password}" -d "no_expire=0" | jq -r .auth
}

emails.count() {
  curl -s https://dashboard.serversmtp.com/api/stats/panes/emails/count -G -d "start=$date_start" -d "end=$date_end" -d "filter=*" -H "Authorization: $auth" | jq -r .count
}

plans.smtp_limit() {
  curl -s https://dashboard.serversmtp.com/api/plans -G -H "Authorization: $auth" | jq -r .[] | jq -r .smtp_limit
}

emails.count.month.previous() {
  date_start="$(date -d "-$(date +%d) days -1 day" +"%Y-%m-01 00:00:00")"
  date_end="$(date -d "-$(date +%d) days -1 day" +"%Y-%m-%d 23:59:59")"
  emails.count
}

emails.count.week.previous() {
  date_start="$(date -d 'monday -14 days' +"%Y-%m-%d 00:00:00")"
  date_end="$(date -d 'sunday -7 days' +"%Y-%m-%d 23:59:59")"
  emails.count
}

emails.count.month() {
  date_start="$(date +"%Y-%m-01 00:00:00")"
  date_end="$(date -d "-$(date +%d) days month" +"%Y-%m-%d 23:59:59")"
  emails.count
}

emails.count.week() {
  date_start="$(date -d 'monday -7 days' +"%Y-%m-%d 00:00:00")"
  date_end="$(date -d 'sunday' +"%Y-%m-%d 23:59:59")"
  emails.count
}

emails.count.today() {
  date_start="$(date +"%Y-%m-%d 00:00:00")"
  date_end="$(date +"%Y-%m-%d %H:%M:%S")"
  emails.count
}


# execute the given command
#set -x
cmd_init
$cmd $@
