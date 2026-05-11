import LumaCore
import SwiftUI

#if os(macOS)
import AppKit
#endif

struct ExternalMCPSection: View {
    let engine: Engine

    @State private var isToggling = false
    @State private var lastError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "network")
                    .foregroundStyle(.tint)
                Text("External MCP Server").font(.headline)
                Spacer()
                if engine.isExternalMCPRunning {
                    Button("Disable") {
                        Task { await disable() }
                    }
                    .disabled(isToggling)
                } else {
                    Button("Enable") {
                        Task { await enable() }
                    }
                    .disabled(isToggling)
                    .buttonStyle(.borderedProminent)
                }
            }

            if let url = engine.externalMCPURL,
                let token = engine.externalMCPServer?.bearerToken
            {
                runningBody(url: url, token: token)
            } else {
                Text("Run Frida tools from Claude Code or any MCP-aware client.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func runningBody(url: URL, token: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            row(label: "URL", value: url.absoluteString)
            row(label: "Bearer token", value: token.prefix(12) + "…")
            HStack(spacing: 8) {
                Button("Copy `claude mcp add` command") {
                    copy(claudeMcpAddCommand(url: url, token: token))
                }
                Button("Copy MCP config JSON") {
                    copy(mcpConfigJSON(url: url, token: token))
                }
                Button("Rotate token") {
                    Task { await rotate() }
                }
                .disabled(isToggling)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .font(.caption.monospaced())
    }

    private func row(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(label):").foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    private func enable() async {
        isToggling = true
        defer { isToggling = false }
        do {
            _ = try await engine.enableExternalMCPServer()
            lastError = nil
        } catch {
            lastError = "could not enable: \(error.localizedDescription)"
        }
    }

    private func disable() async {
        isToggling = true
        defer { isToggling = false }
        await engine.disableExternalMCPServer()
        lastError = nil
    }

    private func rotate() async {
        isToggling = true
        defer { isToggling = false }
        do {
            _ = try await engine.rotateExternalMCPToken()
            lastError = nil
        } catch {
            lastError = "could not rotate: \(error.localizedDescription)"
        }
    }

    private func claudeMcpAddCommand(url: URL, token: String) -> String {
        "claude mcp add --transport http luma '\(url.absoluteString)' --header 'Authorization: Bearer \(token)'"
    }

    private func mcpConfigJSON(url: URL, token: String) -> String {
        let payload: [String: Any] = [
            "mcpServers": [
                "luma": [
                    "type": "http",
                    "url": url.absoluteString,
                    "headers": ["Authorization": "Bearer \(token)"],
                ],
            ],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])) ?? Data("{}".utf8)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
