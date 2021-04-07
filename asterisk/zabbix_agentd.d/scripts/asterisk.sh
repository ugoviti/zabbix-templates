#!/bin/bash
# Zabbix Agent monitoring automatic discovery and check script for Asterisk PBX services
# author: Ugo Viti <ugo.viti@initzero.it>
# version: 20210317

# comment to disable sudo
sudo="sudo -u asterisk"

# enable the caching of asterisk commands (to lowering the load caused by frequent queries)
asteriskCacheEnabled="true"

# timeout expire for cache file
asteriskCacheTime="60"

# tmp directory of cache files
asteriskCacheDir="/tmp/zabbix-asterisk-tmp"


## Zabbix JSON out examples

# SIP/IAX2 Trunks example JSON file for zabbix discovery
# {
#   "data":
#   [
#     { "{#HOST}":"voip.eutelia.it:5060", "{#USERNAME}":"05751234567", "{#STATE}":"Registered"},
#     { "{#HOST}":"sip.messagenet.it:5060", "{#USERNAME}":"34887123456", "{#STATE}":"Registered"}
#   ]
# }

# PJSIP Trunks example JSON file for zabbix discovery
# {
#   "data":
#   [
#     { "{#HOST}":"voip.eutelia.it", "{#ENDPOINT}":"ci-05751234567",  "{#USERNAME}":"05751234567", "{#STATE}":"Avail"},
#     { "{#HOST}":"sip.messagenet.it:5060", "{#ENDPOINT}":"mn-34887123456",  "{#USERNAME}":"34887123456", "{#STATE}":"Avail"},
#   ]
# }

# SIP/IAX2 Peers example JSON file for zabbix discovery
# {
#   "data":
#   [
#     { "{#PEER}":"201", "{#STATE}":"OK", "{#LATENCY}":"10"},
#     { "{#PEER}":"202", "{#STATE}":"UNKNOWN", "{#LATENCY}":""},
#     { "{#PEER}":"203", "{#STATE}":"OK", "{#LATENCY}":"72"}
#   ]
# }

cmd="$1"
shift

# exit on first error
set -e

[ -z "$cmd" ] && echo "ERROR: missing arguments... exiting" && exit 1

## Asterisk command cache
asteriskCmd() {
  asteriskCmd=$@
  if [ "$asteriskCacheEnabled" = "true" ]; then
      asteriskCacheFile="$asteriskCacheDir/$(echo $asteriskCmd | sed 's/ /_/g')"
      [ ! -e "$asteriskCacheDir" ] && install -m 750 -d "$asteriskCacheDir"
      [ ! -e "$asteriskCacheFile" ] && touch "$asteriskCacheFile"
      if [ -z "$(cat "$asteriskCacheFile")" ] || [ "$(( $(date +"%s") - $(stat -c "%Y" $asteriskCacheFile) ))" -gt "$asteriskCacheTime" ]; then
        $sudo asterisk -rx "$asteriskCmd" > "$asteriskCacheFile"
      fi
      cat "$asteriskCacheFile"
    else
      $sudo asterisk -rx "$asteriskCmd"
  fi
}

## discovery functions
# SIP/IAX2 registrations trunks
convert_registrations_to_json() {
  echo "{
  \"data\":
  ["
  echo "$REGISTRY" | while read registry; do
  HOST="$(echo $registry | awk '{print $1}')"
  USERNAME="$(echo $registry | awk '{print $3}')"
  STATE="$(echo $registry | awk '{print $5}')"
  [ ! -z "$HOST" ] && echo "    { \"{#HOST}\":\"$HOST\", \"{#USERNAME}\":\"$USERNAME\", \"{#STATE}\":\"$STATE\"},"
  done | sed '$ s/,$//'
  echo "  ]
}"
}

