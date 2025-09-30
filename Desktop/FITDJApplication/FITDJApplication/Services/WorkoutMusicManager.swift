//
//  WorkoutMusicManager.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import Combine
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WebKit)
import WebKit
#endif

// F-004 & F-006: Music management with ducking for trainer voice
@MainActor
class WorkoutMusicManager: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentTrack: SpotifyTrack?
    @Published var volume: Float = 0.7
    @Published var errorMessage: String?
    
    private let spotifyManager: SpotifyManager
#if canImport(AVFoundation) && !targetEnvironment(macCatalyst)
    private var audioSession = AVAudioSession.sharedInstance()
#endif
    private var cancellables = Set<AnyCancellable>()
    
    // Music ducking settings
    private let normalVolume: Float = 0.7
    private let duckedVolume: Float = 0.15  // Quiet but audible when trainer is speaking
    private var isDucked = false
    
    // User-controlled volume settings
    @Published var userMusicVolume: Float = 1.0 // User-controlled music volume multiplier (0.0 to 1.0)
    
    // Track current cue for volume recalculation
    private var currentCue: VoiceCue?
    
    // Fade animation settings
    private var fadeTimer: Timer?
    private let fadeDuration: TimeInterval = 0.5 // 500ms fade
    private let fadeSteps: Int = 20 // Number of steps for smooth fade
    
    // Performance optimizations
    private var deviceCache: [SpotifyDevice] = []
    private var lastDeviceCheck: Date?
    private let deviceCacheTimeout: TimeInterval = 30.0 // 30 seconds
    private var activeDeviceID: String?
    private let backgroundQueue = DispatchQueue(label: "workout.music.background", qos: .userInitiated)
    private var pendingRequests = Set<String>() // Track pending requests to avoid duplicates
    
    // Network error handling
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 2.0
    private var retryCount: [String: Int] = [:]
    
    
    init(spotifyManager: SpotifyManager) {
        self.spotifyManager = spotifyManager
        super.init()
        setupAudioSession()
        setupVolumeObserver()
    }
    
    deinit {
        fadeTimer?.invalidate()
        fadeTimer = nil
        
        // Cancel any pending requests
        pendingRequests.removeAll()
        
        // Clear cache
        deviceCache.removeAll()
        activeDeviceID = nil
        lastDeviceCheck = nil
        
        // Clear retry counts
        retryCount.removeAll()
        
    }
    
    // MARK: - Public Methods
    
    func startWorkoutMusic(for workout: Workout, userPreference: MusicPreference) {
        print("🎵 ===== STARTING WORKOUT MUSIC =====")
        print("🎵 Starting workout music for: \(workout.title)")
        print("🎵 User preference: \(userPreference)")
        
        // Add a small delay to ensure Spotify manager is fully initialized
        // and to allow voice system to set up first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { 
                print("❌ WorkoutMusicManager deallocated during initialization")
                return 
            }
            
            // Check if Spotify is connected
            guard self.spotifyManager.isConnected else {
                print("🎵 Spotify not connected. Workout will continue without music.")
                self.errorMessage = "No music available. Connect to Spotify to play music during workouts."
                self.isPlaying = false
                self.isPaused = false
                return
            }
            
            guard self.spotifyManager.accessToken != nil else {
                print("🎵 No Spotify access token available")
                self.errorMessage = "No Spotify access token available"
                self.isPlaying = false
                self.isPaused = false
                return
            }
            
            // Ensure audio session is compatible with voice system
            self.configureAudioSessionForMusic()
            
            let energyLevel = self.getEnergyLevel(for: workout, userPreference: userPreference)
            print("🎵 Playing Spotify playlist for energy level: \(energyLevel)")
            self.playWorkoutPlaylist(energyLevel: energyLevel)
        }
    }
    
    func pauseMusic() {
        guard spotifyManager.isConnected else { return }
        
        isPaused = true
        isPlaying = false
        
        // Pause Spotify playback
        pauseSpotifyPlayback()
    }
    
    func resumeMusic() {
        guard spotifyManager.isConnected else { return }
        
        isPaused = false
        isPlaying = true
        
        // Resume Spotify playback
        resumeSpotifyPlayback()
    }
    
    func stopMusic() {
        guard spotifyManager.isConnected else { return }
        
        isPlaying = false
        isPaused = false
        
        // Stop Spotify playback
        stopSpotifyPlayback()
    }
    
    func duckMusic() {
        guard !isDucked else { return }
        
        print("🎵 Ducking music volume from \(volume) to \(duckedVolume)")
        isDucked = true
        fadeToVolume(duckedVolume)
    }
    
    func unduckMusic() {
        guard isDucked else { return }
        
        print("🎵 Unducking music volume from \(volume) to \(normalVolume)")
        isDucked = false
        fadeToVolume(normalVolume)
    }
    
    private func duckMusicForVoice(cueType: String, cueText: String) {
        guard !isDucked else { return }
        
        // Store current cue for volume recalculation
        currentCue = VoiceCue(id: "current", text: cueText, timing: 0, type: VoiceCueType(rawValue: cueType) ?? .instruction)
        
        // Adjust ducking based on cue type with more nuanced control
        let targetVolume: Float
        let fadeSpeed: TimeInterval
        
        switch cueType {
        case "instruction":
            // Instructions need heavy ducking for clarity - these are critical
            targetVolume = (duckedVolume * 0.4) * userMusicVolume // Apply user volume multiplier
            fadeSpeed = 0.25 // Faster fade for instructions
        case "countdown":
            // Countdowns need moderate ducking but should be clear
            targetVolume = (duckedVolume * 0.6) * userMusicVolume // Apply user volume multiplier
            fadeSpeed = 0.3
        case "motivation":
            // Motivational cues can have less ducking to maintain energy
            targetVolume = (duckedVolume * 1.5) * userMusicVolume // Apply user volume multiplier
            fadeSpeed = 0.4
        case "transition":
            // Transitions need moderate ducking
            targetVolume = (duckedVolume * 0.7) * userMusicVolume // Apply user volume multiplier
            fadeSpeed = 0.35
        case "rest":
            // During rest, music can be louder for motivation
            targetVolume = (duckedVolume * 2.0) * userMusicVolume // Apply user volume multiplier
            fadeSpeed = 0.5
        case "exercise_description":
            // Exercise descriptions need clear audio but music can stay energetic
            targetVolume = (duckedVolume * 0.8) * userMusicVolume // Apply user volume multiplier
            fadeSpeed = 0.4
        default:
            targetVolume = duckedVolume * userMusicVolume // Apply user volume multiplier
            fadeSpeed = 0.5
        }
        
        print("🎵 Ducking for \(cueType): volume=\(targetVolume), speed=\(fadeSpeed)s")
        print("🎵 Current volume: \(volume), Target volume: \(targetVolume)")
        isDucked = true
        
        // Use custom fade speed for this ducking
        fadeToVolumeWithSpeed(targetVolume, duration: fadeSpeed)
    }
    
    private func unduckMusicAfterVoice() {
        guard isDucked else { return }
        
        print("🎵 Unducking music after voice")
        print("🎵 Current volume: \(volume), Target volume: \(normalVolume * userMusicVolume)")
        isDucked = false
        currentCue = nil // Clear current cue
        
        // Add a longer delay to ensure voice has completely finished before unducking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            // Check if we're still not ducked (in case another voice cue started)
            guard !self.isDucked else { return }
            // Slower fade back to normal volume for smoother transition (with user volume multiplier)
            self.fadeToVolumeWithSpeed(self.normalVolume * self.userMusicVolume, duration: 1.2)
        }
    }
    
    func adjustIntensity(easier: Bool, currentWorkout: Workout) {
        let newEnergyLevel = getAdjustedEnergyLevel(for: currentWorkout, easier: easier)
        playWorkoutPlaylist(energyLevel: newEnergyLevel)
    }
    
    func setCustomPlaylistID(_ playlistID: String) {
        UserDefaults.standard.set(playlistID, forKey: "customSpotifyPlaylistID")
        print("🎵 Custom playlist ID set to: \(playlistID)")
    }
    
    func clearCustomPlaylistID() {
        UserDefaults.standard.removeObject(forKey: "customSpotifyPlaylistID")
        print("🎵 Custom playlist ID cleared")
    }
    
    func setUserMusicVolume(_ volume: Float) {
        userMusicVolume = max(0.0, min(1.0, volume)) // Clamp between 0.0 and 1.0
        print("🎵 User music volume set to: \(userMusicVolume)")
        
        // If music is currently playing, apply the new volume immediately
        if isPlaying && !isPaused {
            if isDucked {
                // If currently ducked, recalculate ducked volume with new user volume
                let currentCueType = currentCue?.type.rawValue ?? "default"
                duckMusicForVoice(cueType: currentCueType, cueText: currentCue?.text ?? "")
            } else {
                // If not ducked, apply normal volume with new user volume
                fadeToVolumeWithSpeed(normalVolume * userMusicVolume, duration: 0.3)
            }
        }
    }
    
    // MARK: - Music Energy Synchronization
    
    func syncMusicWithExercisePhase(phase: ExercisePhase) {
        guard isPlaying && !isPaused else { return }
        
        let energyMultiplier: Float
        let volumeMultiplier: Float
        
        switch phase {
        case .preparation:
            // Lower energy during preparation to not overwhelm
            energyMultiplier = 0.8
            volumeMultiplier = 0.9
        case .exercise:
            // Full energy during exercise for motivation
            energyMultiplier = 1.0
            volumeMultiplier = 1.0
        case .rest:
            // Slightly lower energy during rest but still motivating
            energyMultiplier = 0.9
            volumeMultiplier = 1.1
        case .transition:
            // Medium energy during transitions
            energyMultiplier = 0.85
            volumeMultiplier = 0.95
        }
        
        // Adjust music volume based on phase (only if not ducked)
        if !isDucked {
            let targetVolume = (normalVolume * userMusicVolume * volumeMultiplier)
            fadeToVolumeWithSpeed(targetVolume, duration: 1.0)
        }
        
        print("🎵 Music synced with exercise phase: \(phase) - energy: \(energyMultiplier), volume: \(volumeMultiplier)")
    }
    
    
    
    func checkSpotifySetup() -> String {
        guard spotifyManager.isConnected else {
            return "Please connect to Spotify first."
        }
        
        guard spotifyManager.accessToken != nil else {
            return "Spotify access token not available. Please reconnect to Spotify."
        }
        
        return "Spotify is connected. Make sure Spotify is open on another device (phone, computer, or web player) before starting a workout."
    }
    
    func searchForPlaylists(completion: @escaping ([SpotifyPlaylistInfo]) -> Void) {
        guard let accessToken = spotifyManager.accessToken else {
            completion([])
            return
        }
        
        // Search for workout playlists with optimized query
        let query = "workout fitness"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=playlist&limit=20") else {
            completion([])
            return
        }
        
        makeNetworkRequest(
            url: url,
            requestType: "search_playlists",
            accessToken: accessToken
        ) { result in
            switch result {
            case .success(let data):
                do {
                    let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
                    completion(searchResponse.playlists.items)
                } catch {
                    print("🎵 Failed to parse search response: \(error.localizedDescription)")
                    completion([])
                }
            case .failure(let error):
                print("🎵 Error searching playlists: \(error.localizedDescription)")
                completion([])
            }
        }
    }
    
    private func fadeToVolume(_ targetVolume: Float) {
        fadeToVolumeWithSpeed(targetVolume, duration: fadeDuration)
    }
    
    private func fadeToVolumeWithSpeed(_ targetVolume: Float, duration: TimeInterval) {
        // Cancel any existing fade
        fadeTimer?.invalidate()
        fadeTimer = nil
        
        let startVolume = volume
        let volumeDifference = targetVolume - startVolume
        
        // Skip fade if volume difference is too small
        if abs(volumeDifference) < 0.05 {
            volume = targetVolume
            setSpotifyVolume(targetVolume)
            return
        }
        
        let stepSize = volumeDifference / Float(fadeSteps)
        let timeStep = duration / Double(fadeSteps)
        
        print("🎵 Starting fade from \(startVolume) to \(targetVolume) over \(duration)s")
        
        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: timeStep, repeats: true) { [weak self] timer in
            guard let strongSelf = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let newVolume = startVolume + (stepSize * Float(currentStep))
            
            // Clamp volume to valid range
            let clampedVolume = max(0.0, min(1.0, newVolume))
            
            // Only update volume every few steps to reduce API calls during fade
            if currentStep % 3 == 0 || currentStep >= strongSelf.fadeSteps {
                print("🎵 Fade step \(currentStep)/\(strongSelf.fadeSteps): volume = \(clampedVolume)")
                
                // Update local volume and Spotify volume on main thread
                Task { @MainActor in
                    strongSelf.volume = clampedVolume
                    strongSelf.setSpotifyVolumeDirectly(clampedVolume)
                }
            } else {
                // Update local volume without API call for intermediate steps
                Task { @MainActor in
                    strongSelf.volume = clampedVolume
                }
            }
            
            // Check if we've reached the target or completed all steps
            if currentStep >= strongSelf.fadeSteps || abs(clampedVolume - targetVolume) < 0.01 {
                // Ensure we end exactly at target volume
                Task { @MainActor in
                    strongSelf.volume = targetVolume
                    strongSelf.setSpotifyVolumeDirectly(targetVolume)
                    print("🎵 Fade complete: final volume = \(targetVolume)")
                    strongSelf.fadeTimer?.invalidate()
                    strongSelf.fadeTimer = nil
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkNetworkConnectivity() -> Bool {
        // Check if we have network connectivity
        guard let url = URL(string: "https://api.spotify.com") else { return false }
        
        var isConnected = false
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                isConnected = httpResponse.statusCode < 500 // Any response under 500 means we can reach the server
            } else if error == nil {
                isConnected = true
            }
            semaphore.signal()
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 5.0) // 5 second timeout
        
        return isConnected
    }
    
    private func makeNetworkRequest(
        url: URL,
        requestType: String,
        accessToken: String,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        // Check network connectivity first
        guard checkNetworkConnectivity() else {
            print("🎵 No network connectivity for \(requestType)")
            completion(.failure(NetworkError.noConnectivity))
            return
        }
        
        // Prevent duplicate requests
        if pendingRequests.contains(requestType) {
            print("🎵 Request already in progress for \(requestType)")
            return
        }
        pendingRequests.insert(requestType)
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15.0
        
        // Add retry logic
        let retryKey = "\(requestType)_\(url.absoluteString)"
        let currentRetryCount = retryCount[retryKey] ?? 0
        
        if currentRetryCount >= maxRetryAttempts {
            print("🎵 Max retry attempts reached for \(requestType)")
            pendingRequests.remove(requestType)
            completion(.failure(NetworkError.maxRetriesReached))
            return
        }
        
        backgroundQueue.async {
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    guard let strongSelf = self else {
                        completion(.failure(NetworkError.unknown))
                        return
                    }
                    
                    strongSelf.pendingRequests.remove(requestType)
                    
                    if let error = error {
                        print("🎵 Network error for \(requestType): \(error.localizedDescription)")
                        
                        // Check if this is a retryable error
                        if strongSelf.isRetryableError(error) && currentRetryCount < strongSelf.maxRetryAttempts {
                            print("🎵 Retrying \(requestType) (attempt \(currentRetryCount + 1)/\(strongSelf.maxRetryAttempts))")
                            strongSelf.retryCount[retryKey] = currentRetryCount + 1
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + strongSelf.retryDelay) {
                                strongSelf.makeNetworkRequest(
                                    url: url,
                                    requestType: requestType,
                                    accessToken: accessToken,
                                    completion: completion
                                )
                            }
                            return
                        }
                        
                        completion(.failure(error))
                        return
                    }
                    
                    guard let data = data else {
                        completion(.failure(NetworkError.noData))
                        return
                    }
                    
                    // Reset retry count on success
                    strongSelf.retryCount.removeValue(forKey: retryKey)
                    completion(.success(data))
                }
            }.resume()
        }
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .notConnectedToInternet, .timedOut, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    private func setupAudioSession() {
#if canImport(AVFoundation) && !targetEnvironment(macCatalyst)
        // Add a small delay to avoid conflicts with VoiceManager
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            do {
                // Check if audio session is already configured by VoiceManager
                if self.audioSession.category == .playAndRecord {
                    print("🎵 Audio session already configured by VoiceManager")
                    return
                }
                
                // Set up audio session that works well with voice system
                // Use playAndRecord to allow both music and voice
                try self.audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .allowAirPlay, .allowBluetoothHFP, .defaultToSpeaker])
                try self.audioSession.setActive(true)
                print("🎵 Music audio session configured to work with voice system")
            } catch {
                print("❌ Music audio session setup failed: \(error.localizedDescription)")
                self.errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
            }
        }
