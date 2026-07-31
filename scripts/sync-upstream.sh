#!/usr/bin/env bash
set -Eeuo pipefail

# 从上游仓库同步更新，同时保护当前分支上的提交和未提交改动。
# 默认同步 upstream/main；可通过 UPSTREAM_REMOTE / UPSTREAM_BRANCH 覆盖。

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

upstream_remote="${UPSTREAM_REMOTE:-upstream}"
upstream_branch="${UPSTREAM_BRANCH:-main}"
git rev-parse --show-toplevel >/dev/null 2>&1 || die '当前目录不是 Git 仓库。'
current_branch="$(git branch --show-current)"
stash_ref=""

[[ -n "$current_branch" ]] || die '当前处于 detached HEAD，请先切换到需要同步的分支。'

git remote get-url "$upstream_remote" >/dev/null 2>&1 \
  || die "找不到远程仓库 '$upstream_remote'。请先执行：git remote add $upstream_remote UPSTREAM_URL"

git_dir="$(git rev-parse --git-dir)"
for state_file in \
  "$git_dir/MERGE_HEAD" \
  "$git_dir/CHERRY_PICK_HEAD" \
  "$git_dir/REVERT_HEAD" \
  "$(git rev-parse --git-path rebase-merge)" \
  "$(git rev-parse --git-path rebase-apply)"; do
  [[ ! -e "$state_file" ]] || die "检测到未完成的 Git 操作：${state_file}。请先完成或中止该操作。"
done

restore_stash_on_exit() {
  local exit_code=$?
  trap - EXIT

  if [[ -n "$stash_ref" ]]; then
    if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
      printf '\n上游合并发生冲突，未自动恢复本地改动。临时 stash：%s\n' "$stash_ref" >&2
      printf '处理方式：先解决合并冲突并提交，或执行 git merge --abort；然后执行 git stash pop %s\n' "$stash_ref" >&2
    elif git stash pop --index "$stash_ref"; then
      info '已恢复同步前的本地改动。'
      stash_ref=""
    else
      printf '\n上游提交已合并，但恢复本地改动时发生冲突。临时 stash 仍保留：%s\n' "$stash_ref" >&2
      printf '请先处理工作区冲突，再按需执行 git stash drop %s。\n' "$stash_ref" >&2
      exit_code=1
    fi
  fi

  exit "$exit_code"
}
trap restore_stash_on_exit EXIT

info "获取 ${upstream_remote}/${upstream_branch} 的最新提交……"
git fetch --prune "$upstream_remote"
git show-ref --verify --quiet "refs/remotes/$upstream_remote/$upstream_branch" \
  || die "远程分支不存在：${upstream_remote}/${upstream_branch}"

if [[ -n "$(git status --porcelain=v1)" ]]; then
  stash_message="sync-upstream: ${current_branch} before ${upstream_remote}/${upstream_branch}"
  info '检测到未提交改动，先临时保存（包含未跟踪文件）……'
  git stash push --include-untracked --message "$stash_message"
  stash_ref="$(git stash list -1 --format='%gd')"
  [[ -n "$stash_ref" ]] || die '创建临时 stash 失败。'

  [[ -z "$(git status --porcelain=v1)" ]] \
    || die '临时保存后工作区仍不干净，已停止同步。'
fi

info "将 ${upstream_remote}/${upstream_branch} 合并到当前分支 ${current_branch}……"
git merge --no-edit "$upstream_remote/$upstream_branch"
info "上游更新已合并到 ${current_branch}。"
