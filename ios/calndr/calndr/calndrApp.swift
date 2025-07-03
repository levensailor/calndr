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
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var storeManager = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(navigationManager)
                .environmentObject(ThemeManager()) // It's okay to create this here if it's stateless
                .environmentObject(storeManager)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        guard url.scheme == "calndr" else { return }
        
        if url.host == "schedule" {
            navigationManager.shouldNavigateToSchedule = true
        }
    }
}
