#!/bin/bash
# Zabbix Agent monitoring for TurboSMTP service
# author: Ugo Viti <ugo.viti@initzero.it>
# version: 20210409

## RHEL INSTALLATION:
# dnf install curl jq bind-utils -y

# enable the caching of recurring commands (to lowering the load caused by frequent queries)
cmdCacheEnabled="false"

# timeout expire for cache file (in seconds)
cmdCacheTime="3600"

# tmp directory of cache files
cmdCacheDir="/tmp/zabbix-turbosmtp"

cmd="$1"
shift

username="$1"
shift

password="$1"
shift

args="$@"

[ -z "$cmd" ] && echo "ERROR: missing COMMAND arguments... exiting" && exit 1
[ -z "$username" ] && echo "ERROR: missing USERNAME... exiting" && exit 1
[ -z "$password" ] && echo "ERROR: missing PASSWORD... exiting" && exit 1

cmdInit() {
  COMMANDS="curl jq dig"

  # verify if all commands are installed in the system paths
  for COMMAND in $COMMANDS; do
      which $COMMAND >/dev/null 2>&1
      [ $? -ne 0 ] && echo "ERROR: the command '$COMMAND' doesn't exist in any path, please install it and retry. exiting..." && exit 1
  done

  auth=$(cmdCacheEnabled=true cmdCacheWrapper authorize)
}

## command wrapper cache
cmdCacheWrapper() {
  cmd="$1"
  shift
  
  # use a cache file if requested
  if [ "$cmdCacheEnabled" = "true" ]; then
      cmdCacheFile="$cmdCacheDir/$(echo $cmd | sed 's/ /_/g')"
      [ ! -e "$cmdCacheDir" ] && install -m 750 -d "$cmdCacheDir"
      [ ! -e "$cmdCacheFile" ] && touch "$cmdCacheFile"
      # update cache file if cmdCacheTime is expired
      if [ -z "$(cat "$cmdCacheFile")" ] || [ "$(( $(date +"%s") - $(stat -c "%Y" $cmdCacheFile) ))" -gt "$cmdCacheTime" ]; then
        $cmd $@ > "$cmdCacheFile"
      fi
      cat "$cmdCacheFile"
    else
      $cmd $@
  fi
}

rblCheck(){
  IP="$1"
  shift
  
  # test blacklisted IP
  #IP="127.0.0.2"
  
  RBL_LIST="$@"
  
  # default RBL list
  : ${RBL_LIST:="
      cbl.abuseat.org
      dnsbl.sorbs.net
      bl.spamcop.net
      zen.spamhaus.org
      combined.njabl.org
      myfasttelco.com
  "}
  
  RDNS=$(echo $IP | sed -ne "s~^\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)$~\4.\3.\2.\1~p")

  # -- cycle through all the blacklists
  for RBL in ${RBL_LIST} ; do
      # print the UTC date (without linefeed)
      #printf $(date +"%Y-%m-%d %H:%M:%S")
      #printf "%-50s" " ${RDNS}.${BL}."

      # use dig to lookup the name in the blacklist  
      local LISTED="$(dig +short -t a ${RDNS}.${RBL}.)"
      [ ! -z "${LISTED}" ] && LISTED_RBL+="${RBL}, "
      unset LISTED
  done
  if [ ! -z "${LISTED_RBL}" ]; then
    LISTED_RBL=$(echo ${LISTED_RBL} | sed 's/,$//')
    echo "IP $IP is listed in RBL: [${LISTED_RBL}]"
  else
    echo "Good"
  fi
}

# returns the integer representation of an IP arg, passed in ascii dotted-decimal notation (x.x.x.x)
ip2dec() {
    local a b c d ip=$@
    IFS=. read -r a b c d <<< "$ip"
    printf '%d\n' "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
}

# returns the dotted-decimal ascii form of an IP arg passed in integer format
dec2ip() {
    local ip dec=$@
    for e in {3..0}
    do
        ((octet = dec / (256 ** e) ))
        ((dec -= octet * 256 ** e))
        ip+=$delim$octet
        delim=.
    done
    printf '%s\n' "$ip"
}

## ref: https://www.serversmtp.com/turbo-api/
authorize() {
  curl -s https://dashboard.serversmtp.com/api/authorize -d "email=${username}" -d "password=${password}" -d "no_expire=0" | jq -r .auth
}

user.info.active() {
  # https://www.serversmtp.com/turbo-api/#account-info
  curl -s https://dashboard.serversmtp.com/api/user/info -G -H "Authorization: $auth" | jq -r .active
}

user.info.ip() {
  # https://www.serversmtp.com/turbo-api/#account-info
  dec2ip $(curl -s https://dashboard.serversmtp.com/api/user/info -G -H "Authorization: $auth" | jq -r .ip)
}

blacklist.check() {
  rblCheck $(cmdCacheEnabled=true cmdCacheWrapper user.info.ip) $@
  # rbl tester
  #rblCheck 127.0.0.2 $@
}

emails.count() {
  # https://www.serversmtp.com/turbo-api/#count-of-email-sent
  [ -z "$1" ] && filter='*' || filter="$1"
  curl -s https://dashboard.serversmtp.com/api/stats/panes/emails/count -G -d "start=$date_start" -d "end=$date_end" -d "filter=$filter" -H "Authorization: $auth" | jq -r .count
}

plans.smtp_limit() {
  # https://www.serversmtp.com/turbo-api/#active-plans
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
  emails.count $1
}

emails.count.today.delivered() {
  emails.count.today '["SUCCESS","OPEN","CLICK","UNSUB","REPORT"]'
}

emails.count.today.read() {
  emails.count.today '["OPEN","CLICK","UNSUB","REPORT"]'
}

emails.count.today.failed() {
  emails.count.today '["FAIL"]'
}

# init commands
#set -x
cmdInit

# command cache handling
case $cmd in
  # always cache these commands
  authorize|user.info.ip)
    cmdCacheEnabled=true cmdCacheWrapper $cmd $@
    ;;
  # disable cache for other commands
  *)  
    cmdCacheEnabled=false cmdCacheWrapper $cmd $@
    ;;
esac
