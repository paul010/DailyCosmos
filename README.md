# DailyCosmos · iOS App 开发 101

这是大雷的 iOS App 开发 101 学习项目，用来实践 SwiftUI、数据持久化以及本地通知等基础技能。项目目标是构建一个简单的待办事项应用，并在后续迭代中尝试接入 AI 帮助快速创建任务。

## 已完成内容（Step 1）
- 使用 SwiftUI 搭建基础界面，展示待办事项列表。
- 支持新增、完成状态切换、滑动删除等操作。
- 待办数据以 JSON 的形式持久化到 `Documents/Notes/todo.json`。
- 可选设置提醒时间，并通过 `UserNotifications` 安排本地通知。

## 即将实现（Step 2）
- 接入 Google Gemini 2.5 Flash API，通过自然语言快速创建待办事项。
- 自动从 AI 返回的 JSON 提取标题和时间，继续沿用现有的存储与提醒逻辑。

## 运行要求
1. Xcode 16 或更高版本，目标平台 iOS 18。
2. 首次运行请在 `Info.plist` 中补充 `NSUserNotificationsUsageDescription`，否则无法弹出通知授权。
3. 如果需要体验 Step 2，请先在 Google AI Studio 申请 API Key，并替换 `TodoViewModel` 中的占位串（当前代码尚未接入）。

## 快速开始
```bash
open DailyCosmos.xcodeproj
```
选择 `DailyCosmos` scheme，在模拟器或真机上运行即可。

## 目录结构
```
DailyCosmos/
├── DailyCosmos/               # App 源码
│   ├── ContentView.swift      # SwiftUI 主界面
│   ├── DailyCosmosApp.swift   # App 入口
│   ├── TodoItem.swift         # 待办数据模型
│   └── TodoViewModel.swift    # 视图模型，负责数据与通知
└── README.md
```

欢迎继续完善项目，逐步完成 101 学习路线。
