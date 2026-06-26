import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("colorSchemePref") private var schemePref = "system"

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
                    Picker("Latency mode", selection: $model.latencyMode) {
                        Text("Low").tag("low")
                        Text("Balanced").tag("balanced")
                        Text("Stable").tag("stable")
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .padding(.horizontal, 16)
                    Text("Lower = more responsive but more prone to dropouts; higher buffers more for smoother audio. Applies instantly, even mid-session.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .padding(.horizontal, 16).padding(.top, 8)

                    SectionHeader(text: "Connection")
                    GlassCard {
                        VStack(spacing: 0) {
                            toggleRow("Auto-Reconnect", isOn: $model.autoReconnect)
                            RowDivider()
                            toggleRow("Keep Audio in Background", isOn: $model.keepAudioBackground)
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
