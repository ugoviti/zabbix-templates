# WEB URLs and SSL Monitor Template
Monitor WEB URLs response time, reachability and SSL/HTTPS certificates expire time using Zabbix Network Monitoring system

![URL Monitor](url-monitor-dashboard.png)

## Features
- Zabbix Agent based (require Zabbix server >= 5.4)
- Simple and short Linux bash script based template (only openssl command required)
- Easy Intallation and Configuration
- LLD Discovery based template
- Multiple SSL domains support using one CSV file as input for LLD (local file path or HTTP URL supported)
- Accounting of Expire Date and Time Left of the Expiring SSL certificates
- 4 configurable types of trigger notifications (7 days left to expire, 3 days left to expire, certificate expired, domain https unreachable)
- Configurable macros values for expiration days and CSV file/url path
- Automatic Graphs and dashboard for response time metrics

## Installation
- `ZABBIX_AGENT_DIR="/etc/zabbix/zabbix_agentd.d"`
- `mkdir -p $ZABBIX_AGENT_DIR/../scripts/`
- `cp scripts/url-monitor.sh $ZABBIX_AGENT_DIR/../scripts/`
- `chmod 755 $ZABBIX_AGENT_DIR/../scripts/url-monitor.sh`
- `cp url-monitor.conf $ZABBIX_AGENT_DIR/`
- Restart zabbix-agent: `systemctl restart zabbix-agent `
- Import `url-monitor-zbx_export_templates.xml` into Zabbix templates panel
- Assign Zabbix template to the host, customize the `{$URL_PATH_CSV}` macro path with your CSV file and wait for automatic discovery

## CSV Template example

```/etc/zabbix/url-monitor.csv
https://www.initzero.it
https://www.wearequantico.it
# this is a comment and will be excluded
# follow an example with different port
http://www.otherdomain.fqdn:8080
https://www.amazon.it/gp/bestsellers/?ref_=nav_em_cs_bestsellers_0_1_1_2
```

## Template macros available
- `{$URL_PATH_CSV}`: CSV file path or url of domains list (example: '/etc/zabbix/url-monitor.csv' or 'http://yourserver.local/url-monitor.csv')
- `{$URL_LATENCY_WARNING}`: Default acceptable latency for loading URL (seconds)
- `{$URL_SSL_EXPIRE_TIME_CRITICAL}`: Critical level for SSL certificate expiration time (days)
- `{$URL_SSL_EXPIRE_TIME_WARNING}`: Warning level for SSL certificate expiration time (days)
