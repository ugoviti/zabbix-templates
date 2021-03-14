# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2021-03-14
### Changed
- Major Template rewrite, replace the script on every asterisk installation and import new template
- Changed Template name from "Template App Asterisk" to "Asterisk PBX"
- Renamed MACROS: (NOTE: if you changed defaults values, remember to update the macros associated to your hosts)
  - from {$ACTIVE_CALLS_THRESHOLD} to {$ASTERISK_CALLS_ACTIVE_WARN}
  - from {$LOGENST_CALL_DURATION} to {$ASTERISK_CALLS_DURATION_WARN}
### Added
- New Template Dashboard
- Caching of commands (to lowering the load on busy asterisk pbx)
- Refactoring of Graphs
- Item PJSIP Trunks Online/Offline
- Item PJSIP Endpoints Online/Offline
- Item IAX2 Peers Online/Offline
- Trigger for last restart
- Trigger for last reload
- Trigger for version change
- Trigger for peers high latency
- New Macro: {$ASTERISK_PEER_LATENCY_WARN} (default 400 ms)
- Dicovery+Triggers of IAX2 Peers
- Dicovery+Triggers of PJSIP Endpoints (enabled discovery but disabled item collection and triggers by default, enable by hand the items you want to monitor)
- Dicovery+Triggers of SIP Peers (enabled discovery but disabled item collection and triggers by default, enable by hand the items you want to monitor)


## [1.0.0] - 2020-03-31
### Added
- First public release
