//
//  SoundCloudManager.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import Combine
#if canImport(AVFoundation)
import AVFoundation
#endif

// SoundCloud URL parsing and management
@MainActor
class SoundCloudManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    
    func parseSoundCloudURL(_ urlString: String) -> SoundCloudTrack? {
        guard let url = URL(string: urlString),
              url.host?.contains("soundcloud.com") == true else {
            errorMessage = "Invalid SoundCloud URL"
            return nil
        }
        
        // Extract track information from URL
        let trackID = extractTrackID(from: urlString)
        let trackTitle = extractTrackTitle(from: urlString)
        
        return SoundCloudTrack(
            id: trackID,
            title: trackTitle,
            url: urlString,
            streamURL: nil, // Will be resolved when needed
            duration: nil,
            artworkURL: nil
        )
    }
    
    func validateSoundCloudURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.host?.contains("soundcloud.com") == true
    }
    
    func addSoundCloudTrackToPlaylist(_ track: SoundCloudTrack, playlistID: String) {
        // Store SoundCloud track in UserDefaults for now
        // In a real implementation, you'd want to store this in a proper database
        var soundCloudTracks = getStoredSoundCloudTracks()
        soundCloudTracks.append(track)
        storeSoundCloudTracks(soundCloudTracks)
        
        print("🎵 Added SoundCloud track to playlist: \(track.title)")
    }
    
    func getStoredSoundCloudTracks() -> [SoundCloudTrack] {
        guard let data = UserDefaults.standard.data(forKey: "soundcloud_tracks"),
              let tracks = try? JSONDecoder().decode([SoundCloudTrack].self, from: data) else {
            return []
        }
        return tracks
    }
    
    func removeSoundCloudTrack(_ trackID: String) {
        var tracks = getStoredSoundCloudTracks()
        tracks.removeAll { $0.id == trackID }
        storeSoundCloudTracks(tracks)
    }
    
    func clearAllSoundCloudTracks() {
        UserDefaults.standard.removeObject(forKey: "soundcloud_tracks")
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
#if canImport(AVFoundation)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
            print("🎵 SoundCloud audio session configured")
        } catch {
            print("❌ SoundCloud audio session setup failed: \(error.localizedDescription)")
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
        }
#endif
    }
    
    private func extractTrackID(from urlString: String) -> String {
        // Extract a unique identifier from the SoundCloud URL
        // This is a simplified approach - in reality, you'd need to make API calls to SoundCloud
        let components = urlString.components(separatedBy: "/")
        if let lastComponent = components.last {
            let trackID = lastComponent.components(separatedBy: "?")[0]
            return trackID.isEmpty ? UUID().uuidString : trackID
        }
        return UUID().uuidString
    }
    
    private func extractTrackTitle(from urlString: String) -> String {
        // Extract title from URL path
        let components = urlString.components(separatedBy: "/")
        if let lastComponent = components.last {
            let title = lastComponent.components(separatedBy: "?")[0]
            return title.replacingOccurrences(of: "-", with: " ").capitalized
        }
        return "SoundCloud Track"
    }
    
    private func storeSoundCloudTracks(_ tracks: [SoundCloudTrack]) {
        if let data = try? JSONEncoder().encode(tracks) {
            UserDefaults.standard.set(data, forKey: "soundcloud_tracks")
        }
    }
}

// MARK: - Data Models

struct SoundCloudTrack: Codable, Identifiable {
    let id: String
    let title: String
    let url: String
    let streamURL: String?
    let duration: TimeInterval?
    let artworkURL: String?
    
    init(id: String, title: String, url: String, streamURL: String? = nil, duration: TimeInterval? = nil, artworkURL: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.streamURL = streamURL
        self.duration = duration
        self.artworkURL = artworkURL
    }
}

// MARK: - URL Parsing Extensions

extension SoundCloudManager {
    func parseSoundCloudURLFromComment(_ comment: String) -> SoundCloudTrack? {
        // Look for SoundCloud URLs in comments/text
        let pattern = #"https?://(?:www\.)?soundcloud\.com/[^\s]+"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: comment.utf16.count)
        
        if let match = regex?.firstMatch(in: comment, options: [], range: range),
           let urlRange = Range(match.range, in: comment) {
            let urlString = String(comment[urlRange])
            return parseSoundCloudURL(urlString)
        }
        
        return nil
    }
    
    func extractAllSoundCloudURLs(from text: String) -> [String] {
        let pattern = #"https?://(?:www\.)?soundcloud\.com/[^\s]+"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: text.utf16.count)
        
        var urls: [String] = []
        regex?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match = match,
               let urlRange = Range(match.range, in: text) {
                urls.append(String(text[urlRange]))
            }
        }
        
        return urls
    }
}
