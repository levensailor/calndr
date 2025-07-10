//
//  calndrApp.swift
//  calndr
//
//  Created by Levi Sailor on 9/1/23.
//

import SwiftUI
import UserNotifications

@main
struct calndrApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var calendarViewModel: CalendarViewModel
    @StateObject private var networkMonitor = NetworkMonitor()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        let authManager = AuthenticationManager()
        let themeManager = ThemeManager()
        _authManager = StateObject(wrappedValue: authManager)
        _themeManager = StateObject(wrappedValue: themeManager)
        _calendarViewModel = StateObject(wrappedValue: CalendarViewModel(authManager: authManager, themeManager: themeManager))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoggedIn {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .environmentObject(calendarViewModel)
            .environmentObject(themeManager)
            .environmentObject(networkMonitor)
            .onAppear(perform: setupAppearance)
        }
    }
    
    private func setupAppearance() {
        // Your existing appearance setup code
    }
}
