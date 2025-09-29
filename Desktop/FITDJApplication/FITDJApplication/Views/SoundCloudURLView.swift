//
//  SoundCloudURLView.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import SwiftUI

struct SoundCloudURLView: View {
    @State private var urlText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isAdding = false
    
    let onURLAdded: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Add SoundCloud Track")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Paste a SoundCloud URL to add it to your workout playlist")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // URL Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("SoundCloud URL")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("https://soundcloud.com/...", text: $urlText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    
                    // Example URL
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Example: https://soundcloud.com/artist/track-name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Quick Add Button for the provided URL
                VStack(spacing: 12) {
                    Text("Quick Add Example")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Button(action: {
                        let exampleURL = "https://soundcloud.com/coredotworld/samm-at-core-medellin-2025?si=3ed0de6206814036ad3bd10893e9e429&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"
                        urlText = exampleURL
                        addURL()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Example Track")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: addURL) {
                        HStack {
                            if isAdding {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text(isAdding ? "Adding..." : "Add to Playlist")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidURL ? Color.blue : Color.gray)
                        .cornerRadius(10)
                    }
                    .disabled(!isValidURL || isAdding)
                    
                    Button(action: onCancel) {
                        Text("Cancel")
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("SoundCloud")
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
        
        isAdding = true
        
        // Simulate adding process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onURLAdded(urlText)
            isAdding = false
        }
    }
}

struct SoundCloudTrackListView: View {
    @State private var tracks: [SoundCloudTrack] = []
    let onTrackRemoved: (String) -> Void
    
    var body: some View {
        NavigationView {
            List {
                if tracks.isEmpty {
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
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(tracks) { track in
                        SoundCloudTrackRow(track: track) {
                            onTrackRemoved(track.id)
                        }
                    }
                }
            }
            .navigationTitle("SoundCloud Tracks")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadTracks()
            }
        }
    }
    
    private func loadTracks() {
        // This would typically come from your WorkoutMusicManager
        // For now, we'll show a placeholder
        tracks = []
    }
}

struct SoundCloudTrackRow: View {
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
        .padding(.vertical, 4)
    }
}

#Preview {
    SoundCloudURLView(
        onURLAdded: { url in
            print("Added URL: \(url)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
