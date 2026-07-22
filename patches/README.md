# patches 目录说明

本目录用于存放对第三方依赖的补丁文件。

## 要求

- 每个依赖使用独立子目录
- 补丁文件命名建议包含序号与用途
- 补丁必须可追踪、可回放、可审计

## 示例

```text
patches/
  /libcef
    0001-fix-platform-detection.patch
  /fmt
    0001-adjust-warning-level.patch
```
