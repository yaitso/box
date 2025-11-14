import Charts
import Cocoa
import CoreGraphics
import Foundation
import ServiceManagement
import SQLite3
import SwiftUI

class KountDelegate: NSObject, NSApplicationDelegate {
    struct AppState { var total: Int64; var current: Int64 }

    enum Constants {
        static let persist_interval: TimeInterval = 60
        static let warning_symbol = "💀"
        static let seconds_per_day: Int64 = 86400
        static let menu_item_width: CGFloat = 180
        static let menu_item_height: CGFloat = 26
    }

    enum MenuItemConfig {
        static let symbol_size: CGFloat = 13.65
        static let count_size: CGFloat = 13
        static let hover_opacity: CGFloat = 0.06
        static let corner_radius: CGFloat = 6
        static let padding_horizontal: CGFloat = 12
        static let padding_vertical: CGFloat = 4
        static let padding_inset: CGFloat = 6
    }

    enum QuitItemConfig {
        static let corner_radius_top: CGFloat = 8
        static let corner_radius_bottom: CGFloat = 12
        static let padding_horizontal: CGFloat = 16
        static let padding_top: CGFloat = 4
        static let padding_bottom: CGFloat = 6
        static let padding_inset: CGFloat = 9
    }

    var status_item: NSStatusItem?
    var state = AppState(total: 0, current: 0)
    var current_day_start: Int64 = 0
    var db: OpaquePointer?
    var timer: Timer?
    var event_tap: CFMachPort?
    var menu: NSMenu?
    var show_plots = false
    var hovered_bar_value: Int64?

