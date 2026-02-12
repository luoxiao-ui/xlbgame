# starMoon

`starMoon` 是一个原生 Android 应用，聚合了阅读、记账和估值三个场景。

## 功能概览

- 首页：卡片式入口与底部导航（首页 / 我的）
- 阅读时光：
  - 记录书籍历史（书名、作者、状态、日期）
  - 设置本周阅读目标
  - 保存读后看法
  - 本地持久化数据
- 智能记账：
  - 收入/支出记录
  - 每日输出与汇总统计
  - 目标攒钱预计达成时间
  - 本地持久化数据
- 有数估值：根据设备信息计算估值区间和建议
- 我的：
  - 关于我们
  - 版本更新页（显示当前版本与更新内容）

## 技术栈

- Kotlin
- Android XML 布局
- Material Components
- SharedPreferences（本地持久化）

## 目录结构

- `item-value-app/`：Android 工程目录
- `item-value-app/app/src/main/java/com/xlbgame/itemvalue/`：业务代码
- `item-value-app/app/src/main/res/`：布局、主题、资源文件

## 运行方式

1. 使用 Android Studio 打开 `item-value-app`
2. 等待 Gradle Sync 完成
3. 运行 `app` 模块到模拟器或真机

## Author

- Codex