#endif
    }
    
    private func configureAudioSessionForMusic() {
#if canImport(AVFoundation) && !targetEnvironment(macCatalyst)
        do {
            // Configure audio session to work with voice system
            // Use the same category as voice system to avoid conflicts
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .allowAirPlay, .allowBluetoothHFP, .defaultToSpeaker])
            try audioSession.setActive(true)
            print("🎵 Audio session configured for music with voice compatibility")
        } catch {
            print("❌ Failed to configure audio session for music: \(error.localizedDescription)")
        }
#endif
    }
    
    private func setupVolumeObserver() {
        // Monitor for voice manager speaking state with enhanced info
        NotificationCenter.default.publisher(for: .voiceManagerSpeaking)
            .sink { [weak self] notification in
                if let isSpeaking = notification.object as? Bool {
                    let userInfo = notification.userInfo
                    let cueText = userInfo?["cueText"] as? String ?? ""
                    let cueType = userInfo?["cueType"] as? String ?? ""
                    
                    print("🎵 Voice state changed: speaking=\(isSpeaking), type=\(cueType), text='\(cueText.prefix(50))...'")
                    
                    if isSpeaking {
                        self?.duckMusicForVoice(cueType: cueType, cueText: cueText)
                    } else {
                        self?.unduckMusicAfterVoice()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func getEnergyLevel(for workout: Workout, userPreference: MusicPreference) -> MusicEnergyLevel {
        let baseEnergy: MusicEnergyLevel
        
        switch workout.difficulty {
        case .beginner:
            baseEnergy = .medium
        case .intermediate:
            baseEnergy = .high
        case .advanced:
            baseEnergy = .veryHigh
        }
        
        // Adjust based on user preference
        switch userPreference {
        case .highEnergy:
            return baseEnergy.increase()
        case .calm:
            return baseEnergy.decrease()
        case .mixed:
            return baseEnergy
        }
    }
    
    private func getAdjustedEnergyLevel(for workout: Workout, easier: Bool) -> MusicEnergyLevel {
        let currentEnergy = getEnergyLevel(for: workout, userPreference: .mixed)
        return easier ? currentEnergy.decrease() : currentEnergy.increase()
    }
    
    private func playWorkoutPlaylist(energyLevel: MusicEnergyLevel) {
        guard let accessToken = spotifyManager.accessToken else {
            errorMessage = "No Spotify access token"
            return
        }
        
        let playlistID = getPlaylistID(for: energyLevel)
        startSpotifyPlayback(playlistID: playlistID, accessToken: accessToken)
    }
    
    private func getPlaylistID(for energyLevel: MusicEnergyLevel) -> String {
        // Check for custom playlist ID first
        if let customPlaylistID = UserDefaults.standard.string(forKey: "customSpotifyPlaylistID"), !customPlaylistID.isEmpty {
            print("🎵 Using custom playlist ID: \(customPlaylistID)")
            return customPlaylistID
        }
        
        // Get playlist options for this energy level
        let playlistOptions = getPlaylistOptions(for: energyLevel)
        
        // Randomly select one playlist from the options
        if let selectedPlaylist = playlistOptions.randomElement() {
            print("🎵 Selected playlist for \(energyLevel): \(selectedPlaylist)")
            return selectedPlaylist
        }
        
        // Fallback to your default playlist
        return "3M7fmKuBlyCRGDRt653zEZ"
    }
    
    private func getPlaylistOptions(for energyLevel: MusicEnergyLevel) -> [String] {
        switch energyLevel {
        case .low:
            return [
                "3M7fmKuBlyCRGDRt653zEZ", // Your playlist "★"
                // Add more low-energy playlist IDs here:
                // "37i9dQZF1DX0XUsuxWHRQd", // Example: Chill Vibes
                // "37i9dQZF1DX4WY4goJxj8s", // Example: Peaceful Piano
            ]
        case .medium:
            return [
                "3M7fmKuBlyCRGDRt653zEZ", // Your playlist "★"
                // Add more medium-energy playlist IDs here:
                // "37i9dQZF1DXcBWIGoYBM5M", // Example: Today's Top Hits
                // "37i9dQZF1DX0XUsuxWHRQd", // Example: Pop Hits
            ]
        case .high:
            return [
                "3M7fmKuBlyCRGDRt653zEZ", // Your playlist "★"
                // Add more high-energy playlist IDs here:
                // "37i9dQZF1DX0XUsuxWHRQd", // Example: Workout
                // "37i9dQZF1DXcBWIGoYBM5M", // Example: High Energy
            ]
        case .veryHigh:
            return [
                "3M7fmKuBlyCRGDRt653zEZ", // Your playlist "★"
                // Add more very high-energy playlist IDs here:
                // "37i9dQZF1DX0XUsuxWHRQd", // Example: Intense Workout
                // "37i9dQZF1DXcBWIGoYBM5M", // Example: Maximum Energy
            ]
        }
    }
    
    private func startSpotifyPlayback(playlistID: String, accessToken: String) {
        print("🎵 Starting Spotify playback for playlist: \(playlistID)")
        
        // First, check if there's an active device
        checkActiveDevice(accessToken: accessToken) { [weak self] hasActiveDevice in
            if !hasActiveDevice {
                self?.errorMessage = "No active Spotify device found. Please open Spotify on another device or the web player."
                return
            }
            
            self?.performPlayback(playlistID: playlistID, accessToken: accessToken)
        }
    }
    
    private func checkActiveDevice(accessToken: String, completion: @escaping (Bool) -> Void) {
        // Check cache first
        if let lastCheck = lastDeviceCheck,
           Date().timeIntervalSince(lastCheck) < deviceCacheTimeout,
           !deviceCache.isEmpty {
            let activeDevices = deviceCache.filter { $0.is_active }
            let hasActiveDevice = !activeDevices.isEmpty
            print("🎵 Using cached device data: \(deviceCache.count) total devices, \(activeDevices.count) active")
            
            if !hasActiveDevice && !deviceCache.isEmpty {
                print("🎵 No active devices found in cache, trying to activate first device...")
                activateFirstDevice(deviceCache.first!, accessToken: accessToken) { success in
                    completion(success)
                }
            } else {
                completion(hasActiveDevice)
            }
            return
        }
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/devices") else {
            completion(false)
            return
        }
        
        makeNetworkRequest(
            url: url,
            requestType: "device_check_\(accessToken.prefix(10))",
            accessToken: accessToken
        ) { [weak self] result in
            guard let strongSelf = self else {
                completion(false)
                return
            }
            
            switch result {
            case .success(let data):
                do {
                    let deviceResponse = try JSONDecoder().decode(SpotifyDevicesResponse.self, from: data)
                    // Update cache
                    strongSelf.deviceCache = deviceResponse.devices
                    strongSelf.lastDeviceCheck = Date()
                    
                    let activeDevices = deviceResponse.devices.filter { $0.is_active }
                    let hasActiveDevice = !activeDevices.isEmpty
                    print("🎵 Found \(deviceResponse.devices.count) total devices, \(activeDevices.count) active")
                    
                    // Cache the first active device ID
                    if let activeDevice = activeDevices.first {
                        strongSelf.activeDeviceID = activeDevice.id
                    }
                    
                    if !hasActiveDevice && !deviceResponse.devices.isEmpty {
                        print("🎵 No active devices found, but devices available. Trying to activate first device...")
                        strongSelf.activateFirstDevice(deviceResponse.devices.first!, accessToken: accessToken) { success in
                            completion(success)
                        }
                    } else {
                        completion(hasActiveDevice)
                    }
                } catch {
                    print("🎵 Failed to parse device response: \(error.localizedDescription)")
                    completion(false)
                }
            case .failure(let error):
                print("🎵 Error checking devices: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    private func activateFirstDevice(_ device: SpotifyDevice, accessToken: String, completion: @escaping (Bool) -> Void) {
        print("🎵 Activating device: \(device.name) (ID: \(device.id))")
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let activateRequest = SpotifyTransferRequest(device_ids: [device.id])
        
        do {
            request.httpBody = try JSONEncoder().encode(activateRequest)
            print("🎵 Device activation request: \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")
        } catch {
            print("🎵 Failed to encode device activation request: \(error.localizedDescription)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🎵 Device activation error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🎵 Device activation response: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 204 {
                        print("🎵 Device activated successfully!")
                        // Wait a moment for the device to become active
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            completion(true)
                        }
                    } else {
                        print("🎵 Device activation failed with status: \(httpResponse.statusCode)")
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func performPlayback(playlistID: String, accessToken: String) {
        // Prevent duplicate playback requests
        let requestKey = "playback_\(playlistID)"
        if pendingRequests.contains(requestKey) {
            print("🎵 Playback request already in progress for playlist: \(playlistID)")
            return
        }
        pendingRequests.insert(requestKey)
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/play") else {
            print("🎵 Invalid Spotify playback URL")
            errorMessage = "Invalid Spotify playback URL"
            pendingRequests.remove(requestKey)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0 // Add timeout
        
        // Optimize request body - use simpler structure when possible
        let requestBody: SpotifyPlaybackRequestWithDevice
        if let deviceID = activeDeviceID {
            // Use cached device ID if available
            requestBody = SpotifyPlaybackRequestWithDevice(
                context_uri: "spotify:playlist:\(playlistID)",
                offset: ["position": 0],
                position_ms: 0,
                device_id: deviceID
            )
        } else {
            requestBody = SpotifyPlaybackRequestWithDevice(
                context_uri: "spotify:playlist:\(playlistID)",
                offset: ["position": 0],
                position_ms: 0
            )
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            print("🎵 Playback request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")
        } catch {
            print("🎵 Failed to encode playback request: \(error.localizedDescription)")
            errorMessage = "Failed to encode playback request: \(error.localizedDescription)"
            pendingRequests.remove(requestKey)
            return
        }
        
        // Move network request to background queue
        backgroundQueue.async {
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    guard let strongSelf = self else { return }
                    
                    strongSelf.pendingRequests.remove(requestKey)
                    
                    if let error = error {
                        print("🎵 Failed to start playback: \(error.localizedDescription)")
                        strongSelf.errorMessage = "Failed to start playback: \(error.localizedDescription)"
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        print("🎵 Spotify playback response: \(httpResponse.statusCode)")
                        
                        if httpResponse.statusCode == 404 {
                            print("🎵 Playlist not found (404). Playlist ID: \(playlistID)")
                            // Try to verify the playlist exists by fetching its details
                            strongSelf.verifyPlaylistExists(playlistID: playlistID, accessToken: accessToken)
                            return
                        } else if httpResponse.statusCode == 403 {
                            print("🎵 Forbidden (403). Check if you have Spotify Premium and proper permissions.")
                            strongSelf.errorMessage = "Access denied. Please ensure you have Spotify Premium and the playlist is accessible."
                            return
                        } else if httpResponse.statusCode == 401 {
                            print("🎵 Unauthorized (401). Token may be expired.")
                            strongSelf.errorMessage = "Authentication failed. Please reconnect to Spotify."
                            // Try to refresh the token
                            strongSelf.spotifyManager.refreshAccessToken()
                            return
                        } else if httpResponse.statusCode == 204 {
                            print("🎵 Music started successfully!")
                            strongSelf.isPlaying = true
                            strongSelf.isPaused = false
                            strongSelf.errorMessage = nil
                        } else {
                            print("🎵 Unexpected response code: \(httpResponse.statusCode)")
                            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                                print("🎵 Response body: \(responseString)")
                            }
                            strongSelf.errorMessage = "Unexpected response from Spotify: \(httpResponse.statusCode)"
                            return
                        }
                    }
                }
            }.resume()
        }
    }
    
    private func verifyPlaylistExists(playlistID: String, accessToken: String) {
        print("🎵 Verifying playlist exists: \(playlistID)")
        
        guard let url = URL(string: "https://api.spotify.com/v1/playlists/\(playlistID)") else {
            self.errorMessage = "Invalid playlist URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("🎵 Error verifying playlist: \(error.localizedDescription)")
                    self.errorMessage = "Failed to verify playlist: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🎵 Playlist verification response: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        print("🎵 Playlist exists but playback failed. Trying alternative approach...")
                        self.tryAlternativePlayback(playlistID: playlistID, accessToken: accessToken)
                    } else if httpResponse.statusCode == 404 {
                        print("🎵 Playlist does not exist or is not accessible to this account")
                        self.errorMessage = "Playlist not found or not accessible. Trying to find a working playlist..."
                        // Try to find a working playlist
                        self.findWorkingPlaylist(accessToken: accessToken)
                    } else if httpResponse.statusCode == 403 {
                        print("🎵 Playlist is private or restricted")
                        self.errorMessage = "Playlist is private or restricted. Please use a public playlist or one you own."
                    } else {
                        print("🎵 Unexpected response when verifying playlist: \(httpResponse.statusCode)")
                        if let data = data, let responseString = String(data: data, encoding: .utf8) {
                            print("🎵 Response body: \(responseString)")
                        }
                        self.errorMessage = "Failed to access playlist. Please try a different playlist."
                    }
                }
            }
        }.resume()
    }
    
    private func tryAlternativePlayback(playlistID: String, accessToken: String) {
        print("🎵 Trying alternative playback method...")
        
        // Try a simpler approach first - just retry the playback
        print("🎵 Retrying playback with original method...")
        performPlayback(playlistID: playlistID, accessToken: accessToken)
        
        // If that fails, try device transfer
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            print("🎵 If playback still failed, trying device transfer...")
            self?.transferPlaybackToActiveDevice(accessToken: accessToken) { success in
                if success {
                    print("🎵 Device transfer successful, retrying playback...")
                    self?.performPlayback(playlistID: playlistID, accessToken: accessToken)
                } else {
                    print("🎵 Device transfer failed, trying direct playback...")
                    self?.tryDirectPlayback(playlistID: playlistID, accessToken: accessToken)
                }
            }
        }
    }
    
    private func tryDirectPlayback(playlistID: String, accessToken: String) {
        print("🎵 Trying direct playback without device transfer...")
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/play") else {
            errorMessage = "Invalid playback URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Use the simplest possible request
        let requestBody = SpotifyPlaybackRequest(context_uri: "spotify:playlist:\(playlistID)")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            print("🎵 Direct playback request: \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")
        } catch {
            print("🎵 Failed to encode direct playback request: \(error.localizedDescription)")
            errorMessage = "Failed to encode playback request"
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("🎵 Direct playback error: \(error.localizedDescription)")
                    self.errorMessage = "Playback failed: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🎵 Direct playback response: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 204 {
                        print("🎵 Direct playback successful!")
                        self.isPlaying = true
                        self.isPaused = false
                        self.errorMessage = nil
                    } else {
                        print("🎵 Direct playback failed with status: \(httpResponse.statusCode)")
                        if let data = data, let responseString = String(data: data, encoding: .utf8) {
                            print("🎵 Response body: \(responseString)")
                        }
                        self.errorMessage = "No active Spotify device found. Please open Spotify on your phone, computer, or web player and try again."
                    }
                }
            }
        }.resume()
    }
    
    private func transferPlaybackToActiveDevice(accessToken: String, completion: @escaping (Bool) -> Void) {
        // Get the device list first
        getDeviceList(accessToken: accessToken) { [weak self] deviceID in
            guard let _ = self, let deviceID = deviceID else {
                print("🎵 No active device found for transfer")
                completion(false)
                return
            }
            
            print("🎵 Transferring playback to device: \(deviceID)")
            
            guard let url = URL(string: "https://api.spotify.com/v1/me/player") else {
                completion(false)
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let transferRequest = SpotifyTransferRequest(device_ids: [deviceID])
            
            do {
                request.httpBody = try JSONEncoder().encode(transferRequest)
                print("🎵 Transfer request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")
                
                URLSession.shared.dataTask(with: request) { _, response, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("🎵 Transfer error: \(error.localizedDescription)")
                            completion(false)
                            return
                        }
                        
                        if let httpResponse = response as? HTTPURLResponse {
                            print("🎵 Transfer response: \(httpResponse.statusCode)")
                            completion(httpResponse.statusCode == 204)
                        } else {
                            completion(false)
                        }
                    }
                }.resume()
            } catch {
                print("🎵 Failed to encode transfer request: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    private func getDeviceList(accessToken: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/devices") else {
            completion(nil)
            return
        }
        
        makeNetworkRequest(
            url: url,
            requestType: "get_device_list",
            accessToken: accessToken
        ) { result in
            switch result {
            case .success(let data):
                do {
                    let deviceResponse = try JSONDecoder().decode(SpotifyDevicesResponse.self, from: data)
                    let activeDevice = deviceResponse.devices.first { $0.is_active }
                    completion(activeDevice?.id)
                } catch {
                    print("🎵 Failed to parse device list: \(error.localizedDescription)")
                    completion(nil)
                }
            case .failure(let error):
                print("🎵 Error getting device list: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    private func findWorkingPlaylist(accessToken: String) {
        print("🎵 Searching for a working playlist...")
        
        // First try to get user's own playlists
        guard let url = URL(string: "https://api.spotify.com/v1/me/playlists?limit=20") else {
            self.errorMessage = "Failed to access your playlists. Please try reconnecting to Spotify."
            return
        }
        
        makeNetworkRequest(
            url: url,
            requestType: "find_working_playlist",
            accessToken: accessToken
        ) { [weak self] result in
            guard let strongSelf = self else { return }
            
            switch result {
            case .success(let data):
                do {
                    let userPlaylists = try JSONDecoder().decode(SpotifyUserPlaylistsResponse.self, from: data)
                    if let firstPlaylist = userPlaylists.items.first {
                        print("🎵 Found user playlist: \(firstPlaylist.name) (ID: \(firstPlaylist.id))")
                        strongSelf.setCustomPlaylistID(firstPlaylist.id)
                        strongSelf.performPlayback(playlistID: firstPlaylist.id, accessToken: accessToken)
                    } else {
                        print("🎵 No user playlists found, trying search...")
                        strongSelf.searchForWorkingPlaylist(accessToken: accessToken)
                    }
                } catch {
                    print("🎵 Failed to parse user playlists: \(error.localizedDescription)")
                    strongSelf.searchForWorkingPlaylist(accessToken: accessToken)
                }
            case .failure(let error):
                print("🎵 Error getting user playlists: \(error.localizedDescription)")
                strongSelf.errorMessage = "Failed to get your playlists. Please try reconnecting to Spotify."
                strongSelf.searchForWorkingPlaylist(accessToken: accessToken)
            }
        }
    }
    
    private func searchForWorkingPlaylist(accessToken: String) {
        print("🎵 Searching for public workout playlists...")
        
        guard let encodedQuery = "workout fitness".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=playlist&limit=10") else {
            self.errorMessage = "Failed to search for playlists. Please try reconnecting to Spotify."
            return
        }
        
        makeNetworkRequest(
            url: url,
            requestType: "search_working_playlist",
            accessToken: accessToken
        ) { [weak self] result in
            guard let strongSelf = self else { return }
            
            switch result {
            case .success(let data):
                do {
                    let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
                    if let firstPlaylist = searchResponse.playlists.items.first {
                        print("🎵 Found public playlist: \(firstPlaylist.name) (ID: \(firstPlaylist.id))")
                        strongSelf.setCustomPlaylistID(firstPlaylist.id)
                        strongSelf.performPlayback(playlistID: firstPlaylist.id, accessToken: accessToken)
                    } else {
                        strongSelf.errorMessage = "No accessible playlists found. Please create a playlist in Spotify and try again."
                    }
                } catch {
                    print("🎵 Failed to parse search results: \(error.localizedDescription)")
                    strongSelf.errorMessage = "Failed to find working playlists. Please try reconnecting to Spotify."
                }
            case .failure(let error):
                print("🎵 Error searching playlists: \(error.localizedDescription)")
                strongSelf.errorMessage = "Failed to search for playlists. Please try reconnecting to Spotify."
            }
        }
    }
    
    private func pauseSpotifyPlayback() {
        guard let accessToken = spotifyManager.accessToken else { return }
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/pause") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    private func resumeSpotifyPlayback() {
        guard let accessToken = spotifyManager.accessToken else { return }
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/play") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    private func stopSpotifyPlayback() {
        guard let accessToken = spotifyManager.accessToken else { return }
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/pause") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    private func setSpotifyVolume(_ volume: Float) {
        guard spotifyManager.accessToken != nil else { return }
        
        // Throttle volume changes to avoid API spam during fade
        let volumePercent = Int(volume * 100)
        
        print("🎵 Setting Spotify volume: \(volume) (\(volumePercent)%)")
        
        // Skip API call only if volume change is extremely minimal (less than 1%)
        if abs(volume - (self.volume)) < 0.01 {
            print("🎵 Skipping volume change - too small: \(abs(volume - (self.volume)))")
            return
        }
        
        setSpotifyVolumeDirectly(volume)
    }
    
    private func setSpotifyVolumeDirectly(_ volume: Float) {
        guard let accessToken = spotifyManager.accessToken else { return }
        
        let volumePercent = Int(volume * 100)
        print("🎵 Setting Spotify volume directly: \(volume) (\(volumePercent)%)")
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/volume?volume_percent=\(volumePercent)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5.0 // Shorter timeout for volume changes
        
        // Move volume change to background queue
        backgroundQueue.async {
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    print("🎵 Volume change error: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode != 204 {
                        print("🎵 Volume change failed with status: \(httpResponse.statusCode)")
                    } else {
                        print("🎵 Volume change successful: \(volumePercent)%")
                    }
                }
            }.resume()
        }
    }
}

