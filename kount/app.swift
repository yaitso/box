import SwiftUI

@main
struct KountApp: App {
    @NSApplicationDelegateAdaptor(KountDelegate.self) var kount_delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
