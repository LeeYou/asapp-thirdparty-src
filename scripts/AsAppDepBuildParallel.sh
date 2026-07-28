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
