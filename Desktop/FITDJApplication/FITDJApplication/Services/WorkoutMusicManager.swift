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

// F-004 & F-006: Music management with ducking for trainer voice
@MainActor
class WorkoutMusicManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentTrack: SpotifyTrack?
    @Published var volume: Float = 0.7
    @Published var errorMessage: String?
    
    private let spotifyManager: SpotifyManager
    private let soundCloudManager: SoundCloudManager
#if canImport(AVFoundation)
    private var audioSession = AVAudioSession.sharedInstance()
#endif
    private var cancellables = Set<AnyCancellable>()
    
    // Music ducking settings
    private let normalVolume: Float = 0.7
    private let duckedVolume: Float = 0.2
    private var isDucked = false
    
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
    
    init(spotifyManager: SpotifyManager) {
        self.spotifyManager = spotifyManager
        self.soundCloudManager = SoundCloudManager()
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
    }
    
    // MARK: - Public Methods
    
    func startWorkoutMusic(for workout: Workout, userPreference: MusicPreference) {
        print("🎵 Starting workout music for: \(workout.title)")
        
        // Add a small delay to ensure Spotify manager is fully initialized
        // and to allow voice system to set up first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            guard self.spotifyManager.isConnected else {
                print("🎵 Spotify not connected. Workout will continue without music.")
                self.errorMessage = "Spotify not connected. Workout will continue without music."
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
            print("🎵 Playing playlist for energy level: \(energyLevel)")
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
        
        // Adjust ducking based on cue type
        let targetVolume: Float
        let fadeSpeed: TimeInterval
        
        switch cueType {
        case "instruction":
            // Instructions need more ducking for clarity
            targetVolume = duckedVolume * 0.7 // Even lower for instructions
            fadeSpeed = 0.3 // Faster fade for instructions
        case "countdown":
            // Countdowns need moderate ducking
            targetVolume = duckedVolume
            fadeSpeed = 0.4
        case "motivation":
            // Motivational cues can have less ducking
            targetVolume = duckedVolume * 1.2
            fadeSpeed = 0.5
        case "transition":
            // Transitions need moderate ducking
            targetVolume = duckedVolume
            fadeSpeed = 0.4
        default:
            targetVolume = duckedVolume
            fadeSpeed = 0.5
        }
        
        print("🎵 Ducking for \(cueType): volume=\(targetVolume), speed=\(fadeSpeed)s")
        isDucked = true
        
        // Use custom fade speed for this ducking
        fadeToVolumeWithSpeed(targetVolume, duration: fadeSpeed)
    }
    
    private func unduckMusicAfterVoice() {
        guard isDucked else { return }
        
        print("🎵 Unducking music after voice")
        isDucked = false
        
        // Slightly slower fade back to normal volume for smoother transition
        fadeToVolumeWithSpeed(normalVolume, duration: 0.8)
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
    
    // MARK: - SoundCloud Methods
    
    func addSoundCloudURL(_ urlString: String) -> Bool {
        guard soundCloudManager.validateSoundCloudURL(urlString) else {
            errorMessage = "Invalid SoundCloud URL. Please provide a valid SoundCloud link."
            return false
        }
        
        guard let track = soundCloudManager.parseSoundCloudURL(urlString) else {
            errorMessage = "Failed to parse SoundCloud URL. Please check the link and try again."
            return false
        }
        
        soundCloudManager.addSoundCloudTrackToPlaylist(track, playlistID: "soundcloud_playlist")
        print("🎵 Added SoundCloud track: \(track.title)")
        return true
    }
    
    func getSoundCloudTracks() -> [SoundCloudTrack] {
        return soundCloudManager.getStoredSoundCloudTracks()
    }
    
    func removeSoundCloudTrack(_ trackID: String) {
        soundCloudManager.removeSoundCloudTrack(trackID)
    }
    
    func clearSoundCloudTracks() {
        soundCloudManager.clearAllSoundCloudTracks()
    }
    
    func parseSoundCloudURLFromText(_ text: String) -> [SoundCloudTrack] {
        let urls = soundCloudManager.extractAllSoundCloudURLs(from: text)
        var tracks: [SoundCloudTrack] = []
        
        for url in urls {
            if let track = soundCloudManager.parseSoundCloudURL(url) {
                tracks.append(track)
            }
        }
        
        return tracks
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
        
        // Prevent duplicate search requests
        let requestKey = "search_playlists"
        if pendingRequests.contains(requestKey) {
            print("🎵 Search request already in progress, skipping duplicate")
            return
        }
        pendingRequests.insert(requestKey)
        
        // Search for workout playlists with optimized query
        let query = "workout fitness"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=playlist&limit=20") else {
            pendingRequests.remove(requestKey)
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0
        
        // Move search to background queue
        backgroundQueue.async {
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    guard let strongSelf = self else {
                        completion([])
                        return
                    }
                    
                    strongSelf.pendingRequests.remove(requestKey)
                    
                    if let error = error {
                        print("🎵 Error searching playlists: \(error.localizedDescription)")
                        completion([])
                        return
                    }
                    
                    guard let data = data else {
                        completion([])
                        return
                    }
                    
                    do {
                        let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
                        completion(searchResponse.playlists.items)
                    } catch {
                        print("🎵 Failed to parse search response: \(error.localizedDescription)")
                        completion([])
                    }
                }
            }.resume()
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
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let newVolume = startVolume + (stepSize * Float(currentStep))
            
            // Clamp volume to valid range
            let clampedVolume = max(0.0, min(1.0, newVolume))
            
            // Only update volume every few steps to reduce API calls during fade
            if currentStep % 3 == 0 || currentStep >= self.fadeSteps {
                print("🎵 Fade step \(currentStep)/\(self.fadeSteps): volume = \(clampedVolume)")
                
                // Update local volume and Spotify volume on main thread
                Task { @MainActor in
                    self.volume = clampedVolume
                    self.setSpotifyVolume(clampedVolume)
                }
            } else {
                // Update local volume without API call for intermediate steps
                Task { @MainActor in
                    self.volume = clampedVolume
                }
            }
            
            // Check if we've reached the target or completed all steps
            if currentStep >= self.fadeSteps || abs(clampedVolume - targetVolume) < 0.01 {
                // Ensure we end exactly at target volume
                Task { @MainActor in
                    self.volume = targetVolume
                    self.setSpotifyVolume(targetVolume)
                    print("🎵 Fade complete: final volume = \(targetVolume)")
                    timer.invalidate()
                    self.fadeTimer = nil
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
#if canImport(AVFoundation)
        do {
            // Set up audio session that works well with voice system
            // Use playAndRecord to allow both music and voice
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .allowAirPlay, .allowBluetoothHFP, .defaultToSpeaker])
            try audioSession.setActive(true)
            print("🎵 Music audio session configured to work with voice system")
        } catch {
            print("❌ Music audio session setup failed: \(error.localizedDescription)")
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
        }
#endif
    }
    
    private func configureAudioSessionForMusic() {
#if canImport(AVFoundation)
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
        
        // Prevent duplicate requests
        let requestKey = "device_check_\(accessToken.prefix(10))"
        if pendingRequests.contains(requestKey) {
            print("🎵 Device check already in progress, skipping duplicate request")
            return
        }
        pendingRequests.insert(requestKey)
        
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/devices") else {
            pendingRequests.remove(requestKey)
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0 // Add timeout
        
        // Move network request to background queue
        backgroundQueue.async {
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    guard let strongSelf = self else {
                        completion(false)
                        return
                    }
                    
                    strongSelf.pendingRequests.remove(requestKey)
                    
                    if let error = error {
                        print("🎵 Error checking devices: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    guard let data = data else {
                        print("🎵 No device data received")
                        completion(false)
                        return
                    }
                    
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
                }
            }.resume()
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
                            self.verifyPlaylistExists(playlistID: playlistID, accessToken: accessToken)
                            return
                        } else if httpResponse.statusCode == 403 {
                            print("🎵 Forbidden (403). Check if you have Spotify Premium and proper permissions.")
                            self.errorMessage = "Access denied. Please ensure you have Spotify Premium and the playlist is accessible."
                            return
                        } else if httpResponse.statusCode == 401 {
                            print("🎵 Unauthorized (401). Token may be expired.")
                            self.errorMessage = "Authentication failed. Please reconnect to Spotify."
                            // Try to refresh the token
                            self.spotifyManager.refreshAccessToken()
                            return
                        } else if httpResponse.statusCode == 204 {
                            print("🎵 Music started successfully!")
                            self.isPlaying = true
                            self.isPaused = false
                            self.errorMessage = nil
                        } else {
                            print("🎵 Unexpected response code: \(httpResponse.statusCode)")
                            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                                print("🎵 Response body: \(responseString)")
                            }
                            self.errorMessage = "Unexpected response from Spotify: \(httpResponse.statusCode)"
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
            guard let self = self, let deviceID = deviceID else {
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
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🎵 Error getting device list: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let data = data else {
                    completion(nil)
                    return
                }
                
                do {
                    let deviceResponse = try JSONDecoder().decode(SpotifyDevicesResponse.self, from: data)
                    let activeDevice = deviceResponse.devices.first { $0.is_active }
                    completion(activeDevice?.id)
                } catch {
                    print("🎵 Failed to parse device list: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    private func findWorkingPlaylist(accessToken: String) {
        print("🎵 Searching for a working playlist...")
        
        // Prevent duplicate requests
        let requestKey = "find_working_playlist"
        if pendingRequests.contains(requestKey) {
            print("🎵 Find working playlist request already in progress")
            return
        }
        pendingRequests.insert(requestKey)
        
        // First try to get user's own playlists
        guard let url = URL(string: "https://api.spotify.com/v1/me/playlists?limit=20") else {
            self.errorMessage = "Failed to access your playlists. Please try reconnecting to Spotify."
            pendingRequests.remove(requestKey)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0
        
        // Move to background queue
        backgroundQueue.async {
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    guard let strongSelf = self else { return }
                    
                    strongSelf.pendingRequests.remove(requestKey)
                    
                    if let error = error {
                        print("🎵 Error getting user playlists: \(error.localizedDescription)")
                        self.errorMessage = "Failed to get your playlists. Please try reconnecting to Spotify."
                        return
                    }
                    
                    guard let data = data else {
                        self.errorMessage = "No playlist data received. Please try reconnecting to Spotify."
                        return
                    }
                    
                    do {
                        let userPlaylists = try JSONDecoder().decode(SpotifyUserPlaylistsResponse.self, from: data)
                        if let firstPlaylist = userPlaylists.items.first {
                            print("🎵 Found user playlist: \(firstPlaylist.name) (ID: \(firstPlaylist.id))")
                            self.setCustomPlaylistID(firstPlaylist.id)
                            self.performPlayback(playlistID: firstPlaylist.id, accessToken: accessToken)
                        } else {
                            print("🎵 No user playlists found, trying search...")
                            self.searchForWorkingPlaylist(accessToken: accessToken)
                        }
                    } catch {
                        print("🎵 Failed to parse user playlists: \(error.localizedDescription)")
                        self.searchForWorkingPlaylist(accessToken: accessToken)
                    }
                }
            }.resume()
        }
    }
    
    private func searchForWorkingPlaylist(accessToken: String) {
        print("🎵 Searching for public workout playlists...")
        
        // Prevent duplicate requests
        let requestKey = "search_working_playlist"
        if pendingRequests.contains(requestKey) {
            print("🎵 Search working playlist request already in progress")
            return
        }
        pendingRequests.insert(requestKey)
        
        guard let encodedQuery = "workout fitness".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=playlist&limit=10") else {
            self.errorMessage = "Failed to search for playlists. Please try reconnecting to Spotify."
            pendingRequests.remove(requestKey)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0
        
        // Move to background queue
        backgroundQueue.async {
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    guard let strongSelf = self else { return }
                    
                    strongSelf.pendingRequests.remove(requestKey)
                    
                    if let error = error {
                        print("🎵 Error searching playlists: \(error.localizedDescription)")
                        self.errorMessage = "Failed to search for playlists. Please try reconnecting to Spotify."
                        return
                    }
                    
                    guard let data = data else {
                        self.errorMessage = "No search results received. Please try reconnecting to Spotify."
                        return
                    }
                    
                    do {
                        let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
                        if let firstPlaylist = searchResponse.playlists.items.first {
                            print("🎵 Found public playlist: \(firstPlaylist.name) (ID: \(firstPlaylist.id))")
                            self.setCustomPlaylistID(firstPlaylist.id)
                            self.performPlayback(playlistID: firstPlaylist.id, accessToken: accessToken)
                        } else {
                            self.errorMessage = "No accessible playlists found. Please create a playlist in Spotify and try again."
                        }
                    } catch {
                        print("🎵 Failed to parse search results: \(error.localizedDescription)")
                        self.errorMessage = "Failed to find working playlists. Please try reconnecting to Spotify."
                    }
                }
            }.resume()
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
        guard let accessToken = spotifyManager.accessToken else { return }
        
        // Throttle volume changes to avoid API spam during fade
        let volumePercent = Int(volume * 100)
        
        // Skip API call if volume change is minimal
        if abs(volume - (self.volume)) < 0.05 {
            return
        }
        
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

// MARK: - Extensions

// MARK: - Notifications

extension Notification.Name {
    static let voiceManagerSpeaking = Notification.Name("voiceManagerSpeaking")
}
