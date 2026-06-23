import AppKit
import DailyReplicaCore
import SwiftUI

enum CalmPalette {
    static let porcelain = Color(nsColor: .windowBackgroundColor)
    static let ink = Color(nsColor: .labelColor)
    static let graphite = Color(hex: 0x5F6875)
    static let mist = Color(hex: 0xE5E8EC)
    static let cypress = Color(hex: 0x2F6F63)
    static let signalBlue = Color(hex: 0x476F9D)
    static let persimmon = Color(hex: 0x9A6A2F)
    static let iris = Color(hex: 0x6D649B)
    static let rose = Color(hex: 0x9E5668)

    static func categoryColor(_ categoryID: String) -> Color {
        switch categoryID {
        case CategoryID.work.rawValue:
            return cypress
        case CategoryID.videogames.rawValue:
            return iris
        case CategoryID.communication.rawValue:
            return signalBlue
        case CategoryID.browsing.rawValue:
            return persimmon
        case CategoryID.media.rawValue:
            return rose
        case CategoryID.personal.rawValue:
            return Color(hex: 0x7A8B3A)
        case CategoryID.unclassified.rawValue:
            return graphite
        case CategoryID.inactive.rawValue:
            return Color(hex: 0xA8B0BA)
        default:
            let colors = [cypress, signalBlue, persimmon, iris, rose, Color(hex: 0x7A8B3A)]
            let index = abs(categoryID.hashValue) % colors.count
            return colors[index]
        }
    }
}

extension Color {
    init(hex: Int, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xff) / 255
        let green = Double((hex >> 8) & 0xff) / 255
        let blue = Double(hex & 0xff) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

struct JournalSurface: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
    }
}

extension View {
    func journalSurface(padding: CGFloat = 16) -> some View {
        modifier(JournalSurface(padding: padding))
    }
}

struct JournalSectionHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    var tint: Color = CalmPalette.cypress
    var symbol: String = "clock"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .journalSurface(padding: 12)
    }
}

struct CategoryPill: View {
    let title: String
    let categoryID: String
    var systemImage: String = "tag.fill"

    var body: some View {
        Label {
            Text(title)
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(CalmPalette.categoryColor(categoryID))
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(CalmPalette.categoryColor(categoryID).opacity(0.11), in: Capsule())
    }
}

struct CategoryDot: View {
    let categoryID: String

    var body: some View {
        Circle()
            .fill(CalmPalette.categoryColor(categoryID))
            .frame(width: 8, height: 8)
    }
}

struct AppIconBadge: View {
    let bundleID: String?
    let appName: String?
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let image = icon {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(initials)
                    .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                    .foregroundStyle(CalmPalette.graphite)
            }
        }
        .frame(width: size, height: size)
        .background(CalmPalette.mist.opacity(0.7), in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }

    private var icon: NSImage? {
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private var initials: String {
        let name = appName ?? "App"
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "A" : String(letters).uppercased()
    }
}

struct DayRibbonView: View {
    let entries: [ActivityRibbonEntry]
    let selectedSegmentID: UUID?
    var height: CGFloat = 18
    var onSelect: ((UUID) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(CalmPalette.mist.opacity(0.7))

                ForEach(entries) { entry in
                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(CalmPalette.categoryColor(entry.categoryID).opacity(entry.state == .inactive ? 0.45 : 0.92))
                        .frame(
                            width: max(2, proxy.size.width * entry.widthFraction),
                            height: height
                        )
                        .offset(x: proxy.size.width * entry.startFraction)
                        .overlay(alignment: .leading) {
                            if selectedSegmentID == entry.segmentID {
                                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                                    .stroke(.primary.opacity(0.65), lineWidth: 2)
                                    .frame(
                                        width: max(3, proxy.size.width * entry.widthFraction),
                                        height: height + 4
                                    )
                                    .offset(x: proxy.size.width * entry.startFraction)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect?(entry.segmentID)
                        }
                }

                Rectangle()
                    .fill(.primary.opacity(0.5))
                    .frame(width: 1, height: height + 8)
                    .offset(x: min(proxy.size.width - 1, max(0, currentDayFraction * proxy.size.width)))
            }
        }
        .frame(height: height + 8)
        .accessibilityLabel("Day ribbon")
    }

    private var currentDayFraction: Double {
        let day = DateInterval.day(containing: Date())
        return min(1, max(0, Date().timeIntervalSince(day.start) / day.duration))
    }
}

struct EmptyJournalState: View {
    let title: String
    let message: String
    var systemImage: String = "sparkle.magnifyingglass"

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(CalmPalette.cypress)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .journalSurface(padding: 24)
    }
}

#if DEBUG
#Preview("Journal Section Header") {
    JournalSectionHeader(title: "Today", detail: "2h 10m")
        .padding()
        .frame(width: 360)
}

#Preview("Metric Tile") {
    MetricTile(title: "Tracked", value: "3h 12m", tint: CalmPalette.cypress, symbol: "clock")
        .padding()
        .frame(width: 280)
}

#Preview("Category Pill") {
    HStack {
        CategoryPill(title: "Work", categoryID: CategoryID.work.rawValue)
        CategoryPill(title: "Edited", categoryID: CategoryID.personal.rawValue, systemImage: "pencil")
    }
    .padding()
}

#Preview("Category Dot") {
    CategoryDot(categoryID: CategoryID.media.rawValue)
        .padding()
}

#Preview("App Icon Badge") {
    AppIconBadge(bundleID: "com.apple.dt.Xcode", appName: "Xcode", size: 52)
        .padding()
}

#Preview("Day Ribbon") {
    DayRibbonView(
        entries: PreviewFactory.ribbonEntries(),
        selectedSegmentID: PreviewFactory.segment().id,
        height: 18
    )
    .padding()
    .frame(width: 420)
}

#Preview("Empty Journal State") {
    EmptyJournalState(
        title: "No activity yet",
        message: "Start tracking from the menu bar and your day will appear here.",
        systemImage: "clock.badge"
    )
    .padding()
    .frame(width: 460)
}
#endif