    var current_menu_width: CGFloat {
        show_plots ? Constants.menu_item_width * 1.5 : Constants.menu_item_width
    }
    var db_path: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("box/kount/kount.db").path
    }

    func applicationDidFinishLaunching(_: Notification) {
        status_item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status_item?.behavior = [.removalAllowed]

        if let button = status_item?.button {
            button.title = "0"
            button.alignment = .center
            button.imagePosition = .noImage
        }

        setup_menu()
        enable_login_item()

        init_db()
        current_day_start = get_current_day_start()
        load_today_total()
        start_event_monitor()
        start_periodic_save()
    }

    func enable_login_item() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
            } catch {
                print("failed to register login item: \(error)")
            }
        }
    }

    func init_db() {
        guard sqlite3_open(db_path, &db) == SQLITE_OK else { return }

        let createTable = """
        CREATE TABLE IF NOT EXISTS hourly_counts (
            timestamp INTEGER PRIMARY KEY,
            count INTEGER NOT NULL
        );
        """

        sqlite3_exec(db, createTable, nil, nil, nil)
    }

    func get_current_day_start() -> Int64 {
        let start = Calendar.current.startOfDay(for: Date())
        return Int64(start.timeIntervalSince1970)
    }

    func load_today_total() {
        let dayStart = current_day_start
        let dayEnd = dayStart + Constants.seconds_per_day
        state.total = get_count_for_range(start: dayStart, end: dayEnd)
        update_display()
    }

    func save_interval_count() {
        if state.current == 0 { return }
        let timestamp = Int64(Date().timeIntervalSince1970)
        let insert = "INSERT OR REPLACE INTO hourly_counts (timestamp, count) VALUES (?, ?)"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insert, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, timestamp)
            sqlite3_bind_int64(statement, 2, state.current)
            _ = sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
        state.current = 0
    }

    func check_day_rollover() {
        let newDayStart = get_current_day_start()
        if newDayStart != current_day_start {
            save_interval_count()
            current_day_start = newDayStart
            state = AppState(total: 0, current: 0)
            update_display()
        }
    }

    func start_event_monitor() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                let appDelegate = Unmanaged<KountDelegate>.fromOpaque(refcon!).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let et = appDelegate.event_tap {
                        CGEvent.tapEnable(tap: et, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }
                appDelegate.increment_count()
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            show_accessibility_alert()
            status_item?.button?.title = Constants.warning_symbol
            return
        }

        event_tap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func increment_count() {
        check_day_rollover()
        state.total += 1
        state.current += 1
        update_display()
    }

    func update_display() {
        DispatchQueue.main.async {
            if let button = self.status_item?.button {
                button.title = "\(self.state.total)"
            }
        }
    }

    func start_periodic_save() {
        timer = Timer.scheduledTimer(withTimeInterval: Constants.persist_interval, repeats: true) { [weak self] _ in
            self?.check_day_rollover()
            self?.save_interval_count()
        }
    }

    func setup_menu() {
        menu = NSMenu()
        menu?.delegate = self
        status_item?.menu = menu
    }

    func get_count_for_range(start: Int64, end: Int64) -> Int64 {
        let query = "SELECT SUM(count) FROM hourly_counts WHERE timestamp >= ? AND timestamp < ?"
        var statement: OpaquePointer?
        var result: Int64 = 0

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, start)
            sqlite3_bind_int64(statement, 2, end)
            if sqlite3_step(statement) == SQLITE_ROW {
                result = sqlite3_column_int64(statement, 0)
            }
        }
        sqlite3_finalize(statement)
        return result
    }

    func styled_menu_item(symbol: String, interval: String, count: Int64) -> NSMenuItem {
        let item = NSMenuItem()
        let view = MenuItemView(symbol: symbol, interval: interval, count: count)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(
            x: 0, y: 0,
            width: current_menu_width,
            height: Constants.menu_item_height
        )
        item.view = hosting
        return item
    }

    func get_daily_counts(days: Int) -> [(date: Date, count: Int64)] {
        var results: [(Date, Int64)] = []
        let cal = Calendar.current
        let now = Date()

        for day_offset in (0..<days).reversed() {
            guard let day_date = cal.date(byAdding: .day, value: -day_offset, to: now) else { continue }
            let day_start = cal.startOfDay(for: day_date)
            let day_end = day_start.addingTimeInterval(TimeInterval(Constants.seconds_per_day))

            let start_ts = Int64(day_start.timeIntervalSince1970)
            let end_ts = Int64(day_end.timeIntervalSince1970)

            var count = get_count_for_range(start: start_ts, end: end_ts)
            if cal.isDate(day_date, inSameDayAs: now) {
                count += state.current
            }

            results.append((day_start, count))
        }

        for future_offset in 1...5 {
            if let future_date = cal.date(byAdding: .day, value: future_offset, to: now) {
                let future_start = cal.startOfDay(for: future_date)
                results.append((future_start, 0))
            }
        }

        return results
    }

    func show_accessibility_alert() {
        let alert = NSAlert()
        alert.messageText = "input monitoring permission required"
        alert.informativeText = "kount needs input monitoring access to count keystrokes"
        alert.addButton(withTitle: "open settings")
        alert.addButton(withTitle: "cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
        }
    }

    func applicationWillTerminate(_: Notification) {
        save_interval_count()
        sqlite3_close(db)
    }
}

struct MenuItemView: View {
    let symbol: String
    let interval: String
    let count: Int64
    @State private var is_hovering = false

    var formatted_count: String {
        let formatter = NumberFormatter()
        formatter.groupingSeparator = ""
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? String(count)
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: KountDelegate.MenuItemConfig.symbol_size))
                .foregroundColor(.black)
                .frame(width: 16)

            Text(interval)
                .font(.system(size: KountDelegate.MenuItemConfig.symbol_size))
                .foregroundColor(.black)
                .padding(.leading, 8)

            Spacer(minLength: 12)

            Text(formatted_count)
                .font(.system(size: KountDelegate.MenuItemConfig.count_size).monospacedDigit())
                .foregroundColor(.black)
        }
        .padding(.horizontal, KountDelegate.MenuItemConfig.padding_horizontal)
        .padding(.vertical, KountDelegate.MenuItemConfig.padding_vertical)
        .background(
            RoundedRectangle(cornerRadius: KountDelegate.MenuItemConfig.corner_radius)
                .fill(is_hovering ? Color.black.opacity(KountDelegate.MenuItemConfig.hover_opacity) : Color.clear)
                .padding(.horizontal, KountDelegate.MenuItemConfig.padding_inset)
        )
        .onHover { hovering in
            is_hovering = hovering
        }
    }
}

