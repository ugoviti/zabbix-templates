#!/bin/bash
# Zabbix Agent monitoring automatic discovery and check script for Asterisk PBX services
# author: Ugo Viti <ugo.viti@initzero.it>
# version: 20200402

# comment to disable sudo
sudo="sudo -u asterisk"

# SIP/IAX2 example JSON file for zabbix discovery
# {
#   "data":
#   [
#     { "{#HOST}":"voip.eutelia.it:5060", "{#USERNAME}":"05751234567", "{#STATE}":"Registered"},
#     { "{#HOST}":"sip.messagenet.it:5060", "{#USERNAME}":"34887123456", "{#STATE}":"Registered"}
#   ]
# }

# PJSIP example JSON file for zabbix discovery
# {
#   "data":
#   [
#     { "{#HOST}":"voip.eutelia.it", "{#ENDPOINT}":"ci-05751234567",  "{#USERNAME}":"05751234567", "{#STATE}":"Avail"},
#     { "{#HOST}":"sip.messagenet.it:5060", "{#ENDPOINT}":"mn-34887123456",  "{#USERNAME}":"34887123456", "{#STATE}":"Avail"},
#   ]
# }

cmd="$1"
shift

[ -z "$cmd" ] && echo "ERROR: missing arguments... exiting" && exit 1

## discovery functions
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

convert_pjsip_registrations_to_json() {
  echo "{
  \"data\":
  ["
  echo "$REGISTRY" | while read registry; do
  HOST="$(echo $registry | awk '{print $1}' | awk -F "/sip:" '{print $2}')"
  ENDPOINT="$(echo $registry | awk '{print $2}')"
  USERNAME="$($sudo asterisk -rx "pjsip show endpoint $ENDPOINT" | grep "$ENDPOINT/sip:" | awk '{print $2}' | awk -F"/sip:" '{print $2}' | awk -F"@" '{print $1}')"
  STATE="$(echo $registry | awk '{print $3}')"
  [ ! -z "$HOST" ] && echo "    { \"{#HOST}\":\"$HOST\", \"{#ENDPOINT}\":\"$ENDPOINT\",  \"{#USERNAME}\":\"$USERNAME\", \"{#STATE}\":\"$STATE\"},"
  done | sed '$ s/,$//'
  echo "  ]
}"
}

discovery.iax2.registry() {
  REGISTRY="$($sudo asterisk -rx "iax2 show registry" | grep -q 'No such command')"
  
  if [ $? == 0 ]; then ## IAX2 is not installed
    REGISTRY=""
  else
    REGISTRY="$($sudo asterisk -r -x "iax2 show registry" | grep -v -e "^Host" -e "IAX2 registrations")"
    fi
  
  convert_registrations_to_json
}

discovery.sip.registry() {
  REGISTRY="$($sudo asterisk -r -x "sip show registry" | grep -v -e "^Host" -e "SIP registrations")"
  convert_registrations_to_json
}

discovery.pjsip.registry() {
  REGISTRY="$($sudo asterisk -r -x "pjsip show registrations" | grep -v -e "^$" -e "<Registration/ServerURI" -e "^===" -e "^Objects")"
  convert_pjsip_registrations_to_json
}

## status functions 

service.status() {
  pgrep -x asterisk >/dev/null
  [ $? = 0 ] && echo Up || echo Down
}

# return int
calls.active() {
  $sudo asterisk -rx "core show channels" | grep "active call.*" | awk '{print$1}'
}

# return int
calls.processed() {
  $sudo asterisk -rx "core show channels" | grep "call.* processed" | awk '{print$1}'
}

calls.longest.channel() {
  # grab only latest call duration in seconds
  channel="$($sudo asterisk -rx 'core show channels concise' | cut -d'!' -f1 | sed 's/!/ /g' | tail -1)"
  [ -z "$channel" ] && echo 0 || echo "$channel"
}

calls.longest.duration() {
  # grab only latest call duration in seconds
  duration="$($sudo asterisk -rx 'core show channels concise' | cut -d'!' -f12 | sed 's/!/ /g' | tail -1)"
  [ -z "$duration" ] && echo 0 || echo "$duration"
}


# return secs
lastreload() {
  $sudo asterisk -rx "core show uptime seconds" | awk -F": " '/Last reload:/{print$2}'
}

# return secs
systemuptime() {
  $sudo asterisk -rx "core show uptime seconds" | awk -F": " '/System uptime:/{print$2}'
}

# return text
version() {
  $sudo asterisk -rx "core show version"
}

## sip functions - nb. trunks names must container alphanumeric chars adn peer names only numbers
# return text
sip.registry() {
  $sudo asterisk -rx "sip show registry" | grep $1 | sed 's/Request Sent/RequestSent/' | awk '{print $5}'
}

sip.peers.online(){
  $sudo asterisk -rx "sip show peers" | grep OK | awk '{print $1}' | grep -v [A-Za-z] | wc -l
}

sip.peers.offline(){
  $sudo asterisk -rx "sip show peers" | grep -e UNREACHABLE  -e UNKNOWN | awk '{print $1}' | grep -v [A-Za-z] | wc -l
}

sip.trunks.online(){
  $sudo asterisk -rx "sip show peers" | grep OK | awk '{print $1}' | grep [A-Za-z] | wc -l
}

sip.trunks.offline(){
  $sudo asterisk -rx "sip show peers" | grep -e UNREACHABLE  -e UNKNOWN | awk '{print $1}' | grep [A-Za-z] | wc -l
}

# iax2 functions
iax2.registry() {
  $sudo asterisk -rx "iax2 show registry" | grep $1 | sed 's/Request Sent/RequestSent/' | awk '{print $5}'
}

iax2.peers.online(){
  $sudo asterisk -rx "iax2 show peers" | grep OK | awk '{print $1}' | wc -l
}

iax2.peers.offline(){
  $sudo asterisk -rx "iax2 show peers" | grep -e UNREACHABLE  -e UNKNOWN | awk '{print $1}' | wc -l
}

iax2.trunks.online(){
  $sudo asterisk -rx "iax2 show peers" | grep OK | awk '{print $1}' | grep [A-Za-z] | wc -l
}

iax2.trunks.offline(){
  $sudo asterisk -rx "iax2 show peers" | grep -e UNREACHABLE  -e UNKNOWN | awk '{print $1}' | grep [A-Za-z] | wc -l
}

# pjsip functions
pjsip.registry() {
  #$sudo asterisk -rx "pjsip show registration $1" | grep "$1/sip:" | awk '{print $3}'
  $sudo asterisk -rx "pjsip show endpoint $1" | grep "$1/sip:" | awk '{print $4}'
}

pjsip.endpoints.online() {
  $sudo asterisk -rx "pjsip show endpoints" | grep "Contact:" | egrep "Avail" | awk '{print $2}'| cut -d "/" -f1 | wc -l
}

pjsip.endpoints.offline() {
  $sudo asterisk -rx "pjsip show endpoints" | grep "Endpoint:" | grep -v "<Endpoint/CID" | grep "Unavailable" | awk '{print $2}'| cut -d "/" -f1 | wc -l
}

pjsip.trunks.online() {
  $sudo asterisk -rx "pjsip show endpoints" | grep "Contact:" | egrep "Avail" | awk '{print $2}'| cut -d "/" -f1 | grep [A-Za-z] | wc -l
}

pjsip.trunks.offline() {
  $sudo asterisk -rx "pjsip show endpoints" | grep "Contact:" | egrep -e "NonQual" | awk '{print $2}'| cut -d "/" -f1 | grep [A-Za-z] | wc -l
}

# execute the passed command
#set -x
$cmd $@