# PJSIP registrations trunks
convert_pjsip_registrations_to_json() {
  echo "{
  \"data\":
  ["
  echo "$REGISTRY" | while read registry; do
  HOST="$(echo $registry | awk '{print $1}' | awk -F "/sip:" '{print $2}')"
  ENDPOINT="$(echo $registry | awk '{print $2}')"
  USERNAME="$(asteriskCmd "pjsip show endpoint $ENDPOINT" | grep "$ENDPOINT/sip:" | awk '{print $2}' | awk -F"/sip:" '{print $2}' | awk -F"@" '{print $1}')"
  STATE="$(echo $registry | awk '{print $3}')"
  [ ! -z "$HOST" ] && echo "    { \"{#HOST}\":\"$HOST\", \"{#ENDPOINT}\":\"$ENDPOINT\",  \"{#USERNAME}\":\"$USERNAME\", \"{#STATE}\":\"$STATE\"},"
  done | sed '$ s/,$//'
  echo "  ]
}"
}

# SIP/IAX2 peers
convert_peers_to_json() {
  echo "{
  \"data\":
  ["
  echo "$PEERS" | while read line; do
  PEER="$(echo $line | awk '{print $1}' | awk -F "/" '{print $1}')"
  STATE="$(echo $line | awk '{print $2}')"
  LATENCY="$(echo $line | awk '{print $3}')"
  [ ! -z "$PEER" ] && echo "    { \"{#PEER}\":\"$PEER\", \"{#STATE}\":\"$STATE\", \"{#LATENCY}\":\"$LATENCY\"},"
  done | sed '$ s/,$//'
  echo "  ]
}"
}

# PJSIP endpoints
convert_endpoints_to_json() {
  echo "{
  \"data\":
  ["
  echo "$ENDPOINTS" | while read line; do
  ENDPOINT="$(echo $line | awk '{print $1}' | awk -F "/" '{print $1}')"
  STATE="$(echo $line | cut -d" " -f2-)"
  [ ! -z "$ENDPOINT" ] && echo "    { \"{#ENDPOINT}\":\"$ENDPOINT\", \"{#STATE}\":\"$STATE\"},"
  done | sed '$ s/,$//'
  echo "  ]
}"
}

# trunk registrations discovery
discovery.iax2.registry() {
  if asteriskCmd "iax2 show registry" | grep -qi ^'No such command'; then
    REGISTRY=""
  else
    REGISTRY="$(asteriskCmd "iax2 show registry" | sed -e '1,1d' -e '$d')"
  fi
  convert_registrations_to_json
}

discovery.sip.registry() {
  REGISTRY="$(asteriskCmd "sip show registry" | sed -e '1,1d' -e '$d')"
  convert_registrations_to_json
}

discovery.pjsip.registry() {
  #REGISTRY="$(asteriskCmd "pjsip show registrations" | grep -v -e "^$" -e "<Registration/ServerURI" -e "^===" -e "^Objects")"
  REGISTRY="$(asteriskCmd "pjsip show registrations" | sed -e '1,1d' -e '$d' | grep -v -e "^$" -e "<Registration/ServerURI" -e "^===" -e "^Objects")"
  convert_pjsip_registrations_to_json
}

# peers discovery
discovery.iax2.peers() {
  if asteriskCmd "iax2 show peers" | grep -qi ^'No such command'; then
    PEERS=""
  else
    # FIXME: because asterisk print empty columns in the "iax2 show peers" command, I must hardcode the field width, if asterisk will change the width we must update this function
    PEERS="$(asteriskCmd "iax2 show peers" | sed -e '1,1d' -e '$d' | awk -v FIELDWIDTHS="17 41 5 42 15 11" '{print $1" "$6}' | sed -e 's/(//g' -e 's/)//g' | awk '{print $1" "$2" "$3}' | sed 's/  \+/ /g')"
  fi
  convert_peers_to_json
}

