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
        guard spotifyManager.isConnected else {
            print("🎵 Spotify not connected. Workout will continue without music.")
            errorMessage = "Spotify not connected. Workout will continue without music."
            // Set playing state to false to prevent UI issues
            isPlaying = false
            isPaused = false
            return
        }
        
        let energyLevel = getEnergyLevel(for: workout, userPreference: userPreference)
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
        // These would be actual Spotify playlist IDs for different energy levels
        switch energyLevel {
        case .low:
            return "37i9dQZF1DX0XUsuxWHRQd" // Chill workout playlist
        case .medium:
            return "37i9dQZF1DX76Wlfdnj7AP" // Medium energy playlist
        case .high:
            return "37i9dQZF1DX0XUsuxWHRQd" // High energy playlist
        case .veryHigh:
            return "37i9dQZF1DX76Wlfdnj7AP" // Very high energy playlist
        }
    }
    
    private func startSpotifyPlayback(playlistID: String, accessToken: String) {
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/play") else {
            errorMessage = "Invalid Spotify playback URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = SpotifyPlaybackRequest(
            context_uri: "spotify:playlist:\(playlistID)"
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            errorMessage = "Failed to encode playback request: \(error.localizedDescription)"
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Failed to start playback: \(error.localizedDescription)"
                    return
                }
                
                self?.isPlaying = true
                self?.isPaused = false
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

// MARK: - Extensions

// MARK: - Notifications

extension Notification.Name {
    static let voiceManagerSpeaking = Notification.Name("voiceManagerSpeaking")
}