struct DayData: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int64
    let week_start: Date
}

struct PlotsChartView: View {
    let daily_data: [(date: Date, count: Int64)]
    @Binding var hovered_value: Int64?
    @State private var appeared = false
    @State private var selected_date: Date?

    var processed_data: [DayData] {
        let cal = Calendar.current
        return daily_data.map { day in
            let week_start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day.date))!
            return DayData(date: day.date, count: day.count, week_start: week_start)
        }
    }

    var weeks: [Date] {
        Array(Set(processed_data.map { $0.week_start })).sorted()
    }

    var week_totals: [Date: Int64] {
        var totals: [Date: Int64] = [:]
        for day in processed_data {
            totals[day.week_start, default: 0] += day.count
        }
        return totals
    }

    var max_daily_count: Int64 {
        daily_data.map { $0.count }.max() ?? 1
    }

    func format_number(_ n: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.groupingSeparator = ""
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? String(n)
    }

    var body: some View {
        VStack(spacing: 0) {
            Chart(processed_data) { day in
                BarMark(
                    x: .value("date", day.date, unit: .day),
                    y: .value("count", day.count)
                )
                .foregroundStyle(day.count > 0 ? Color.black.opacity(0.8) : Color.clear)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            if let total = week_totals[date], total > 0 {
                                Text(format_number(total))
                                    .font(.system(size: 10))
                                    .foregroundColor(.black)
                            }
                        }

                        AxisGridLine()
                        AxisTick()
                    }
                }
            }
            .chartXSelection(value: $selected_date)
            .chartYScale(domain: 0...max(max_daily_count, 1))
            .chartYAxis(.hidden)
            .frame(height: 180)
            .padding(.leading, 12)
            .padding(.trailing, 24)
            .padding(.vertical, 12)
            .onChange(of: selected_date) { newValue in
                if let newValue = newValue,
                   let selected_day = processed_data.first(where: { Calendar.current.isDate($0.date, inSameDayAs: newValue) }),
                   selected_day.count > 0 {
                    hovered_value = selected_day.count
                } else {
                    hovered_value = nil
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                appeared = true
            }
        }
    }
}

struct PlotsMenuItemView: View {
    @State private var is_hovering = false
    @Binding var show_plots: Bool
    @Binding var hovered_value: Int64?

    var formatted_value: String {
        guard let value = hovered_value else { return "plots" }
        let formatter = NumberFormatter()
        formatter.groupingSeparator = ""
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Image(systemName: "chart.bar.fill")
                .font(.system(size: KountDelegate.MenuItemConfig.symbol_size))
                .foregroundColor(.black)
                .frame(width: 16)

            Text(formatted_value)
                .font(.system(size: KountDelegate.MenuItemConfig.symbol_size))
                .foregroundColor(.black)
                .padding(.leading, 8)
            Spacer()
        }
        .padding(.horizontal, KountDelegate.QuitItemConfig.padding_horizontal)
        .padding(.top, KountDelegate.QuitItemConfig.padding_top)
        .padding(.bottom, KountDelegate.QuitItemConfig.padding_bottom)
        .background(
            RoundedRectangle(cornerRadius: KountDelegate.QuitItemConfig.corner_radius_top)
                .fill(is_hovering ? Color.black.opacity(KountDelegate.MenuItemConfig.hover_opacity) : Color.clear)
                .padding(.horizontal, KountDelegate.QuitItemConfig.padding_inset)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            show_plots.toggle()
        }
        .onHover { hovering in
            is_hovering = hovering
        }
    }
}

