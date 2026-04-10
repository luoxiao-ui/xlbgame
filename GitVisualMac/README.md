# GitVisualMac

一个 macOS 原生 Git 可视化桌面工具（MVP），用于提供类似 IDE Git 面板的核心能力。

## 已实现功能

- 选择本地 Git 仓库
- 查看提交图（`git log --graph --decorate --oneline --all`）
- 查看分支并切换分支
- 新建分支
- 查看文件状态（staged / unstaged / untracked）
- 查看选中文件 Diff
- Stage / Unstage
- Commit
- Fetch / Pull / Push

## 运行方式

```bash
cd GitVisualMac
swift run
```

> 需要 macOS 13+ 与 Swift 5.9+

## 说明

这是第一版可用 MVP，重点放在 Git 操作闭环和可视化信息呈现。
下一步可继续补充提交详情面板、文件树、冲突处理、stash/cherry-pick/rebase UI 等。
