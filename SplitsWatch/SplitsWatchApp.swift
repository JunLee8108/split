//
//  SplitsWatchApp.swift
//  SplitsWatch
//

import SwiftUI

@main
struct SplitsWatchApp: App {
    init() {
        WatchSync.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
