#!/usr/bin/env bash
# 供 scripts/*.sh source：统一并行度与 cmake/ninja/make 调用
# shellcheck disable=SC2034

asapp_dep_normalize_jobs() {
  local jobs="${1:-}"
  local nproc_n
  nproc_n="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
  if [[ -z "$jobs" || "$jobs" -lt 1 ]]; then
    jobs="$nproc_n"
  fi
  echo "$jobs"
}

# 在 build 目录执行并行编译（优先 ninja -j，保证真正并发）
# 用法：asapp_dep_cmake_build <build_dir> <jobs> [log_file]
asapp_dep_cmake_build() {
  local build_dir="$1"
  local jobs="$2"
  local log_file="${3:-}"
  jobs="$(asapp_dep_normalize_jobs "$jobs")"
  export CMAKE_BUILD_PARALLEL_LEVEL="$jobs"

  echo "  compile parallelism: -j${jobs} (CMAKE_BUILD_PARALLEL_LEVEL=${jobs})"

  local -a cmd
  if [[ -f "$build_dir/build.ninja" ]] && command -v ninja >/dev/null 2>&1; then
    cmd=(ninja -C "$build_dir" -j "$jobs")
  else
    # --parallel 传给 cmake；再 -- -j 传给底层生成器（双保险）
    cmd=(cmake --build "$build_dir" --parallel "$jobs" -- -j"$jobs")
  fi

  echo "  running: ${cmd[*]}"
  if [[ -n "$log_file" ]]; then
    # tee：既落盘又让终端能看到 ninja 进度（避免误以为单线程卡住）
    "${cmd[@]}" 2>&1 | tee "$log_file"
    return "${PIPESTATUS[0]}"
  fi
  "${cmd[@]}"
}

# 强制删除路径：先放开写权限（OpenSSL/gRPC 常 444；WSL/NTFS 上直接 rm 易 Permission denied）
asapp_dep_rm_rf() {
  local path="$1"
  local soft="${2:-0}" # 1=失败只告警不返回错误（用于清理旧树）
  if [[ -z "$path" || "$path" == "/" ]]; then
    echo "ERROR: asapp_dep_rm_rf refused empty or root path" >&2
    return 1
  fi
  if [[ ! -e "$path" ]]; then
    return 0
  fi
  # 尽量剥掉只读；归属非本人时 chmod 会失败，后面仍尝试 rm/find
  chmod -R u+w "$path" 2>/dev/null || true
  find "$path" -type f -exec chmod u+w {} + 2>/dev/null || true
  find "$path" -type d -exec chmod u+w {} + 2>/dev/null || true
  if rm -rf "$path" 2>/dev/null; then
    return 0
  fi
  # 二次：逐个删（部分 NTFS/只读场景下整树 rm 失败但单文件可删）
  find "$path" -depth -exec rm -rf {} + 2>/dev/null || true
  if [[ ! -e "$path" ]]; then
    return 0
  fi
  echo "WARNING: cannot fully remove: $path" >&2
  echo "  fix ownership: sudo chown -R \"\$(id -u):\$(id -g)\" \"$path\"" >&2
  echo "  or NTFS readonly:  attrib -R \"${path}\" /S   (Windows cmd)" >&2
  if [[ "$soft" == "1" ]]; then
    return 0
  fi
  return 1
}

# 同步目录内容：src/* → dest/
# 使用 dest.tmp 写入后 mv 原子切换，避免必须先删掉只读的旧 dest（WSL/NTFS 常见失败）
asapp_dep_sync_tree() {
  local src="$1"
  local dest="$2"
  local dest_tmp="${dest}.tmp.$$"
  local dest_old="${dest}.old.$$"

  echo "Sync $src -> $dest"
  if [[ ! -d "$src" ]]; then
    echo "ERROR: sync source missing: $src" >&2
    return 1
  fi

  asapp_dep_rm_rf "$dest_tmp" 1
  mkdir -p "$dest_tmp"
  cp -a "$src"/. "$dest_tmp"/

  if [[ -e "$dest" ]]; then
    # 同文件系统 rename，不碰内部只读文件
    if ! mv "$dest" "$dest_old"; then
      echo "ERROR: cannot rename $dest -> $dest_old (check permissions)" >&2
      asapp_dep_rm_rf "$dest_tmp" 1
      return 1
    fi
  fi
  if ! mv "$dest_tmp" "$dest"; then
    echo "ERROR: cannot rename $dest_tmp -> $dest" >&2
    # 尽量回滚
    if [[ -e "$dest_old" ]]; then
      mv "$dest_old" "$dest" 2>/dev/null || true
    fi
    return 1
  fi

  # 旧树清理失败不阻断本次 sync（留下 .old.$$ 供人工 chown 后删）
  if [[ -e "$dest_old" ]]; then
    asapp_dep_rm_rf "$dest_old" 1 || true
    if [[ -e "$dest_old" ]]; then
      echo "NOTE: left behind $dest_old — remove after: sudo chown -R \"\$(id -u):\$(id -g)\" \"$dest_old\" && rm -rf \"$dest_old\"" >&2
    fi
  fi
}

# 同步单个包目录：src → dest（dest 为最终包根，如 .../libcef）
asapp_dep_sync_dir() {
  local src="$1"
  local dest="$2"
  local parent dest_tmp dest_old
  parent="$(dirname "$dest")"
  dest_tmp="${dest}.tmp.$$"
  dest_old="${dest}.old.$$"

  echo "Sync $src -> $dest"
  if [[ ! -d "$src" ]]; then
    echo "ERROR: sync source missing: $src" >&2
    return 1
  fi
  mkdir -p "$parent"
  asapp_dep_rm_rf "$dest_tmp" 1
  cp -a "$src" "$dest_tmp"

  if [[ -e "$dest" ]]; then
    if ! mv "$dest" "$dest_old"; then
      echo "ERROR: cannot rename $dest -> $dest_old" >&2
      asapp_dep_rm_rf "$dest_tmp" 1
      return 1
    fi
  fi
  if ! mv "$dest_tmp" "$dest"; then
    echo "ERROR: cannot rename $dest_tmp -> $dest" >&2
    if [[ -e "$dest_old" ]]; then
      mv "$dest_old" "$dest" 2>/dev/null || true
    fi
    return 1
  fi
  if [[ -e "$dest_old" ]]; then
    asapp_dep_rm_rf "$dest_old" 1 || true
    if [[ -e "$dest_old" ]]; then
      echo "NOTE: left behind $dest_old — remove after chown" >&2
    fi
  fi
}
