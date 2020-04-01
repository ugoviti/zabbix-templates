# Asterisk Zabbix Template

Monitor Asterisk PBX systems using Zabbix Network Monitoring system

## Features
- Fast installation and easy configuration (pure bash script without particular dependencies)
- Single script for discovery and checks
- Zabbix Agent based checks
- Automatic discovery, monitoring and triggers generation for SIP and IAX Trunks
- Monitoring of active calls
- Monitoring of processed calls
- Monitoring of stucked calls
- Monitoring of last reload time
- Monitoring of uptime asterisk core
- Monitoring of asterisk version
- Monitoring of sip/iax2 online/offline peers
- Monitoring of sip/iax2 online/offline trunks

## Installation

- `cp zabbix_agentd.d/scripts/asterisk.sh /etc/zabbix/zabbix_agentd.d/scripts/asterisk.sh`
- `chmod 755 /etc/zabbix/zabbix_agentd.d/scripts/asterisk.sh`
- `cp zabbix_agentd.d/asterisk.conf /etc/zabbix/zabbix_agentd.d/asterisk.conf`
- Edit `sudoers` using `visudo` command and add:
```
User_Alias ZABBIX = zabbix
Cmnd_Alias ZABBIX_COMMANDS = /usr/sbin/asterisk
Defaults:ZABBIX !requiretty
ZABBIX ALL=(ALL) NOPASSWD: ZABBIX_COMMANDS
```
- Restart zabbix-agent: `systemctl restart zabbix-agent `
- Import `Asterisk-zbx_export_templates.xml` into Zabbix templates panel
- Assign Zabbix template to the Asterisk Host and wait automatic discovery


## TODO
- PJSIP Support

