# Zabbix Template Veeam Agent for Linux
This Zabbix template is designed to interact with Veeam Agent, providing functionalities such as discovering Veeam license information, checking job statuses, and retrieving detailed logs for Veeam backup jobs

## Features
- Zabbix Agent based (developed and tested with Zabbix server >= 7.0)
- Simple Linux bash script based template
- Easy Intallation and Configuration
- LLD Discovery Items and Triggers based template
- Expire Date and Time Left of the expiring Veeam Agent License
- Configurable macros

### Macros
- {$VEEAM_JOB_HOURS_WARN} - Warn if no backup occurs in the specified time
- {$VEEAM_LICENSE_EXPIRE_WARN} - Warn days before license expires

### Items
- Veeam Agent License Email
- Veeam Agent License Expiration
- Veeam Agent License Expiration Days Left
- Veeam Agent License Owner
- Veeam Agent License Source
- Veeam Agent License Status
- Veeam Agent Mode

### Triggers
- No Veeam Agent data collection since 12h
- Veeam Agent Backup License will expire in {$VEEAM_LICENSE_EXPIRE_WARN} days

### Items prototypes
- Veeam Agent job {#JOB_NAME} data processed
- Veeam Agent job {#JOB_NAME} data transfered
- Veeam Agent job {#JOB_NAME} description
- Veeam Agent job {#JOB_NAME} log file
- Veeam Agent job {#JOB_NAME} status
- Veeam Agent job {#JOB_NAME} time duration
- Veeam Agent job {#JOB_NAME} time end
- Veeam Agent job {#JOB_NAME} time start
- Veeam Agent repository {#REPO_NAME} accessible
- Veeam Agent repository {#REPO_NAME} ID
- Veeam Agent repository {#REPO_NAME} location
- Veeam Agent repository {#REPO_NAME} type

### Triggers prototypes
- Veeam Agent job {#JOB_NAME} time start
- No Veeam Agent Backup job running since {$VEEAM_JOB_HOURS_WARN}
- Veeam Agent repository {#REPO_NAME} is not accessible

## Installation
- Install and configure the main script into zabbix agent:
```
ZABBIX_SCRIPTS_DIR="/etc/zabbix/scripts"
ZABBIX_AGENT_DIR="/etc/zabbix/zabbix_agent2.d"
mkdir -p $ZABBIX_SCRIPTS_DIR $ZABBIX_AGENT_DIR

wget https://raw.githubusercontent.com/ugoviti/zabbix-templates/refs/heads/main/veeam-agent/scripts/veeam-agent.sh -O $ZABBIX_SCRIPTS_DIR/veeam-agent.sh
wget https://raw.githubusercontent.com/ugoviti/zabbix-templates/refs/heads/main/veeam-agent/zabbix_agent2.d/veeam-agent.conf -O $ZABBIX_AGENT_DIR/veeam-agent.conf

chmod 755 $ZABBIX_SCRIPTS_DIR/*

# add user zabbix to veeam group
gpasswd -a zabbix veeam

systemctl restart zabbix-agent2

```
- Import `veeam-agent_zbx_export_templates.yaml` into Zabbix templates panel
- Assign Zabbix template to the host and customize the MACROS


## Tips & Tricks

Show latest backup job info:
```
JOB_NAME=srv01 ; veeamconfig session log --id "$(veeamconfig session info --id "$(veeamconfig session list --jobid "$(veeamconfig job list | awk "/^$JOB_NAME/ {print \$2}")" | awk "/^$JOB_NAME/ {print \$3}" | tail -n1)" | sed 's/^[ \t]*//')" | grep -v "\[info\]" | grep -v "Processing finished" | sed 's/^[^]]*\] //'
```

Show latest backup job log:
```
JOB_NAME=srv01 ; veeamconfig session log --id "$(veeamconfig session list --jobid "$(veeamconfig job list | awk "/^$JOB_NAME/ {print \$2}")" | awk "/^$JOB_NAME/ {print \$3}" | sed 's/^[ \t]*//')"
```
