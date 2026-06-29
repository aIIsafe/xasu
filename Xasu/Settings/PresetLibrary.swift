import Foundation

enum PresetLibrary {

    // ── Пресеты ───────────────────────────────────────────────────────────────
    // Используем только iOS-совместимые флаги:
    //   -s N          — разбить TLS ClientHello на позиции N (TCP split, работает в sandbox)
    //   --fake-sni X  — подставить фейковый SNI в первый фрагмент
    //   --tlsrec N    — разбить TLS-запись (работает без raw sockets)
    //
    // НЕ используем: --disorder, --oob, --ttl — требуют raw sockets, недоступны на iOS.

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
    // Дедублирует позиции split и берёт только один fake-sni.
    static func buildArgs(from presets: [ServicePreset]) -> [String] {
        let enabled = presets.filter(\.isEnabled)
        guard !enabled.isEmpty else { return baseArgs }
        if enabled.count == 1 { return baseArgs + enabled[0].cmdArgs }

        var result = baseArgs
        var usedPositions = Set<String>()
        var addedSni = false

        for preset in enabled {
            var i = 0
            let cmdArgs = preset.cmdArgs
            while i < cmdArgs.count {
                if cmdArgs[i] == "-s", i + 1 < cmdArgs.count {
                    let pos = cmdArgs[i + 1]
                    if usedPositions.insert(pos).inserted {
                        result += ["-s", pos]
                    }
                    i += 2
                } else if cmdArgs[i] == "--fake-sni", i + 1 < cmdArgs.count {
                    if !addedSni {
                        result += ["--fake-sni", cmdArgs[i + 1]]
                        addedSni = true
                    }
                    i += 2
                } else {
                    i += 1
                }
            }
        }
        return result
    }
}
