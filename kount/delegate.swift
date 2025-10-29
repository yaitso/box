import Cocoa
import CoreGraphics
import Foundation
import SQLite3

class KountDelegate: NSObject, NSApplicationDelegate {
    struct AppState { var total: Int64; var current: Int64 }
    enum Constants {
        static let persist_interval: TimeInterval = 60
        static let warning_symbol = "💀"
    }

    var status_item: NSStatusItem?
    var state = AppState(total: 0, current: 0)
    var current_day_start: Int64 = 0
    var db: OpaquePointer?
    var timer: Timer?
    var event_tap: CFMachPort?
    var db_path: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("box/kount/kount.db").path
    }

    func applicationDidFinishLaunching(_: Notification) {
        status_item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status_item?.behavior = [.removalAllowed]

        if let button = status_item?.button {
            button.title = "0"
        }

        init_db()
        current_day_start = get_current_day_start()
        load_today_total()
        start_event_monitor()
        start_periodic_save()
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
        let dayEnd = dayStart + 86400
        let query = "SELECT SUM(count) FROM hourly_counts WHERE timestamp >= ? AND timestamp < ?"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, dayStart)
            sqlite3_bind_int64(statement, 2, dayEnd)
            if sqlite3_step(statement) == SQLITE_ROW {
                state.total = sqlite3_column_int64(statement, 0)
            }
        }
        sqlite3_finalize(statement)
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
