# Web SSL Certificates Template
Monitor WEB servers SSL/HTTPS certificates expire time

## Features
- Zabbix Agent based
- Easy Intallation and Configuration
- LLD Discovery based template
- Multiple SSL domains support using CSV as input file for LLD
- 4 types of trigger notifications (7 days left to expire, 3 days left to expire, certificate expired, domain https unreachable)
- Configurable macros values for expiration days and CSV file path

## Installation
- `ZABBIX_AGENT_DIR="/etc/zabbix/zabbix_agentd.d"`
- `mkdir -p $ZABBIX_AGENT_DIR/../scripts/`
- `cp scripts/sslCertificate.sh $ZABBIX_AGENT_DIR/../scripts/`
- `chmod 755 $ZABBIX_AGENT_DIR/../scripts/sslCertificate.sh`
- `cp sslCertificate.conf $ZABBIX_AGENT_DIR/`
- Restart zabbix-agent: `systemctl restart zabbix-agent `
- Import `sslCertificate-zbx_export_templates.xml` into Zabbix templates panel
- Assign Zabbix template to the host, customize the `{$SSL_CERT_FILEPATH_CSV}` macro path with your CSV file and wait for automatic discovery

## CSV Template example

```/etc/zabbix/ssl-domains.csv
{#DOMAIN}
www.initzero.it
www.wearequantico.it
# this is a comment and will be excluded
# follow an example with different port
www.otherdomain.fqdn:8080
```

## Template macros available
- `{$SSL_CERT_EXPIRE_TIME_CRITICAL}`: Critical level expiration days left
- `{$SSL_CERT_EXPIRE_TIME_WARNING}`: Warning level expiration days left
- `{$SSL_CERT_FILEPATH_CSV}`: CSV file path of domains list