discovery.sip.peers() {
  if asteriskCmd "sip show peers" | grep -qi ^'No such command'; then
    PEERS=""
  else
    # FIXME: because asterisk print empty columns in the "sip show peers" command, I must hardcode the field width, if asterisk will change the width we must update this function
    PEERS="$(asteriskCmd "sip show peers" | sed -e '1,1d' -e '$d' | awk -v FIELDWIDTHS="26 41 3 11 12 3 9 11" '{print $1" "$8}' | sed -e 's/(//g' -e 's/)//g' | awk '{print $1" "$2" "$3}' | sed 's/  \+/ /g')"
  fi
  convert_peers_to_json
}

discovery.pjsip.endpoints() {
  if asteriskCmd "pjsip show endpoints" | grep -qi ^'No such command'; then
    ENDPOINTS=""
  else
    # FIXME: because asterisk print empty columns in the "pjsip list endpoints" command, I must hardcode the field width, if asterisk will change the width we must update this function
    ENDPOINTS="$(asteriskCmd "pjsip list endpoints" | grep -v "<.*>" | grep -w "Endpoint:" | awk -v FIELDWIDTHS="12 53 14 2 3 3" '{print $2" "$3}')"
  fi
  convert_endpoints_to_json
}


## status functions 
service.status() {
  pgrep -x asterisk >/dev/null
  [ $? = 0 ] && echo Up || echo Down
}

# return int
calls.active() {
  # disable cache for this check
  asteriskCacheEnabled=false
  # ignore "Ringing" channels and show only active calls ("Up")
  expr $(asteriskCmd "core show channels concise"  | grep "\!Up\!" | wc -l) / 2
}

# return int
calls.processed() {
  # disable cache for this check
  asteriskCacheEnabled=false
  asteriskCmd "core show channels" | grep "call.* processed" | cut -d" " -f 1
}

calls.longest.duration() {
  # disable cache for this check
  asteriskCacheEnabled=false
  # grab only latest call duration in seconds
  duration="$(asteriskCmd 'core show channels concise' | awk -F\! '{print $12" "$1}' | sort -n | tail -1 | cut -d" " -f 1)"
  [ -z "$duration" ] && echo 0 || echo "$duration"
}

calls.longest.channel() {
  # disable cache for this check
  asteriskCacheEnabled=false
  # grab only latest call duration in seconds
  channel="$(asteriskCmd 'core show channels concise' | awk -F\! '{print $12" "$1}' | sort -n | tail -1 | cut -d" " -f 2)"
  [ -z "$channel" ] && echo 0 || echo "$channel"
}

# return secs
lastreload() {
  asteriskCmd "core show uptime seconds" | awk -F": " '/Last reload:/{print$2}'
}

# return secs
systemuptime() {
  asteriskCmd "core show uptime seconds" | awk -F": " '/System uptime:/{print$2}'
}

# return text
version() {
  asteriskCmd "core show version"
}

## sip functions - nb. trunks names must container alphanumeric chars adn peer names only numbers
# return text
sip.registry() {
  asteriskCmd "sip show registry" | sed -e '1,1d' -e '$d' | grep -w "$1" | sed 's/Request Sent/RequestSent/' | awk '{print $5}'
}

sip.peer.status() {
  asteriskCmd "sip show peer $1" | grep -w "Status.*" | sed -e 's/(//g' -e 's/)//g' | awk '{print $3}' | tr -d [:space:]
}

sip.peer.latency() {
  asteriskCmd "sip show peer $1" | grep -w "Status.*" | sed -e 's/(//g' -e 's/)//g' | awk '{print $4}' | tr -d [:space:]
}

sip.peers.online(){
  asteriskCmd "sip show peers" | sed -e '1,1d' -e '$d' | grep -w OK | wc -l
}

sip.peers.offline(){
  asteriskCmd "sip show peers" | sed -e '1,1d' -e '$d' | grep -wv OK | wc -l
}

sip.trunks.online(){
  # FIXME: trunk name MUST container letters to be discovered
  asteriskCmd "sip show peers" | sed -e '1,1d' -e '$d' | grep -w OK | awk '{print $1}' | grep [A-Za-z] | wc -l
}

