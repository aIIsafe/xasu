import Foundation

enum PresetLibrary {

    // ── Пресеты ───────────────────────────────────────────────────────────────
    // cmdArgs — только DPI-evasion аргументы (без --ip/--port).
    // SBDConfig автоматически добавляет базовые аргументы и фильтрует
    // iOS-несовместимые флаги (--fake, --fake-sni, --disorder, --oob и т.д.)
    //
    // Безопасные для iOS флаги:
    //   -s N      — TCP split на позиции N
    //   -s N+s    — split на позиции N + смещение SNI
    //   -s N+h    — split на позиции N + смещение Host
    //   -s 0+sm   — split в середине SNI (наиболее эффективно)
    // Позиции ОБЯЗАНЫ идти по возрастанию при объединении.

    static let youtube = ServicePreset(
        id: "youtube",
        name: "YouTube",
        systemIconName: "play.rectangle.fill",
        cmdArgs: ["-s", "1+s"],
        strategyDescription: "Split at SNI offset +1",
        isEnabled: false
    )

    static let tiktok = ServicePreset(
        id: "tiktok",
        name: "TikTok",
        systemIconName: "music.note",
        cmdArgs: ["-s", "0+sm"],
        strategyDescription: "Split at SNI midpoint",
        isEnabled: false
    )

    static let discord = ServicePreset(
        id: "discord",
        name: "Discord",
        systemIconName: "bubble.left.and.bubble.right.fill",
        cmdArgs: ["-s", "3"],
        strategyDescription: "TCP Split at position 3",
        isEnabled: false
    )

    static let instagram = ServicePreset(
        id: "instagram",
        name: "Instagram",
        systemIconName: "camera.fill",
        cmdArgs: ["-s", "2"],
        strategyDescription: "TCP Split at position 2",
        isEnabled: false
    )

    static var all: [ServicePreset] { [youtube, tiktok, discord, instagram] }

    // ── Формирование аргументов ───────────────────────────────────────────────
    // Возвращает ТОЛЬКО DPI-evasion аргументы (без --ip/--port).
    // ByeDPIService передаёт их в SBDConfig, который добавляет базовые аргументы.
    static func buildDpiArgs(from presets: [ServicePreset]) -> [String] {
        let enabled = presets.filter(\.isEnabled)
        guard !enabled.isEmpty else { return [] }
        if enabled.count == 1 { return enabled[0].cmdArgs }

        // Объединяем: числовые позиции сортируем, позиции со спецификатором оставляем
        var numericPositions: [Int]    = []
        var specialPositions: [String] = []

        for preset in enabled {
            var i = 0
            while i < preset.cmdArgs.count {
                if preset.cmdArgs[i] == "-s", i + 1 < preset.cmdArgs.count {
                    let pos = preset.cmdArgs[i + 1]
                    if let n = Int(pos) {
                        if !numericPositions.contains(n) { numericPositions.append(n) }
                    } else {
                        if !specialPositions.contains(pos) { specialPositions.append(pos) }
                    }
                    i += 2
                } else {
                    i += 1
                }
            }
        }

        var result: [String] = []
        // Специальные позиции (0+sm, 1+s и т.д.) — перед числовыми
        for pos in specialPositions {
            result += ["-s", pos]
        }
        // Числовые — по возрастанию
        for n in numericPositions.sorted() {
            result += ["-s", String(n)]
        }
        return result
    }

    // Совместимость: старый buildArgs возвращает полные аргументы для логов
    static func buildArgs(from presets: [ServicePreset]) -> [String] {
        let dpi = buildDpiArgs(from: presets)
        guard !dpi.isEmpty else {
            return ["-i", "127.0.0.1", "-p", "10800"]
        }
        return ["-i", "127.0.0.1", "-p", "10800"] + dpi
    }
}
