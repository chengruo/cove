# Cove (macOS Menu Bar Notch Overflow Manager)

[![CI & Build](https://github.com/chengruo/cove/actions/workflows/ci.yml/badge.svg)](https://github.com/chengruo/cove/actions/workflows/ci.yml)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014.0%2B-blue.svg)](https://apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B%20%7C%206.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Cove** 是一个纯原生 macOS Swift 应用，专为解决 MacBook 屏幕刘海（Notch）导致顶部 Menu Bar 状态栏图标被遮挡、无法查看和点击的问题而设计。

<p align="center">
  <img src="https://raw.githubusercontent.com/chengruo/cove/main/Assets/preview.png" alt="Cove Preview" width="480" onerror="this.style.display='none'"/>
</p>

---

## ⚡ 快速安装 (Quick Install)

只需在终端中执行以下一键安装命令即可自动完成构建、代码签名与安装到 `/Applications`：

```bash
curl -fsSL https://raw.githubusercontent.com/chengruo/cove/main/install.sh | bash
```

> **提示**：安装完成后 Cove 会自动启动。请在弹出的系统设置中为 Cove 开启 **辅助功能（Accessibility）** 权限。

---

## 🌟 核心特性

1. **纯原生现代架构**：使用 Swift、AppKit、SwiftUI、Accessibility API (`AXUIElement`)、CoreGraphics 与 `NSScreen` 官方框架构建，无 Electron、无 WebView、无第三方依赖。
2. **深度解析现代 macOS 状态栏**：不仅读取 WindowServer Layer 25 窗口，更能递归解析每个第三方应用的 `AXExtrasMenuBar` 与系统的 `AXMenuBar`，准确还原真实应用名称与高分辨率图标。
3. **全局快捷键防刘海遮挡**：支持全局热键 **`⌃⌥C`** (`Control + Option + C`)。即使 Cove 自身图标也被刘海遮挡，面板也会智能吸附在**屏幕刘海正中下方**展开！
4. **固定至输入法旁（防被挤入刘海）**：内置 `autosaveName` 和 `NSStatusItem Preferred Position` 偏好注入，开箱即自动紧贴输入法与控制中心。用户亦可按住 **`⌘ (Command)`** 随意拖拽排序并由系统永久记住。
5. **支持开机自启动（Launch at Login）**：采用 Apple 现代官方 `ServiceManagement.SMAppService.mainApp` API，与系统设置“登录项”完全联动，可在状态栏右键菜单或主面板设置中一键开启。
6. **真实触发原始状态项动作**：在浮动面板中点击项目，通过 `AXUIElementPerformAction` 触发 `kAXPressAction`，直接唤起目标应用的原生菜单或窗口，并具备坐标备用模拟兜底。
7. **macOS 原生毛玻璃交互**：完全符合 macOS HIG 规范，采用原生 Popover 材质、语义化配色与精致的 Hover 微动效，自动适配浅色与深色模式。
8. **极低系统资源占用**：基于事件监听（屏幕参数、应用切换、系统休眠唤醒）配合轻量防抖定时刷新，Idle 状态下 CPU 占用接近 0%，内存低于 50MB。

---

## 🕹️ 使用指南

| 动作 | 操作方式 | 说明 |
| :--- | :--- | :--- |
| **展开 / 折叠面板** | 鼠标左键点击 Cove 状态栏图标 或 按下快捷键 **`⌃⌥C`** | 快速查看被刘海遮挡的应用 |
| **触发应用菜单** | 在面板列表中点击任意应用项目 | 自动触发该应用原生菜单或弹窗 |
| **重置位置到最右侧** | 鼠标右键点击图标 -> 选择 **Move Next to Input Method (移至输入法旁)** | 自动移至紧挨输入法的黄金位置 |
| **手动自定义排序** | 键盘按住 **`⌘ (Command)`** 键，鼠标拖动图标 | macOS 会自动永久记忆排序 |
| **开机自启开关** | 右键点击图标勾选 **Launch at Login (开机自启)** 或在面板右上角 `⋯` 切换 | 系统级开机自动常驻 |

---

## 🏗️ 架构设计

```text
Cove
├── App
│   ├── CoveApp.swift                  # 程序入口 (@main, .accessory 模式)
│   ├── AppDelegate.swift              # 生命周期与系统事件通知管理
│   ├── LaunchAtLoginManager.swift     # 现代 SMAppService 开机自启服务管理
│   └── Logger.swift                   # 统一 OSLog 结构化日志系统
│
├── Models
│   ├── MenuBarItem.swift              # 状态项模型与动作触发状态
│   └── ScreenGeometry.swift           # 屏幕几何、刘海与安全区域模型
│
├── Detection
│   ├── NotchDetector.swift            # 屏幕刘海几何计算器 (NSScreen)
│   └── OverflowDetector.swift         # 遮挡与可见性几何判定器
│
├── Scanner
│   ├── MenuBarScanner.swift           # 综合状态项扫描器 (AXExtrasMenuBar + Layer 25)
│   ├── WindowServerScanner.swift      # 状态窗口扫描器 (CGWindowList layer 25)
│   └── AXHelper.swift                 # Accessibility 安全操作与属性提取工具集
│
├── Accessibility
│   └── AccessibilityManager.swift     # 权限检测、AX 动作执行与模拟点击兜底
│
├── Controllers
│   ├── MenuBarController.swift        # NSStatusItem 与右键快捷菜单管理
│   ├── StatusPanelController.swift    # 原生毛玻璃 NSPanel 悬浮面板控制器
│   └── HotKeyManager.swift            # Carbon 全局热键 (⌃⌥C) 调度器
│
└── Views
    ├── OverflowPanel.swift            # 核心 SwiftUI 浮动面板视图
    ├── MenuBarItemView.swift          # 单项视图 (原生高亮与动作反馈)
    ├── EmptyStateView.swift           # 无遮挡时的原生空状态视图
    ├── PermissionView.swift           # 辅助功能权限引导视图
    └── DebugView.swift                # 屏幕与项目几何信息调试面板
```

---

## 🛠️ 本地编译与打包

### 依赖环境
- macOS 14.0 (Sonoma) 或更高版本
- Xcode 15.0+ 或 Xcode Command Line Tools (`swift --version` >= 5.9)

### 编译为独立 `.app` 包
```bash
git clone https://github.com/chengruo/cove.git
cd cove
./Scripts/build_app.sh
```
编译产物位于 `build/Cove.app`，打包脚本已包含固定标识签名（Designated Requirement），重构编译不会破坏系统的 TCC 辅助功能授权记录。

---

## 🧪 自动化测试验证

运行内置验证测试：
```bash
swift build
./.build/debug/verification_test
```

---

## 📄 开源许可证

本项目采用 [MIT License](LICENSE) 授权。
