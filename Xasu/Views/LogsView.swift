import SwiftUI

struct LogsView: View {

    @Environment(\.dismiss) private var dismiss
    private let logger = AppLogger.shared
    @State private var showShareSheet = false
    @State private var exportText = ""
    @State private var autoScroll = true

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 0) {

                // ── Шапка ────────────────────────────────────────────
                headerBar

                // ── Логи ─────────────────────────────────────────────
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            if logger.entries.isEmpty {
                                emptyState
                            } else {
                                ForEach(logger.entries) { entry in
                                    LogRow(entry: entry)
                                        .id(entry.id)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: logger.entries.count) { _, _ in
                        if autoScroll, let last = logger.entries.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                .liquidGlass(cornerRadius: 20, tintColor: .white, tintOpacity: 0.02)
                .padding(.horizontal, 16)

                // ── Кнопки снизу ─────────────────────────────────────
                bottomBar
                    .padding(.top, 12)
                    .padding(.bottom, 32)
            }
            .padding(.top, 12)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: exportText)
        }
    }

    // MARK: - Компоненты

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Logs")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(logger.entries.count) entries")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()

            HStack(spacing: 10) {
                // Auto-scroll toggle
                Button(action: { autoScroll.toggle() }) {
                    Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(autoScroll ? Color.xasuCyan : Color.textTertiary)
                }
                .buttonStyle(.plain)

                // Clear
                Button(action: { logger.clear() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .liquidGlass(cornerRadius: 10, tintColor: .white, tintOpacity: 0.04)
                }
                .buttonStyle(.plain)

                // Close
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .liquidGlass(cornerRadius: 16, tintColor: .white, tintOpacity: 0.04)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Color.textTertiary)
            Text("No logs yet")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Экспорт
            Button(action: {
                exportText = logger.exportText()
                showShareSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                    Text("Export")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .liquidGlass(cornerRadius: 20, tintColor: .xasuPurple, tintOpacity: 0.15)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Log Row

private struct LogRow: View {
    let entry: LogEntry

    private var levelColor: Color {
        switch entry.level {
        case .success: return .xasuCyan
        case .error:   return Color(red: 0.96, green: 0.22, blue: 0.22)
        case .warning: return Color(red: 0.95, green: 0.75, blue: 0.2)
        case .debug:   return Color.xasuPurple.opacity(0.8)
        case .info:    return Color.textSecondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.formattedTime)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 80, alignment: .leading)

            Text(entry.level.rawValue)
                .font(.system(size: 11))

            Text(entry.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(levelColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    var text: String? = nil
    var items: [Any]? = nil

    init(text: String) { self.text = text }
    init(items: [Any]) { self.items = items }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityItems: [Any] = items ?? [text ?? ""]
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview { LogsView() }
