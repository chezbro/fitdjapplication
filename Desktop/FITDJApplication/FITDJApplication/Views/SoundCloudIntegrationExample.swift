//
//  SoundCloudIntegrationExample.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

// Example of how to integrate SoundCloud URLs into your workout app
struct SoundCloudIntegrationExample: View {
    @State private var workoutMusicManager: WorkoutMusicManager?
    @State private var soundCloudTracks: [SoundCloudTrack] = []
    @State private var showingAddURL = false
    @State private var urlText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "music.note.house")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("SoundCloud Integration")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Add SoundCloud tracks to your workout playlists")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Quick Add Example
                VStack(spacing: 12) {
                    Text("Quick Add Example")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Button(action: {
                        addExampleSoundCloudURL()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Example SoundCloud Track")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                // SoundCloud Tracks List
                if !soundCloudTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your SoundCloud Tracks (\(soundCloudTracks.count))")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(soundCloudTracks) { track in
                            SoundCloudTrackCard(track: track) {
                                removeTrack(track.id)
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No SoundCloud tracks added yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Add SoundCloud URLs to build your custom workout playlist")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button("Add SoundCloud URL") {
                        showingAddURL = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("Clear All Tracks") {
                        clearAllTracks()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(soundCloudTracks.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("SoundCloud")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddURL) {
                SoundCloudURLInputView(
                    onURLAdded: { url in
                        addSoundCloudURL(url)
                        showingAddURL = false
                    },
                    onCancel: {
                        showingAddURL = false
                    }
                )
            }
        }
    }
    
    private func addExampleSoundCloudURL() {
        let exampleURL = "https://soundcloud.com/coredotworld/samm-at-core-medellin-2025?si=3ed0de6206814036ad3bd10893e9e429&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"
        addSoundCloudURL(exampleURL)
    }
    
    private func addSoundCloudURL(_ url: String) {
        // Create a SoundCloud track from the URL
        let track = SoundCloudTrack(
            id: UUID().uuidString,
            title: extractTitleFromURL(url),
            url: url,
            streamURL: nil,
            duration: nil,
            artworkURL: nil
        )
        
        soundCloudTracks.append(track)
    }
    
    private func removeTrack(_ trackID: String) {
        soundCloudTracks.removeAll { $0.id == trackID }
    }
    
    private func clearAllTracks() {
        soundCloudTracks.removeAll()
    }
    
    private func extractTitleFromURL(_ url: String) -> String {
        let components = url.components(separatedBy: "/")
        if let lastComponent = components.last {
            let title = lastComponent.components(separatedBy: "?")[0]
            return title.replacingOccurrences(of: "-", with: " ").capitalized
        }
        return "SoundCloud Track"
    }
}

struct SoundCloudTrackCard: View {
    let track: SoundCloudTrack
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("SoundCloud")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct SoundCloudURLInputView: View {
    @State private var urlText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let onURLAdded: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SoundCloud URL")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("https://soundcloud.com/...", text: $urlText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    
                    Text("Paste a SoundCloud URL to add it to your workout playlist")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Add to Playlist") {
                        addURL()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(!isValidURL)
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Add SoundCloud URL")
            .navigationBarTitleDisplayMode(.inline)
            .alert("SoundCloud", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var isValidURL: Bool {
        !urlText.isEmpty && urlText.contains("soundcloud.com")
    }
    
    private func addURL() {
        guard !urlText.isEmpty else {
            alertMessage = "Please enter a SoundCloud URL"
            showingAlert = true
            return
        }
        
        guard urlText.contains("soundcloud.com") else {
            alertMessage = "Please enter a valid SoundCloud URL"
            showingAlert = true
            return
        }
        
        onURLAdded(urlText)
    }
}

#Preview {
    SoundCloudIntegrationExample()
}
