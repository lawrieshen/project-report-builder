//
//  AppDelegate.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 26/9/2026.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var session: AppSessionStore?

    func applicationWillTerminate(_ notification: Notification) {
        session?.endSession()
    }
}
