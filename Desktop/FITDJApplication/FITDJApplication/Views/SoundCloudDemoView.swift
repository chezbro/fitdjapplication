//
//  SoundCloudDemoView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

struct SoundCloudDemoView: View {
    @State private var urlText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var addedTracks: [SoundCloudTrack] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "music.note.house")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("SoundCloud Integration Demo")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Add SoundCloud URLs to your workout playlist")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // URL Input Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("SoundCloud URL")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("https://soundcloud.com/...", text: $urlText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    
                    // Example URL Button
                    Button(action: {
                        urlText = "https://soundcloud.com/coredotworld/samm-at-core-medellin-2025?si=3ed0de6206814036ad3bd10893e9e429&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Use Example URL")
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Button("Add to Playlist") {
                        addSoundCloudURL()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidURL)
                }
                .padding(.horizontal)
                
                // Added Tracks Section
                if !addedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Added Tracks (\(addedTracks.count))")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(addedTracks) { track in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("SoundCloud")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    removeTrack(track.id)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to use:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Copy a SoundCloud URL from your browser")
                        Text("2. Paste it in the text field above")
                        Text("3. Click 'Add to Playlist' to add it to your workout music")
                        Text("4. The track will be available during your workouts")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("SoundCloud Demo")
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
    
    private func addSoundCloudURL() {
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
        
        // Create a SoundCloud track from the URL
        let track = SoundCloudTrack(
            id: UUID().uuidString,
            title: extractTitleFromURL(urlText),
            url: urlText,
            streamURL: nil,
            duration: nil,
            artworkURL: nil
        )
        
        addedTracks.append(track)
        urlText = ""
        
        alertMessage = "SoundCloud track added successfully!"
        showingAlert = true
    }
    
    private func removeTrack(_ trackID: String) {
        addedTracks.removeAll { $0.id == trackID }
    }
    
    private func extractTitleFromURL(_ url: String) -> String {
        // Extract title from URL path
        let components = url.components(separatedBy: "/")
        if let lastComponent = components.last {
            let title = lastComponent.components(separatedBy: "?")[0]
            return title.replacingOccurrences(of: "-", with: " ").capitalized
        }
        return "SoundCloud Track"
    }
}

#Preview {
    SoundCloudDemoView()
}
