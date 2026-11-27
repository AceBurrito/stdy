import Foundation
import Combine

class WorkoutSessionManager: ObservableObject {
    static let shared = WorkoutSessionManager()
    
    @Published var isSessionActive = false
    
    func startWorkoutSession() async {}
    func endWorkoutSession() async {}
    func discardWorkoutSession() {}
}