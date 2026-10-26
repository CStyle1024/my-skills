#!/usr/bin/env bash
# 核验文档中的 [VERIFY: 相对路径:行号] 标签，逐条确认引用的文件与行号真实存在。
set -u

doc="${1:-}"
root="${2:-.}"

if [ -z "$doc" ] || [ ! -f "$doc" ]; then
  echo "用法: scripts/verify_refs.sh <文档路径> [代码库根目录]"
  exit 2
fi
if [ ! -d "$root" ]; then
  echo "代码库根目录不存在: $root"
  exit 2
fi

total=0
fail=0
declare -A linecount

while IFS=$'\t' read -r dline tag; do
  total=$((total + 1))

  body="${tag#\[VERIFY:}"
  body="${body%]}"
  body="${body#"${body%%[![:space:]]*}"}"
  body="${body%"${body##*[![:space:]]}"}"

  if [ -z "$body" ] || [[ "$body" != *:* ]]; then
    fail=$((fail + 1))
    echo "FAIL 文档第 $dline 行: 标签缺少行号 -> $tag"
    continue
  fi

  path="${body%:*}"
  num="${body##*:}"

  if [[ ! "$num" =~ ^[0-9]+$ ]]; then
    fail=$((fail + 1))
    echo "FAIL 文档第 $dline 行: 行号需为单个整数，不支持区间或列表 -> $tag"
    continue
  fi

  if [[ "$path" = /* ]]; then
    file="$path"
  else
    file="$root/$path"
  fi

  if [ ! -f "$file" ]; then
    fail=$((fail + 1))
    echo "FAIL 文档第 $dline 行: 文件不存在 -> $path"
    continue
  fi

  if [ -z "${linecount[$file]:-}" ]; then
    linecount[$file]="$(awk 'END{print NR}' "$file")"
  fi

  if [ "$num" -gt "${linecount[$file]}" ]; then
    fail=$((fail + 1))
    echo "FAIL 文档第 $dline 行: 行号 $num 超出范围，$path 共 ${linecount[$file]} 行"
  fi
done < <(grep -n -oE '\[VERIFY:[^]]*\]' "$doc" | sed -E 's/^([0-9]+):/\1\t/')

fullwidth=$(grep -oE '\[VERIFY：[^]]*\]' "$doc" | wc -l)
if [ "$fullwidth" -gt 0 ]; then
  total=$((total + fullwidth))
  fail=$((fail + fullwidth))
  echo "有 $fullwidth 条标签写成全角冒号，脚本只识别半角 [VERIFY: ]，请改写："
  grep -n -oE '\[VERIFY：[^]]*\]' "$doc"
fi

if [ "$total" -eq 0 ]; then
  echo "警告: 文档中没有 [VERIFY:] 标签，无法核验"
  exit 1
fi

if [ "$fail" -eq 0 ]; then
  echo "共 $total 条标签，全部通过"
  exit 0
fi

echo "共 $total 条标签，$fail 条未通过，删除或修正这些条目后重新运行"
exit 1
