# 分支策略 — asapp-thirdparty-src

## 1. 长期分支

| 分支 | 用途 | 保护建议 |
|------|------|----------|
| `main` | 已发布/可复现的源码快照；仅接受合并 | 禁止直推；需 PR |
| `develop` | 集成分支：纳管新库、补丁、构建脚本 | 日常 PR 目标 |

## 2. 短期分支

| 模式 | 从哪拉 | 合回哪 | 说明 |
|------|--------|--------|------|
| `feature/<pkg>-...` | `develop` | `develop` | 新库 / 大改构建 |
| `fix/<pkg>-...` | `develop` 或 `main` | 同源 | 构建/补丁缺陷 |
| `cve/<pkg>-...` | 视紧急度 | `develop` 且必要时 cherry-pick 到 `main` | 安全响应 |
| `release/deps-YYYY.MM.DD` | `develop` | → `main` | 冻结一次制品发布对应的源码 |

## 3. 与制品仓的关系

1. 在 `develop`（或 `release/*`）完成矩阵构建  
2. 推送到 **asapp-thirdparty-prebuilt** 的 `develop`，验证后打 tag `deps-YYYY.MM.DD` 并合入制品仓 `main`  
3. 源码仓 `release/*` 合入 `main`，在 `manifests/RELEASES.md` 记录 `prebuilt_tag` 与本仓 commit  
4. 更新本仓 `prebuilt` 子模块指针（可选）

## 4. Tag（源码仓）

| Tag | 含义 |
|-----|------|
| `src-deps-YYYY.MM.DD` | 与制品 `deps-YYYY.MM.DD` 对应的源码冻结点 |

不必为每个包打 tag；以「依赖集发布」为单位。

## 5. 禁止

- 在 `main` 上直接堆未验证大二进制  
- 使用与制品仓无关的长期 `windows-only` 分支分叉源码树  
- 强推已发布的 `src-deps-*` tag
