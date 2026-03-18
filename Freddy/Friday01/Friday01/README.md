# Freddy 本地测试指南

## Step 1：创建 Xcode 项目

1. 打开 Xcode → New Project → iOS App
2. 名称：`Freddy`，Interface：SwiftUI，Language：Swift
3. 把 `Freddy/` 目录下所有 `.swift` 文件拖入项目对应目录
4. Target 选 iPad（iPadOS 16.0+）

## Step 2：填入真实 Token

编辑 `Config/OpenClawConfig.swift`：

```swift
static let token = "YOUR_GATEWAY_TOKEN_HERE"
// 替换为真实的 Bearer token
```

## Step 3：Info.plist 权限

在 Xcode 的 Info.plist 或 Info tab 中添加：

| Key | Value |
|-----|-------|
| NSMicrophoneUsageDescription | Freddy 需要使用麦克风进行语音识别。 |
| NSSpeechRecognitionUsageDescription | Freddy 需要语音识别功能。 |
| NSAppTransportSecurity → NSExceptionDomains → 100.118.204.105 → NSExceptionAllowsInsecureHTTPLoads | YES |

## Step 4：运行目标

- 优先使用**真机 iPad**（语音识别在模拟器上不稳定）
- 确保 iPad 能访问 100.118.204.105:59690

## Step 5：功能验证顺序

### 5.1 测试网络接口
点击「测试发送」按钮，观察：
- Xcode Console 打印原始 JSON
- 界面显示 AI 回复
- TTS 自动朗读

### 5.2 测试语音识别
点击「开始监听」，说一句话：
- 实时识别区域显示识别文字
- 说完自动发送、显示回复

### 5.3 常见问题

| 问题 | 排查 |
|------|------|
| 接口 timeout | 检查 iPad 能否访问服务器 IP；检查 ATS 配置 |
| 语音识别无输出 | 检查麦克风权限；使用真机测试 |
| TTS 无声音 | 检查 iPad 音量；检查静音键 |
| `noTextInResponse` | 看 Console 的原始 JSON，确认服务器返回格式 |

## 未来扩展

- [ ] 热词唤醒 "Hey Freddy"
- [ ] SSE 流式输出
- [ ] 多轮对话历史
- [ ] 后台常驻 + 后台语音监听
- [ ] Siri Intent 集成
