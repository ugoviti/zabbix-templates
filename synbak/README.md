# Synbak Zabbix Template
Monitor Synbak Backup Reports using Zabbix Network Monitoring system

## Features
- Synbak Failed Jobs + Trigger
- Synbak Successful Jobs
- Synbak All Jobs Count
- Synbak All Jobs Status

## Installation
- Install and configure Synbak >= 3.8.1 from https://github.com/ugoviti/synbak
- Import the template into Zabbix Configuration

## Template Macros available
- `{$SYNBAK_URL}`: Synbak HTML report URL, example: http://bck01/admin/log/backup
