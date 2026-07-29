#!/usr/bin/env bash
# 供 scripts/*.sh source：增量跳过 + Clang/libstdc++ filesystem 探测
# shellcheck disable=SC2034

# 是否强制全量重编（--clean / ASAPP_DEP_CLEAN=1）
asapp_dep_want_clean() {
  [[ "${ASAPP_DEP_CLEAN:-0}" == "1" ]]
}

# 若 marker 文件已存在且未要求 clean，则打印 SKIP 并返回 0（调用方应 exit 0）
# 用法：asapp_dep_skip_if_ready <包名> <marker路径> && exit 0
asapp_dep_skip_if_ready() {
  local name="$1"
  local marker="$2"
  if asapp_dep_want_clean; then
    return 1
  fi
  if [[ -f "$marker" ]]; then
    echo "SKIP ${name} (already installed: ${marker})"
    echo "  rebuild: pass --clean  or  ASAPP_DEP_CLEAN=1"
    return 0
  fi
  return 1
}

# 探测本机可用的 GCC≥8 libstdc++ 目录（与 linux-clang.cmake 对齐）
# 输出：triple|ver  例如 x86_64-linux-gnu|8 ；找不到则空
asapp_dep_find_gcc8_plus() {
  local triple ver
  for triple in x86_64-linux-gnu aarch64-linux-gnu loongarch64-linux-gnu; do
    for ver in 13 12 11 10 9 8; do
      if [[ -d "/usr/lib/gcc/${triple}/${ver}" ]]; then
        echo "${triple}|${ver}"
        return 0
      fi
    done
  done
  return 1
}

# Clang 能否编译并链接 <filesystem>（gRPC/Abseil 需要）
# GCC 8 必须加 -lstdc++fs；仅 --gcc-toolchain 不够。
asapp_dep_clang_filesystem_ok() {
  if ! command -v clang++ >/dev/null 2>&1; then
    return 1
  fi
  local _fs_probe _fs_bin _fs_err found flags
  _fs_probe="$(mktemp -t asapp_fs_probe_XXXXXX.cpp)"
  _fs_bin="$(mktemp -t asapp_fs_probe_XXXXXX)"
  _fs_err="$(mktemp -t asapp_fs_probe_XXXXXX.err)"
  cat >"${_fs_probe}" <<'EOF'
#include <filesystem>
int main() { return std::filesystem::temp_directory_path().empty() ? 1 : 0; }
EOF

  found="$(asapp_dep_find_gcc8_plus || true)"
  flags=(-std=c++17)
  link_libs=()
  if [[ -n "${found}" ]]; then
    local triple="${found%%|*}"
    local ver="${found##*|}"
    flags+=(--gcc-toolchain=/usr "-B/usr/lib/gcc/${triple}/${ver}")
    # GCC 8：-lstdc++fs 必须在 .o/.cpp 之后，否则 undefined reference
    if [[ "${ver}" == "8" ]]; then
      link_libs+=(-lstdc++fs)
    fi
  fi

  if clang++ "${flags[@]}" -o "${_fs_bin}" "${_fs_probe}" "${link_libs[@]}" >"${_fs_err}" 2>&1; then
    rm -f "${_fs_probe}" "${_fs_bin}" "${_fs_err}"
    return 0
  fi

  # 再试显式 libstdc++（个别 LLVM 预编译包默认倾向 libc++）
  if clang++ "${flags[@]}" -stdlib=libstdc++ -o "${_fs_bin}" "${_fs_probe}" "${link_libs[@]}" >"${_fs_err}" 2>&1; then
    rm -f "${_fs_probe}" "${_fs_bin}" "${_fs_err}"
    return 0
  fi

  echo "---- filesystem probe stderr (tail) ----" >&2
  tail -n 20 "${_fs_err}" >&2 || true
  rm -f "${_fs_probe}" "${_fs_bin}" "${_fs_err}"
  return 1
}

asapp_dep_print_filesystem_help() {
  echo "ERROR: clang++ cannot compile/link #include <filesystem> (needed by gRPC/Abseil)." >&2
  echo "  Debian 10 / UOS 构建镜像：确认已装 g++-8，且探测带 -lstdc++fs（见 AsAppDepIncremental.sh）。" >&2
  echo "  裸机 Ubuntu 18.04：apt-get install -y g++-8" >&2
  echo "  正式路径：docs/DOCKER_LINUX_BUILD.md（debian:10 + g++-8）。" >&2
}
