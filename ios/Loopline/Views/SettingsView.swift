import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("colorSchemePref") private var schemePref = "system"
    @AppStorage("latencyMode") private var latencyMode = "balanced"
    @AppStorage("autoReconnect") private var autoReconnect = true
    @AppStorage("keepAudioBackground") private var keepAudioBackground = true

    var body: some View {
        ZStack {
            WallBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    SectionHeader(text: "Audio")
                    GlassCard {
                        VStack(spacing: 0) {
                            valueRow("Codec", "PCM · lossless")
                            RowDivider()
                            valueRow("Sample Rate", "\(model.sampleRate / 1000) kHz")
                            RowDivider()
                            valueRow("Bit Depth", "\(model.bitDepth)-bit")
                        }
                    }
                    .padding(.horizontal, 16)

                    SectionHeader(text: "Latency mode")
                    Picker("Latency mode", selection: $latencyMode) {
                        Text("Low").tag("low")
                        Text("Balanced").tag("balanced")
                        Text("Stable").tag("stable")
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .padding(.horizontal, 16)
                    Text("Lower latency feels more responsive; higher settings add a little buffering for smoother audio.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .padding(.horizontal, 16).padding(.top, 8)

                    SectionHeader(text: "Audio mode")
                    Picker("Audio mode", selection: $model.audioMode) {
                        Text("Speaker").tag(AppModel.AudioMode.speaker)
                        Text("Calls").tag(AppModel.AudioMode.calls)
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .padding(.horizontal, 16)
                    Text(model.audioMode == .calls
                         ? "Calls: echo cancellation on, so the PC won't hear itself through the mic — best for two-way calls. Plays a bit quieter."
                         : "Speaker: loud, full-range playback for music and media. The mic may pick up the speaker, so switch to Calls for two-way calls.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .padding(.horizontal, 16).padding(.top, 8)

                    SectionHeader(text: "Connection")
                    GlassCard {
                        VStack(spacing: 0) {
                            toggleRow("Auto-Reconnect", isOn: $autoReconnect)
                            RowDivider()
                            toggleRow("Keep Audio in Background", isOn: $keepAudioBackground)
                        }
                    }
                    .padding(.horizontal, 16)

                    SectionHeader(text: "Appearance")
                    Picker("Appearance", selection: $schemePref) {
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .padding(.horizontal, 16)

                    Text("Loopline \(appVersion)")
                        .font(.system(size: 13)).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity).padding(.top, 26)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("Settings").font(.system(size: 34, weight: .bold))
            Spacer()
            ThemeToggleButton(schemePref: $schemePref)
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 17))
            Spacer()
            Text(value).font(.system(size: 17)).foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).frame(minHeight: 48)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 17))
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Palette.green)
        }
        .padding(.horizontal, 16).frame(minHeight: 48)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(v)"
    }
}
