import SwiftUI

struct MainTabView: View {
    @Environment(NavigationRouter.self) private var router
    
    init() {
        // Customize tab bar appearance for premium look
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(Color.atlasBackground.opacity(0.95))
        
        // Selected item color
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.atlasPrimary)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.atlasPrimary)
        ]
        
        // Unselected item color
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.white.opacity(0.6))
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color.white.opacity(0.6))
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        @Bindable var router = router
        
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }
                .tag(0)
            
            TrainingProgramView()
                .tabItem {
                    Label("Training", systemImage: "list.bullet.clipboard")
                }
                .tag(1)
            
            WorkoutHistoryView()
                .tabItem {
                    Label("Strength", systemImage: "dumbbell.fill")
                }
                .tag(2)
            
            CardioTrackingView()
                .tabItem {
                    Label("Cardio", systemImage: "heart.fill")
                }
                .tag(3)
            
            BodyCompView()
                .tabItem {
                    Label("Body", systemImage: "figure.stand")
                }
                .tag(4)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(5)
        }
        .tint(.atlasPrimary)
        .onChange(of: router.selectedTab) { oldValue, newValue in
            if oldValue == 4 && newValue != 4 {
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