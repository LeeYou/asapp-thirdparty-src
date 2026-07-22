# openssl source placeholder

该目录用于存放受控纳管的 `OpenSSL` 源码或平台发行包元数据。

当前阶段仅约束 `app-service` 的 `Boost.Asio + Boost.Beast` TLS 接线前置条件。

启用条件：

- 受控 `OpenSSL` 源码或可审计发行包已落仓
- 版本、来源、哈希已同步登记到 `third_party/manifests/dependencies.yaml`
- 链接策略与发布物纳入构建与发布治理
- 显式打开 `ASAPP_ENABLE_BOOST_BEAST_TLS`

后续纳管时需同步记录版本、来源、哈希，并将平台差异、证书策略与本地补丁一并收口。
