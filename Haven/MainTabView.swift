import SwiftUI

/// Tab order: Today · Strength · Cardio · Body · More
/// Training setup lives under More; it's a management screen, not a daily destination.
enum AppTab: Int {
    case today = 0
    case strength = 1
    case cardio = 2
    case body = 3
    case more = 4
}

struct MainTabView: View {
    @Environment(NavigationRouter.self) private var router
    
    var body: some View {
        @Bindable var router = router
        
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }
                .tag(AppTab.today.rawValue)
            
            WorkoutHistoryView()
                .tabItem {
                    Label("Strength", systemImage: "dumbbell")
                }
                .tag(AppTab.strength.rawValue)
            
            CardioTrackingView()
                .tabItem {
                    Label("Cardio", systemImage: "heart")
                }
                .tag(AppTab.cardio.rawValue)
            
            BodyCompView()
                .tabItem {
                    Label("Body", systemImage: "figure.stand")
                }
                .tag(AppTab.body.rawValue)
            
            ProfileView()
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
                .tag(AppTab.more.rawValue)
        }
        .tint(.atlasPrimary)
        .onChange(of: router.selectedTab) { oldValue, newValue in
            if oldValue == AppTab.body.rawValue && newValue != AppTab.body.rawValue {
                NotificationCenter.default.post(
                    name: Notification.Name("LockBodyTab"),
                    object: nil
                )
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(NavigationRouter())
}
