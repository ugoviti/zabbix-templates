# Asterisk Zabbix Template
Monitor Asterisk PBX systems using Zabbix Network Monitoring system

## Features
- Easy installation and fast configuration (pure bash script without extra dependencies to install)
- Single script for discovery and checks
- Zabbix Agent based checks
- Automatic discovery, monitoring and triggers generation for PJSIP, SIP and IAX Trunks
- Monitoring of active calls
- Monitoring of processed calls
- Monitoring of stucked calls
- Monitoring of last reload time
- Monitoring of uptime asterisk core
- Monitoring of asterisk version
- Monitoring of pjsip online/offline endpoints and registrations
- Monitoring of sip/iax2 online/offline peers and registrations
- Triggers for max active concurrent calls, call max duration time, Asterisk service problems, trunks registrations problems

## Installation
- `cp zabbix_agentd.d/scripts/asterisk.sh /etc/zabbix/zabbix_agent*.d/scripts/asterisk.sh`
- `chmod 755 /etc/zabbix/zabbix_agent*.d/scripts/asterisk.sh`
- `cp zabbix_agentd.d/asterisk.conf /etc/zabbix/zabbix_agent*.d/asterisk.conf`
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


## Template Macros available
- `{$ACTIVE_CALLS_THRESHOLD}`: Alarm when reaching max active calls threshold (default: 20 calls)
- `{$LOGENST_CALL_DURATION}`: Alarm when reaching call duration time (default: 7200 seconds)
