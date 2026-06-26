import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    private var connected: Bool { model.status == .connected }

    var body: some View {
        ZStack {
            BackdropView()

            VStack(spacing: 0) {
                header

                Spacer(minLength: 8)

                ConnectionOrb(connected: connected,
                              level: max(model.micLevel, model.speakerLevel),
                              latencyMs: model.latencyMs,
                              peerName: model.peerName)

                Spacer(minLength: 8)

                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            RouteTile(title: "Micrófono",
                                      systemImage: "mic.fill",
                                      tint: Brand.mic,
                                      isOn: $model.micEnabled,
                                      level: model.micLevel,
                                      enabled: model.running)
                            RouteTile(title: "Altavoz",
                                      systemImage: "speaker.wave.3.fill",
                                      tint: Brand.speaker,
                                      isOn: $model.speakerEnabled,
                                      level: model.speakerLevel,
                                      enabled: model.running)
                        }
                        primaryButton
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Loopline")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("iPhone como mic y altavoz")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            StatusPill(connected: connected,
                       text: connected ? "Conectado" : "Esperando PC")
        }
    }

    private var primaryButton: some View {
        Button {
            if model.running { model.stop() } else { model.start() }
        } label: {
            HStack {
                Image(systemName: model.running ? "stop.fill" : "play.fill")
                Text(model.running ? "Detener" : "Iniciar Loopline")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(model.running ? .red.opacity(0.6) : Brand.blue)
        .controlSize(.large)
    }
}

#Preview {
    ContentView().environmentObject(AppModel())
}
