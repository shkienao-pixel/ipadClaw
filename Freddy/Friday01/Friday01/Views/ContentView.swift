import SwiftUI

struct ContentView: View {

    @StateObject private var vm = FreddyViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── 标题 ──────────────────────────────────
                Text("Freddy")
                    .font(.system(size: 52, weight: .bold, design: .rounded))

                // ── 状态指示 ──────────────────────────────
                StatusBadge(state: vm.appState)

                Divider()

                // ── 实时识别文本 ─────────────────────────
                Group {
                    SectionLabel(title: "实时识别", icon: "waveform")
                    Text(vm.partialText.isEmpty ? "…" : vm.partialText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // ── 最后一条用户消息 ──────────────────────
                Group {
                    SectionLabel(title: "你说", icon: "person.fill")
                    Text(vm.lastUserMessage.isEmpty ? "（暂无）" : vm.lastUserMessage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1))
                }

                // ── AI 回复 ───────────────────────────────
                Group {
                    SectionLabel(title: "Freddy 回复", icon: "cpu")
                    Text(vm.lastAIReply.isEmpty ? "（暂无）" : vm.lastAIReply)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.green.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1))
                }

                Divider()

                // ── 操作按钮 ──────────────────────────────
                HStack(spacing: 14) {

                    Button(action: vm.toggleListening) {
                        Label(
                            vm.appState == .listening ? "停止监听" : "开始监听",
                            systemImage: vm.appState == .listening
                                ? "stop.circle.fill" : "mic.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(vm.appState == .listening ? Color.red : Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(listenButtonDisabled)

                    Button(action: vm.sendTestMessage) {
                        Label("测试发送", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(testButtonDisabled)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: 640)           // iPad 上居中限宽
        .frame(maxWidth: .infinity)
    }

    private var listenButtonDisabled: Bool {
        vm.appState == .sending || vm.appState == .speaking
    }

    private var testButtonDisabled: Bool {
        vm.appState == .sending || vm.appState == .listening
    }
}

// MARK: - 状态徽章

private struct StatusBadge: View {
    let state: AppState

    private var isAnimating: Bool {
        state == .listening || state == .sending
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)

            Text(state.displayText)
                .font(.subheadline)
                .foregroundStyle(state.isError ? .red : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    private var dotColor: Color {
        switch state {
        case .idle:      return .gray
        case .listening: return .red
        case .sending:   return .orange
        case .speaking:  return .green
        case .error:     return .red
        }
    }
}

// MARK: - 小节标签

private struct SectionLabel: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
}
