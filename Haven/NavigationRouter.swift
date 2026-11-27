// NavigationRouter.swift
// Haven (Main App target ONLY)
//
// Lightweight observable router for deep link handling.
// Injected at the RootView level so both MainTabView and the
// .onOpenURL handler can share navigation state.

import SwiftUI

@Observable
class NavigationRouter {
    var selectedTab: Int = 0
    var showWeeklyCheckIn: Bool = false
}