sip.trunks.offline(){
  # FIXME: trunk name MUST container letters to be discovered
  asteriskCmd "sip show peers" | sed -e '1,1d' -e '$d' | grep -wv OK | awk '{print $1}' | grep [A-Za-z] | wc -l
}

# iax2 functions
iax2.registry() {
  asteriskCmd "iax2 show registry" | sed -e '1,1d' -e '$d' | grep -w "$1" | sed 's/Request Sent/RequestSent/' | awk '{print $5}'
}

iax2.peer.status() {
  asteriskCmd "iax2 show peer $1" | grep -w "Status.*" | sed -e 's/(//g' -e 's/)//g' | awk '{print $3}' | tr -d [:space:]
}

iax2.peer.latency() {
  asteriskCmd "iax2 show peer $1" | grep -w "Status.*" | sed -e 's/(//g' -e 's/)//g' | awk '{print $4}' | tr -d [:space:]
}

iax2.peers.online(){
  asteriskCmd "iax2 show peers" | sed -e '1,1d' -e '$d' | grep -w OK | wc -l
}

iax2.peers.offline(){
  asteriskCmd "iax2 show peers" | sed -e '1,1d' -e '$d' | grep -wv OK | wc -l
}

iax2.trunks.online(){
  # FIXME: trunk name MUST container letters to be discovered
  asteriskCmd "iax2 show peers" | sed -e '1,1d' -e '$d' | grep -w OK | awk '{print $1}' | grep [A-Za-z] | wc -l
}

iax2.trunks.offline(){
  # FIXME: trunk name MUST container letters to be discovered
  asteriskCmd "sip show peers" | sed -e '1,1d' -e '$d' | grep -wv OK | awk '{print $1}' | grep [A-Za-z] | wc -l
}

# pjsip functions
pjsip.registry() {
  #asteriskCmd "pjsip show registration $1" | grep "$1/sip:" | awk '{print $3}'
  asteriskCmd "pjsip show endpoint $1" | grep "$1/sip:" | awk '{print $4}'
}

pjsip.endpoint.status() {
  CONTACT=$(asteriskCmd "pjsip list contacts" | grep -v "<.*>" | grep "Contact.*$1" | awk '{print $4}')
  if [ ! -z "$CONTACT" ]; then
      echo $CONTACT
    else
      # if the endpoint is not registered (missing contact) discover using 'pjsip list endpoints' command
      # FIXME: because asterisk print empty columns in the "pjsip list endpoints" command, I must hardcode the field width, if asterisk will change the width we must update this function
      asteriskCmd "pjsip list endpoints" | grep -v "<.*>" | grep "Endpoint.*$1" | awk -v FIELDWIDTHS="12 53 14 2 3 3" '{print $3}'
  fi
}

pjsip.endpoint.latency() {
  asteriskCmd "pjsip list contacts" | grep -v "<.*>" | grep "Contact.*$1" | awk '{print $5}' | cut -d. -f1
}

pjsip.endpoints.online() {
  asteriskCmd "pjsip show endpoints" | grep "Contact:" | egrep "Avail" | awk '{print $2}'| cut -d "/" -f1 | wc -l
}

pjsip.endpoints.offline() {
  asteriskCmd "pjsip show endpoints" | grep "Endpoint:" | grep -v "<Endpoint/CID" | grep "Unavailable" | awk '{print $2}'| cut -d "/" -f1 | wc -l
}

pjsip.trunks.online() {
  # FIXME: trunk name MUST container letters to be discovered
  asteriskCmd "pjsip show endpoints" | grep "Contact:" | egrep "Avail" | awk '{print $2}'| cut -d "/" -f1 | grep [A-Za-z] | wc -l
}

pjsip.trunks.offline() {
  # FIXME: trunk name MUST container letters to be discovered
  asteriskCmd "pjsip show endpoints" | grep "Contact:" | egrep -e "NonQual" | awk '{print $2}'| cut -d "/" -f1 | grep [A-Za-z] | wc -l
}

# execute the passed command
#set -x
$cmd $@
