import Foundation

enum PresetLibrary {

    static let youtube = ServicePreset(
        id: "youtube",
        name: "YouTube",
        systemIconName: "play.rectangle.fill",
        cmdArgs: ["-s", "1", "--disorder", "1", "--fake-sni", "www.google.com"],
        strategyDescription: "TCP Split + Disorder",
        isEnabled: false
    )

    static let tiktok = ServicePreset(
        id: "tiktok",
        name: "TikTok",
        systemIconName: "music.note",
        cmdArgs: ["-s", "3", "--ttl", "5", "--fake-sni", "cloudflare.com"],
        strategyDescription: "TTL + Fake SNI",
        isEnabled: false
    )

    static let discord = ServicePreset(
        id: "discord",
        name: "Discord",
        systemIconName: "bubble.left.and.bubble.right.fill",
        cmdArgs: ["-s", "1", "--oob", "1"],
        strategyDescription: "TCP Split + OOB",
        isEnabled: false
    )

    static let instagram = ServicePreset(
        id: "instagram",
        name: "Instagram",
        systemIconName: "camera.fill",
        cmdArgs: ["-s", "2", "--disorder", "1"],
        strategyDescription: "TCP Split",
        isEnabled: false
    )

    static var all: [ServicePreset] {
        [youtube, tiktok, discord, instagram]
    }

    /// Базовые аргументы byedpi, всегда присутствуют
    static let baseArgs: [String] = [
        "--ip", "127.0.0.1",
        "--port", "10800"
    ]

    /// Собирает финальный список аргументов из включённых пресетов
    static func buildArgs(from presets: [ServicePreset]) -> [String] {
        let enabled = presets.filter(\.isEnabled)
        guard !enabled.isEmpty else { return baseArgs }
        let combined = enabled.flatMap(\.cmdArgs)
        return baseArgs + combined
    }
}
