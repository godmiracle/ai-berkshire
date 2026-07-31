# 与上游仓库同步

本仓库可以把原作者仓库作为 `upstream`，把自己的 GitHub 仓库作为
`origin`。同步时使用 merge，既保留自己的提交，也不会改写已经推送到
`origin` 的历史。

## 一次性检查远程仓库

```bash
git remote -v
```

如果还没有 `upstream`，执行：

```bash
git remote add upstream UPSTREAM_URL
```

如果是从自己的 fork 克隆的，通常应保持以下关系：

```text
origin   -> 自己的 fork
upstream -> 原作者仓库
```

## 本地报告目录

需要在多台设备之间同步的个人研究报告统一放在根目录 `localReports/`。
该目录会提交到自己的 `origin`，公开报告仍放在 `reports/`。

提交并推送本地报告：

```bash
git add localReports/
git commit -m "同步本地研究报告"
git push origin main
```

在另一台设备上同步：

```bash
git pull --rebase origin main
```

注意：当前 `origin` 指向自己的 GitHub 仓库，`upstream` 才是原作者仓库。
不要把 `localReports/` 推送到 `upstream`。

## 一键同步

在仓库根目录执行：

```bash
./scripts/sync-upstream.sh
```

脚本会依次：

1. 获取 `upstream/main` 的最新提交；
2. 把未提交的修改和未跟踪文件临时放入 stash；
3. 将 `upstream/main` merge 到当前分支；
4. 自动恢复同步前的本地改动。

默认不会自动 push，便于先检查合并结果。确认无误后再执行：

```bash
git status
git log --oneline --graph --decorate -n 12
git push origin main
```

## 自定义远程或分支

```bash
UPSTREAM_REMOTE=upstream UPSTREAM_BRANCH=main ./scripts/sync-upstream.sh
```

## 冲突处理

如果上游更新和本地修改改到了同一处，脚本会停止在冲突现场，并保留
同步前的临时 stash。先处理并提交 merge 冲突，或者执行：

```bash
git merge --abort
git stash pop stash@{0}
```

再根据 `git status` 继续处理即可。不要在尚未查看冲突内容时使用
`git reset --hard`。
