import Foundation

struct ServicePreset: Identifiable {
    let id: String
    let name: String
    let systemIconName: String
    let cmdArgs: [String]
    let strategyDescription: String
    var isEnabled: Bool
}
