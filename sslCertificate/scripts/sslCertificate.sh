#!/bin/bash
## Zabbix Agent monitoring automatic discovery and check script for X509/SSL/HTTPS services
## author: Ugo Viti <ugo.viti@initzero.it>
## version: 20201018

## example input CSV file used by CVS to JSON zabbix discovery parser
# {#DOMAIN}
# www.initzero.it
# www.wearequantico.it
# www.otherdomain.fqdn:8080

## example parsed JSON
# {
#   "data":
#   [
#     { "{#DOMAIN}":"www.initzero.it"},
#     { "{#DOMAIN}":"www.wearequantico.it"},
#     { "{#DOMAIN}":"www.otherdomain.fqdn:8080"}
#   ]
# }

cmd="$1"
shift
domain="$1"
shift

[ -z "$cmd" ] && echo "ERROR: missing command... exiting" && exit 1

# print CSV formatted list removing blank and commented lines
discoveryDomains() {
  cat $domain | sed -e '/^#/d' -e '/^$/d'
}

# output in datetime format
getSSLExpireDate() {
  if [ -z "$(echo $1 | awk -F: '{print $2}')" ]; then
    host=$1
    port=443
   else
    host=$(echo $1 | awk -F: '{print $1}')
    port=$(echo $1 | awk -F: '{print $2}')
  fi
  timeout 5 openssl s_client -host "$host" -port $port -servername "$host" -showcerts </dev/null 2>/dev/null | sed -n '/BEGIN CERTIFICATE/,/END CERT/p' | openssl x509 -text 2>/dev/null | sed -n 's/ *Not After : *//p' 
}

# output in unixtime format
timeLeft() {
  sslExpireDate=$(getSSLExpireDate $domain)
  if [ ! -z "$sslExpireDate" ]; then
    echo $(($(date '+%s' --date "$sslExpireDate") - $(date '+%s')))
   else
    echo 0
    return 1
  fi
}

# output in unixtime format
timeExpire() {
  sslExpireDate=$(getSSLExpireDate $domain)
  if [ ! -z "$sslExpireDate" ]; then
    date '+%s' --date "$sslExpireDate"
   else
    echo 0
    return 1
  fi
}

# execute the given command
#set -x
$cmd $@
exit $?