// MARK: - Data Models

enum MusicEnergyLevel: CaseIterable {
    case low
    case medium
    case high
    case veryHigh
    
    func increase() -> MusicEnergyLevel {
        switch self {
        case .low: return .medium
        case .medium: return .high
        case .high: return .veryHigh
        case .veryHigh: return .veryHigh
        }
    }
    
    func decrease() -> MusicEnergyLevel {
        switch self {
        case .low: return .low
        case .medium: return .low
        case .high: return .medium
        case .veryHigh: return .high
        }
    }
}

struct SpotifyTrack: Codable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    let duration_ms: Int
    let preview_url: String?
}

struct SpotifyArtist: Codable {
    let id: String
    let name: String
}

struct SpotifyAlbum: Codable {
    let id: String
    let name: String
    let images: [SpotifyImage]
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int
    let width: Int
}

struct SpotifyPlaybackRequest: Codable {
    let context_uri: String
}

struct SpotifyPlaybackRequestWithDevice: Codable {
    let context_uri: String
    let offset: [String: Int]
    let position_ms: Int
    let device_id: String?
    
    init(context_uri: String, offset: [String: Int], position_ms: Int, device_id: String? = nil) {
        self.context_uri = context_uri
        self.offset = offset
        self.position_ms = position_ms
        self.device_id = device_id
    }
}

