import Foundation
import AVFoundation
import UIKit

class BackgroundTimerManager {
    static let shared = BackgroundTimerManager()
    
    private var audioSession: AVAudioSession?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup (keeps app alive in background)
    private func setupAudioSession() {
        do {
            audioSession = AVAudioSession.sharedInstance()
            try audioSession?.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession?.setActive(false)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Enable Background Timer
    func enableBackgroundTimer() {
        do {
            // Activate audio session (silent audio keeps app alive)
            try audioSession?.setActive(true)
            print("✅ Background timer enabled")
        } catch {
            print("❌ Failed to enable background timer: \(error)")
        }
    }
    
    // MARK: - Disable Background Timer
    func disableBackgroundTimer() {
        do {
            try audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Background timer disabled")
        } catch {
            print("❌ Failed to disable background timer: \(error)")
        }
    }
    
    // MARK: - Prevent Screen Sleep
    func preventScreenSleep() {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
            print("✅ Screen sleep prevented")
        }
    }
    
    // MARK: - Allow Screen Sleep
    func allowScreenSleep() {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
            print("✅ Screen sleep allowed")
        }
    }
    
    // MARK: - Begin Background Task
    func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    // MARK: - End Background Task
    func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
}