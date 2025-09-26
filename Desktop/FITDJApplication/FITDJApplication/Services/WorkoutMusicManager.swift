//
//  WorkoutMusicManager.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import Combine
import AVFoundation

// F-004 & F-006: Music management with ducking for trainer voice
@MainActor
class WorkoutMusicManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentTrack: SpotifyTrack?
    @Published var volume: Float = 0.7
    @Published var errorMessage: String?
    
    private let spotifyManager: SpotifyManager
    private var audioSession = AVAudioSession.sharedInstance()
    private var cancellables = Set<AnyCancellable>()
    
    // Music ducking settings
    private let normalVolume: Float = 0.7
    private let duckedVolume: Float = 0.2
    private var isDucked = false
    
    init(spotifyManager: SpotifyManager) {
        self.spotifyManager = spotifyManager
        super.init()
        setupAudioSession()
        setupVolumeObserver()
    }
    
    // MARK: - Public Methods
    
    func startWorkoutMusic(for workout: Workout, userPreference: MusicPreference) {
        print("🎵 Starting workout music for: \(workout.title)")
        
        guard spotifyManager.isConnected else {
            print("🎵 Spotify not connected. Workout will continue without music.")
            errorMessage = "Spotify not connected. Workout will continue without music."
            isPlaying = false
            isPaused = false
            return
        }
        
        guard spotifyManager.accessToken != nil else {
            print("🎵 No Spotify access token available")
            errorMessage = "No Spotify access token available"
            isPlaying = false
            isPaused = false
            return
        }
        
        let energyLevel = getEnergyLevel(for: workout, userPreference: userPreference)
        print("🎵 Playing playlist for energy level: \(energyLevel)")
        playWorkoutPlaylist(energyLevel: energyLevel)
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
        
        isDucked = true
        volume = duckedVolume
        setSpotifyVolume(duckedVolume)
    }
    
    func unduckMusic() {
        guard isDucked else { return }
        
        isDucked = false
        volume = normalVolume
        setSpotifyVolume(normalVolume)
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
        
        // Search for workout playlists
        let query = "workout"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=playlist&limit=20") else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
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
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            // Don't set up audio session here - let VoiceManager handle it
            // Just ensure we can work with the existing session
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
    
    private func setupVolumeObserver() {
        // Monitor for voice manager speaking state
        NotificationCenter.default.publisher(for: .voiceManagerSpeaking)
            .sink { [weak self] notification in
                if let isSpeaking = notification.object as? Bool {
                    if isSpeaking {
                        self?.duckMusic()
                    } else {
                        self?.unduckMusic()
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
        
        // Fallback to default playlists - using your own playlist
        switch energyLevel {
        case .low:
            return "0G9fShP6vrHkdhar2f9ZHx" // Your playlist "★"
        case .medium:
            return "0G9fShP6vrHkdhar2f9ZHx" // Your playlist "★"
        case .high:
            return "0G9fShP6vrHkdhar2f9ZHx" // Your playlist "★"
        case .veryHigh:
            return "0G9fShP6vrHkdhar2f9ZHx" // Your playlist "★"
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
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/devices") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
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
                    let activeDevices = deviceResponse.devices.filter { $0.is_active }
                    let hasActiveDevice = !activeDevices.isEmpty
                    print("🎵 Found \(deviceResponse.devices.count) total devices, \(activeDevices.count) active")
                    
                    if !hasActiveDevice && !deviceResponse.devices.isEmpty {
                        print("🎵 No active devices found, but devices available. Trying to activate first device...")
                        self.activateFirstDevice(deviceResponse.devices.first!, accessToken: accessToken) { success in
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
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/play") else {
            print("🎵 Invalid Spotify playback URL")
            errorMessage = "Invalid Spotify playback URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Try a different approach - use the device_id parameter
        let requestBody = SpotifyPlaybackRequestWithDevice(
            context_uri: "spotify:playlist:\(playlistID)",
            offset: ["position": 0],
            position_ms: 0
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            print("🎵 Playback request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")
        } catch {
            print("🎵 Failed to encode playback request: \(error.localizedDescription)")
            errorMessage = "Failed to encode playback request: \(error.localizedDescription)"
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("🎵 Failed to start playback: \(error.localizedDescription)")
                    self.errorMessage = "Failed to start playback: \(error.localizedDescription)"
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
        
        // First try to get user's own playlists
        guard let url = URL(string: "https://api.spotify.com/v1/me/playlists?limit=20") else {
            self.errorMessage = "Failed to access your playlists. Please try reconnecting to Spotify."
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
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
    
    private func searchForWorkingPlaylist(accessToken: String) {
        print("🎵 Searching for public workout playlists...")
        
        guard let encodedQuery = "workout".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=playlist&limit=10") else {
            self.errorMessage = "Failed to search for playlists. Please try reconnecting to Spotify."
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
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
        
        let volumePercent = Int(volume * 100)
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/volume?volume_percent=\(volumePercent)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request).resume()
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
