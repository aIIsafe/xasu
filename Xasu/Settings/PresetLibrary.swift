import Foundation

enum PresetLibrary {

    // ── Пресеты ───────────────────────────────────────────────────────────────
    // iOS-совместимые флаги (без raw sockets):
    //   -s N          — TCP split на позиции N (работает в sandbox)
    //   --fake-sni X  — заменяет SNI в фейк-пакете (идёт после всех -s)
    //
    // НЕ используем: --disorder, --oob, --ttl — требуют raw sockets.
    // ВАЖНО: позиции -s должны идти строго по возрастанию!

    static let youtube = ServicePreset(
        id: "youtube",
        name: "YouTube",
        systemIconName: "play.rectangle.fill",
        cmdArgs: ["-s", "2", "--fake-sni", "www.google.com"],
        strategyDescription: "TCP Split + Fake SNI",
        isEnabled: false
    )

    static let tiktok = ServicePreset(
        id: "tiktok",
        name: "TikTok",
        systemIconName: "music.note",
        cmdArgs: ["-s", "5", "--fake-sni", "cloudflare.com"],
        strategyDescription: "TCP Split + Fake SNI",
        isEnabled: false
    )

    static let discord = ServicePreset(
        id: "discord",
        name: "Discord",
        systemIconName: "bubble.left.and.bubble.right.fill",
        cmdArgs: ["-s", "3"],
        strategyDescription: "TCP Split",
        isEnabled: false
    )

    static let instagram = ServicePreset(
        id: "instagram",
        name: "Instagram",
        systemIconName: "camera.fill",
        cmdArgs: ["-s", "4"],
        strategyDescription: "TCP Split",
        isEnabled: false
    )

    static var all: [ServicePreset] {
        [youtube, tiktok, discord, instagram]
    }

    // ── Базовые аргументы ─────────────────────────────────────────────────────
    static let baseArgs: [String] = [
        "--ip", "127.0.0.1",
        "--port", "10800"
    ]

    // ── Умное объединение пресетов ────────────────────────────────────────────
    // КРИТИЧНО: byedpi требует позиции -s строго по возрастанию.
    // --fake-sni должен идти ПОСЛЕ всех -s флагов.
    static func buildArgs(from presets: [ServicePreset]) -> [String] {
        let enabled = presets.filter(\.isEnabled)
        guard !enabled.isEmpty else { return baseArgs }
        if enabled.count == 1 { return baseArgs + enabled[0].cmdArgs }

        var splitPositions: [Int] = []
        var fakeSni: String? = nil

        for preset in enabled {
            var i = 0
            let cmdArgs = preset.cmdArgs
            while i < cmdArgs.count {
                if cmdArgs[i] == "-s", i + 1 < cmdArgs.count {
                    if let pos = Int(cmdArgs[i + 1]),
                       !splitPositions.contains(pos) {
                        splitPositions.append(pos)
                    }
                    i += 2
                } else if cmdArgs[i] == "--fake-sni", i + 1 < cmdArgs.count {
                    if fakeSni == nil { fakeSni = cmdArgs[i + 1] }
                    i += 2
                } else {
                    i += 1
                }
            }
        }

        // Сортируем позиции по возрастанию — ОБЯЗАТЕЛЬНОЕ требование byedpi
        var result = baseArgs
        for pos in splitPositions.sorted() {
            result += ["-s", String(pos)]
        }
        // --fake-sni всегда в конце
        if let sni = fakeSni {
            result += ["--fake-sni", sni]
        }
        return result
    }
}
