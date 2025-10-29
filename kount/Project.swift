import ProjectDescription

let project = Project(
    name: "kount",
    targets: [
        .target(
            name: "kount",
            destinations: .macOS,
            product: .app,
            bundleId: "com.yaitso.kount",
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "kount",
                    "LSUIElement": true,
                    "NSAppleEventsUsageDescription": "kount needs to monitor keyboard events to count keystrokes.",
                ]
            ),
            sources: [
                "app.swift",
                "delegate.swift",
            ],
            entitlements: "kount.entitlements",
            dependencies: []
        ),
    ]
)