struct QuitMenuItemView: View {
    @State private var is_hovering = false

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Image(systemName: "figure.fall")
                .font(.system(size: KountDelegate.MenuItemConfig.symbol_size))
                .foregroundColor(.black)
                .frame(width: 16)

            Text("quit")
                .font(.system(size: KountDelegate.MenuItemConfig.symbol_size))
                .foregroundColor(.black)
                .padding(.leading, 8)
            Spacer()
        }
        .padding(.horizontal, KountDelegate.QuitItemConfig.padding_horizontal)
        .padding(.top, KountDelegate.QuitItemConfig.padding_top)
        .padding(.bottom, KountDelegate.QuitItemConfig.padding_bottom)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: KountDelegate.QuitItemConfig.corner_radius_top,
                bottomLeadingRadius: KountDelegate.QuitItemConfig.corner_radius_bottom,
                bottomTrailingRadius: KountDelegate.QuitItemConfig.corner_radius_bottom,
                topTrailingRadius: KountDelegate.QuitItemConfig.corner_radius_top
            )
            .fill(is_hovering ? Color.black.opacity(KountDelegate.MenuItemConfig.hover_opacity) : Color.clear)
            .padding(.horizontal, KountDelegate.QuitItemConfig.padding_inset)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            NSApplication.shared.terminate(nil)
        }
        .onHover { hovering in
            is_hovering = hovering
        }
    }
}

extension KountDelegate: NSMenuDelegate {
    func menuWillOpen(_: NSMenu) {
        update_menu_items()
    }

    func update_menu_items() {
        menu?.removeAllItems()

        let today_start = get_current_day_start()
        let today_end = today_start + Constants.seconds_per_day
        let yesterday_start = today_start - Constants.seconds_per_day
        let week_start = today_start - (7 * Constants.seconds_per_day)
        let month_start = today_start - (30 * Constants.seconds_per_day)

        let yesterday_count = get_count_for_range(start: yesterday_start, end: today_start)
        let week_count = get_count_for_range(start: week_start, end: today_end) + state.current
        let month_count = get_count_for_range(start: month_start, end: today_end) + state.current

        menu?.addItem(styled_menu_item(symbol: "sun.haze.fill", interval: "yesterday", count: yesterday_count))
        menu?.addItem(styled_menu_item(symbol: "tornado", interval: "week", count: week_count))
        menu?.addItem(styled_menu_item(symbol: "moon.stars.fill", interval: "month", count: month_count))

        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(create_plots_menu_item())

        if show_plots {
            menu?.addItem(create_chart_menu_item())
        }

        menu?.addItem(create_quit_menu_item())

        menu?.minimumWidth = current_menu_width
    }

    func create_plots_menu_item() -> NSMenuItem {
        let item = NSMenuItem()
        let view = PlotsMenuItemView(
            show_plots: Binding(
                get: { self.show_plots },
                set: { self.show_plots = $0; self.update_menu_items() }
            ),
            hovered_value: Binding(
                get: { self.hovered_bar_value },
                set: { self.hovered_bar_value = $0 }
            )
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(
            x: 0, y: 0,
            width: current_menu_width,
            height: Constants.menu_item_height
        )
        item.view = hosting
        return item
    }

    func create_chart_menu_item() -> NSMenuItem {
        let item = NSMenuItem()
        let daily_data = get_daily_counts(days: 28)
        let view = PlotsChartView(
            daily_data: daily_data,
            hovered_value: Binding(
                get: { self.hovered_bar_value },
                set: { self.hovered_bar_value = $0 }
            )
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(
            x: 0, y: 0,
            width: current_menu_width,
            height: 210
        )
        item.view = hosting
        return item
    }

    func create_quit_menu_item() -> NSMenuItem {
        let item = NSMenuItem(title: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.target = NSApp
        let hosting = NSHostingView(rootView: QuitMenuItemView())
        hosting.frame = NSRect(
            x: 0, y: 0,
            width: current_menu_width,
            height: Constants.menu_item_height
        )
        item.view = hosting
        return item
    }
}
