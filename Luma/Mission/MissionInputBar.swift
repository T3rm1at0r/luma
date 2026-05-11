import LumaCore
import SwiftUI

struct MissionInputBar: View {
    let engine: Engine
    let mission: Mission

    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextEditor(text: $draft)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .frame(minHeight: 36, maxHeight: 96)
                .focused($isFocused)

            sendControl
                .disabled(trimmedDraft.isEmpty)
        }
        .padding(8)
        .background(.thinMaterial)
    }

    @ViewBuilder
    private var sendControl: some View {
        if mission.status == .running {
            Menu {
                Button("Send & Interrupt") { send(interrupt: true) }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
            } label: {
                Text("Send")
            } primaryAction: {
                send(interrupt: false)
            }
            .keyboardShortcut(.return, modifiers: .command)
            .menuStyle(.button)
        } else {
            Button("Send") { send(interrupt: false) }
                .keyboardShortcut(.return, modifiers: .command)
        }
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send(interrupt: Bool) {
        let text = trimmedDraft
        guard !text.isEmpty else { return }
        if interrupt {
            engine.sendMissionUserMessageNow(missionID: mission.id, text: text)
        } else {
            engine.appendMissionUserMessage(missionID: mission.id, text: text)
        }
        draft = ""
        isFocused = true
    }
}
