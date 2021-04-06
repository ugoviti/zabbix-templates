# TurboSMTP Template
Check TurboSMTP Mail Sending API service (https://www.serversmtp.com/it/)

## Features
- Trigger: threshold for hourly send rate
- Trigger: threshold for monthly sent emails
- Item: Emails Sent (this month)
- Item: Emails Sent (previous month)
- Item: Emails Sent (today)
- Item: Emails Delivered (today)
- Item: Emails Failed (today)
- Item: Emails Read (today)
- Item: Emails Sent (this week)
- Item: Emails Sent (previous week)
- Item: Emails Quota Limit (monthly)

## Installation
- `ZABBIX_SCRIPTS_DIR="/etc/zabbix/scripts"`
- `ZABBIX_AGENT_DIR="$ZABBIX_AGENT_DIR/zabbix_agent2.d"`
- `mkdir -p $ZABBIX_SCRIPTS_DIR $ZABBIX_AGENT_DIR`
- `cp scripts/turbosmtp.sh $ZABBIX_SCRIPTS_DIR/scripts/`
- `chmod 755 $ZABBIX_SCRIPTS_DIR/scripts/turbosmtp.sh`
- `cp turbosmtp.conf $ZABBIX_AGENT_DIR/`
- Restart zabbix-agent: `systemctl restart zabbix-agent2`
- Import `turbosmtp-zbx_export_templates.yaml` into Zabbix templates panel
- Assign Zabbix template to the host and customize the MACROS

## Template macros available
- `{$TURBOSMTP.USERNAME}`: TurboSMTP Username (Email Address)
- `{$TURBOSMTP.PASSWORD}`: TurboSMTP Password
- `{$TURBOSMTP.QUOTA.WARN.LIMIT}`: % of monthly send quota limit before triggering alarm\
- `{$TURBOSMTP.THRESHOLD.HOURLY}`: Hourly max sending mail threshold
