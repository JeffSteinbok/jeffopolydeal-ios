import Foundation

// Mirrors src/JeffopolyDeal.Shared/Models/GameConfig.cs (rendering-relevant subset).
// In the real app this comes from the server over SignalR/REST (GameConfigData) so a
// new theme's rent table changes the card faces with no app rebuild.

enum GameConfig {
    static let setSize: [PropertyColor: Int] = [
        .brown: 2, .lightBlue: 3, .pink: 3, .orange: 3, .red: 3,
        .yellow: 3, .green: 3, .darkBlue: 2, .railroad: 4, .utility: 2,
    ]

    static let rentTable: [PropertyColor: [Int]] = [
        .brown:     [0, 1, 2],
        .lightBlue: [0, 1, 2, 3],
        .pink:      [0, 1, 2, 4],
        .orange:    [0, 1, 3, 5],
        .red:       [0, 2, 3, 6],
        .yellow:    [0, 2, 4, 6],
        .green:     [0, 2, 4, 7],
        .darkBlue:  [0, 3, 8],
        .railroad:  [0, 1, 2, 3, 4],
        .utility:   [0, 1, 2],
    ]
}
