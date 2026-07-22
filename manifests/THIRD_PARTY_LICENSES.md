# AsApp Third-Party License Manifest

This document lists all third-party dependencies used by AsApp, their versions, license types, and commercial use status.

Generated from `dependencies.yaml` and `sbom.cdx.json`.

---

## License Summary

| License | Count | Commercial Use |
| --- | --- | --- |
| BSD-3-Clause (BSD-like) | 1 | Allowed |
| MIT | 3 | Allowed |
| BSL-1.0 | 1 | Allowed |
| Apache-2.0 | 1 | Allowed |
| Public Domain | 1 | Allowed |

All licenses are on the project-approved whitelist (MIT, BSD, Apache-2.0, BSL, ISC, Zlib, Public Domain).

No GPL, LGPL, or AGPL dependencies are present.

---

## Component Details

### 1. libcef

- **Version**: 102.0.10+gf249b2e+chromium-102.0.5005.115
- **License**: BSD-3-Clause (BSD-like)
- **SPDX**: BSD-3-Clause
- **Commercial Use**: Allowed
- **Module**: app-gui
- **Category**: A (framework)
- **Source Hash (SHA-256)**: `773e2a2d8752c53c32b43ad7d1757c13bec34e7093a3e9f9be83f17ca7f824b3`
- **Notes**: Chromium Embedded Framework for GUI runtime.

### 2. fmt

- **Version**: (planned)
- **License**: MIT
- **SPDX**: MIT
- **Commercial Use**: Allowed
- **Module**: app-host
- **Category**: B (library)
- **Status**: Planned dependency, not yet integrated.
- **Notes**: Formatting library for host-side formatting.

### 3. spdlog

- **Version**: (planned)
- **License**: MIT
- **SPDX**: MIT
- **Commercial Use**: Allowed
- **Module**: app-host
- **Category**: B (library)
- **Status**: Planned dependency, not yet integrated.
- **Notes**: Structured logging library for host-side logging.

### 4. nlohmann-json

- **Version**: 3.11.3
- **License**: MIT
- **SPDX**: MIT
- **Commercial Use**: Allowed
- **Module**: app-service
- **Category**: B (library)
- **Source Hash (SHA-256)**: `9bea4c8066ef4a1c206b2be5a36302f8926f7fdc6087af5d20b417d0cf103ea6`
- **Source URL**: https://raw.githubusercontent.com/nlohmann/json/v3.11.3/single_include/nlohmann/json.hpp
- **Notes**: Single-header JSON library for app-service serialization.

### 5. boost

- **Version**: 1.90.0
- **License**: BSL-1.0
- **SPDX**: BSL-1.0
- **Commercial Use**: Allowed
- **Module**: app-service
- **Category**: B (library)
- **Source Hash (SHA-256)**: `9f67e625338215f240a52ea487a9f100c01cedd4a35ffd8b711eb692cbdac708`
- **Source URL**: https://archives.boost.io/release/1.90.0/source/boost_1_90_0.zip
- **Notes**: C++ libraries; app-service constrains usage to Asio and Beast subset.

### 6. libffi

- **Version**: 3.4.6
- **License**: MIT
- **SPDX**: MIT
- **Commercial Use**: Allowed
- **Module**: app-host
- **Category**: B (library)
- **Status**: Staged dependency, gated by ASAPP_ENABLE_LIBFFI.
- **Source URL**: https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz
- **Notes**: Foreign function interface library for dynamic C function invocation in BusinessCapabilityEngine.

### 7. openssl

- **Version**: 3.5.6
- **License**: Apache-2.0
- **SPDX**: Apache-2.0
- **Commercial Use**: Allowed
- **Module**: app-service
- **Category**: B (library)
- **Source Hash (SHA-256)**: `0c0511433a574c68e2b2dcfe2f375243137867d583bcc0d5e76b4d46876fa917`
- **Source URL**: https://www.openssl.org/source/openssl-3.5.6.tar.gz
- **Notes**: TLS library for app-service secure transport.

### 8. sqlite

- **Version**: 3.53.3
- **License**: Public Domain (SQLite Blessing)
- **SPDX**: Blessing / Public Domain
- **Commercial Use**: Allowed
- **Module**: common/config, app-host
- **Category**: B (library)
- **Source Hash (SHA-256 of zip)**: `646421e12aac110282ef8cc68f1a62d4bb15fc7b8f09da0b53e29ee690500431`
- **Source URL**: https://www.sqlite.org/2026/sqlite-amalgamation-3530300.zip
- **Notes**: Amalgamation for embedded `als_config.db`; exposed only via `IConfigService`, never direct `sqlite3_open` from business modules.

---

## Compliance Statement

All third-party dependencies have been reviewed for license compliance. Only dependencies with licenses on the approved whitelist (MIT, BSD, Apache-2.0, BSL-1.0, ISC, Zlib, Public Domain) are permitted. GPL, LGPL, and AGPL licensed dependencies are prohibited unless a legal review and product isolation strategy is explicitly approved.

This manifest is validated by CI (`license_compliance_validate` CTest target).