struct SpotifyDevicesResponse: Codable {
    let devices: [SpotifyDevice]
}

struct SpotifyDevice: Codable {
    let id: String
    let is_active: Bool
    let is_private_session: Bool
    let is_restricted: Bool
    let name: String
    let type: String
    let volume_percent: Int
}

struct SpotifyTransferRequest: Codable {
    let device_ids: [String]
}

struct SpotifySearchResponse: Codable {
    let playlists: SpotifyPlaylistSearchResult
}

struct SpotifyPlaylistSearchResult: Codable {
    let items: [SpotifyPlaylistInfo]
}

struct SpotifyPlaylistInfo: Codable {
    let id: String
    let name: String
    let description: String?
    let external_urls: SpotifyExternalURLs
    let owner: SpotifyPlaylistOwner
    let `public`: Bool
}

struct SpotifyExternalURLs: Codable {
    let spotify: String
}

struct SpotifyPlaylistOwner: Codable {
    let display_name: String
}

struct SpotifyUserPlaylistsResponse: Codable {
    let items: [SpotifyPlaylistInfo]
}

// MARK: - Network Error Types

enum NetworkError: Error, LocalizedError {
    case noConnectivity
    case noData
    case maxRetriesReached
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noConnectivity:
            return "No network connectivity"
        case .noData:
            return "No data received"
        case .maxRetriesReached:
            return "Maximum retry attempts reached"
        case .unknown:
            return "Unknown network error"
        }
    }
}

// MARK: - Extensions

// MARK: - WKNavigationDelegate


// MARK: - Notifications

extension Notification.Name {
    static let voiceManagerSpeaking = Notification.Name("voiceManagerSpeaking")
}

