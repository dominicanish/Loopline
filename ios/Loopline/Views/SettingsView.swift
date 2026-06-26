import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("colorSchemePref") private var schemePref = "light"
    @AppStorage("latencyMode") private var latencyMode = "balanced"
    @AppStorage("noiseSuppression") private var noiseSuppression = true
    @AppStorage("autoGain") private var autoGain = false
    @AppStorage("autoReconnect") private var autoReconnect = true
    @AppStorage("keepAudioBackground") private var keepAudioBackground = true

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                Form {
                    Section("Audio") {
                        LabeledContent("Codec", value: "PCM · lossless")
                        LabeledContent("Sample Rate", value: "\(model.sampleRate / 1000) kHz")
                        LabeledContent("Bit Depth", value: "\(model.bitDepth)-bit")
                    }

                    Section {
                        Picker("Latency mode", selection: $latencyMode) {
                            Text("Low").tag("low")
                            Text("Balanced").tag("balanced")
                            Text("Stable").tag("stable")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    } header: {
                        Text("Latency mode")
                    } footer: {
                        Text("Lower latency feels more responsive; higher settings add a little buffering for smoother audio.")
                    }

                    Section("Microphone") {
                        Toggle("Echo Cancellation", isOn: $model.echoCancellation).tint(Palette.outgoing)
                        Toggle("Noise Suppression", isOn: $noiseSuppression).tint(Palette.outgoing)
                        Toggle("Auto Gain", isOn: $autoGain).tint(Palette.outgoing)
                    } footer: {
                        Text(model.running ? "Some changes apply the next time you start a session." : " ")
                    }

                    Section("Connection") {
                        Toggle("Auto-Reconnect", isOn: $autoReconnect).tint(Palette.outgoing)
                        Toggle("Keep Audio in Background", isOn: $keepAudioBackground).tint(Palette.outgoing)
                    }

                    Section("Appearance") {
                        Picker("Appearance", selection: $schemePref) {
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                            Text("System").tag("system")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    Section {
                        EmptyView()
                    } footer: {
                        Text("Loopline \(appVersion) · made for USB audio bridging.")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(v)"
    }
}
