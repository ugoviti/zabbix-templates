# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2020-11-20
### Added
- new MACRO: `{$SYNBAK_ERRORS_DURATION}`: After this time, the failed backups will not counted anymore as errors
- new MACRO: `{$SYNBAK_NODATA_MAXTIME}`: Maximum threshold hours since last run. If data is not received will be fired a warning trigger
- new Item: Synbak Last Run
- new Trigger: No Synbak jobs running since {$SYNBAK_NODATA_MAXTIME}
### Changed
- Export in YAML format (default used by Zabbix 5.2)

## 2020-10-01
### Added
- First Public Release
