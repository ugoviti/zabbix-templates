# Synbak Zabbix Template
Monitor Synbak Backup Reports using Zabbix Network Monitoring system

## Features

### Items
- Failed Jobs
- Successful Jobs
- All Jobs Count
- All Jobs Status
- Last Run Date

### Triggers
- Failed Jobs
- Job not running since time

## Installation
- Install and configure Synbak >= 3.8.1 from https://github.com/ugoviti/synbak
- Import the template into Zabbix Configuration Template Section

## Template Macros available
- `{$SYNBAK_URL}`: Synbak HTML report URL, example: http://bck01/admin/log/backup
- `{$SYNBAK_ERRORS_DURATION}`: After this time, the failed backups will not counted anymore as errors
- `{$SYNBAK_NODATA_MAXTIME}`: Maximum threshold hours since last run. If data is not received will be fired a warning trigger
