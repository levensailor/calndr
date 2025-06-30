//
//  calndrApp.swift
//  calndr
//
//  Created by Jeff Levensailor on 6/25/25.
//

import SwiftUI

@main
struct calndrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthenticationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(ThemeManager()) // It's okay to create this here if it's stateless
        }
    }
}
