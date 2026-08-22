import SwiftUI

/// Mirrors src/web/pages/startPage/StartPage.tsx.
struct StartView: View {
    let onJoinGame: (_ gameCode: String, _ playerName: String) -> Void

    private enum Mode: Equatable { case menu, create, join }

    @State private var mode: Mode = .menu
    @State private var playerName: String = ""
    @State private var gameCode: String = ""
    @State private var showAbout: Bool = false
    @FocusState private var fieldFocused: Bool
    @StateObject private var nearby = NearbyGamesService()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image("TitleImage")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320)

                switch mode {
                case .menu: menuButtons
                case .create: createForm
                case .join: joinForm
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Button("About Jeffopoly Deal") { showAbout = true }
                .font(.footnote)
                .padding(.bottom, 4)

            VStack(spacing: 2) {
                Text("© \(currentYear) Jeff Steinbok. All rights reserved.")
                Text("Monopoly Deal is a trademark of Hasbro, Inc.")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.bottom, 16)
        }
        .appBackground()
        .sheet(isPresented: $showAbout) { AboutSheet() }
        .onAppear {
            if playerName.isEmpty, let name = DeviceName.guessMyName() {
                playerName = name
            }
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .join {
                nearby.startBrowsing()
            } else {
                nearby.stopBrowsing()
            }
        }
    }

    private var currentYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }

    private var menuButtons: some View {
        VStack(spacing: 12) {
            Button("Create Game") { mode = .create }
                .buttonStyle(.borderedProminent)
            Button("Join Game") { mode = .join }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }

    private var createForm: some View {
        VStack(spacing: 12) {
            TextField("Your Name", text: $playerName)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onAppear { fieldFocused = true }
                .onSubmit(handleCreate)
                .textInputAutocapitalization(.words)

            Button("Create Game", action: handleCreate)
                .buttonStyle(.borderedProminent)
                .disabled(playerName.trimmed.isEmpty)

            Button("Back") { mode = .menu }
                .buttonStyle(.bordered)
        }
    }

    private var joinForm: some View {
        VStack(spacing: 12) {
            TextField("Your Name", text: $playerName)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onAppear { fieldFocused = true }
                .textInputAutocapitalization(.words)

            TextField("Game Code", text: $gameCode)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: gameCode) { _, newValue in
                    let upper = String(newValue.uppercased().prefix(4))
                    if upper != gameCode { gameCode = upper }
                }
                .onSubmit(handleJoin)

            Button("Join Game", action: handleJoin)
                .buttonStyle(.borderedProminent)
                .disabled(playerName.trimmed.isEmpty || gameCode.trimmed.isEmpty)

            if !nearby.nearbyGames.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nearby Games").font(.caption).foregroundStyle(.secondary)
                    ForEach(nearby.nearbyGames) { game in
                        Button {
                            gameCode = game.gameCode
                        } label: {
                            HStack {
                                Text("\(game.hostName)'s Game")
                                Spacer()
                                Text(game.gameCode).font(.system(.body, design: .monospaced).bold())
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 4)
            }

            Button("Back") { mode = .menu }
                .buttonStyle(.bordered)
        }
    }

    private func handleCreate() {
        let name = playerName.trimmed
        guard !name.isEmpty else { return }
        onJoinGame("", name) // empty game code signals "create a new game"
    }

    private func handleJoin() {
        let name = playerName.trimmed
        let code = gameCode.trimmed.uppercased()
        guard !name.isEmpty, !code.isEmpty else { return }
        onJoinGame(code, name)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Text("Jeffopoly Deal is a real-time multiplayer take on the Monopoly Deal card game, built by Jeff Steinbok.")
                Link("View on GitHub", destination: URL(string: "https://github.com/JeffSteinbok/jeffopolydeal-ios")!)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    StartView(onJoinGame: { _, _ in })
}
