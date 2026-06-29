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

    // YouTube: множественный сплит на позициях TLS ClientHello.
    // ТСПУ читает SNI из ClientHello — разбиваем его на несколько TCP-сегментов.
    // Позиции 1+s,3+s,6+s,9+s = сплит до SNI + на нескольких точках внутри.
    static let youtube = ServicePreset(
        id: "youtube",
        name: "YouTube",
        systemIconName: "play.rectangle.fill",
        cmdArgs: ["-s", "1+s", "-s", "3+s", "-s", "6+s", "-s", "9+s"],
        strategyDescription: "Multi-split at TLS SNI offsets (TSPU bypass)",
        isEnabled: false
    )

    // TikTok: сплит в середине SNI
    static let tiktok = ServicePreset(
        id: "tiktok",
        name: "TikTok",
        systemIconName: "music.note",
        cmdArgs: ["-s", "0+sm"],
        strategyDescription: "Split at SNI midpoint",
        isEnabled: false
    )

    // Discord: сплит на позиции 3 (перед расширениями TLS)
    static let discord = ServicePreset(
        id: "discord",
        name: "Discord",
        systemIconName: "bubble.left.and.bubble.right.fill",
        cmdArgs: ["-s", "1+s", "-s", "3"],
        strategyDescription: "Split before TLS extensions",
        isEnabled: false
    )

    // Instagram: сплит на позиции 2
    static let instagram = ServicePreset(
        id: "instagram",
        name: "Instagram",
        systemIconName: "camera.fill",
        cmdArgs: ["-s", "2"],
        strategyDescription: "TCP Split at position 2",
        isEnabled: false
    )

    // Универсальный: агрессивный многопозиционный сплит, работает для большинства сервисов
    static let universal = ServicePreset(
        id: "universal",
        name: "Все сервисы",
        systemIconName: "globe",
        cmdArgs: ["-s", "0+sm", "-s", "1+s", "-s", "3+s", "-s", "6"],
        strategyDescription: "Universal multi-split (YouTube + others)",
        isEnabled: false
    )

    static var all: [ServicePreset] { [youtube, tiktok, discord, instagram, universal] }

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
