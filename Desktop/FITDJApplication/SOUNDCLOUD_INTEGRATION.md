# SoundCloud Integration for FITDJ Application

This document explains how to add SoundCloud URL support to your workout playlists in the FITDJ Application.

## Overview

The SoundCloud integration allows users to add SoundCloud tracks to their workout playlists by simply pasting SoundCloud URLs. This feature enhances the music experience during workouts by providing access to a vast library of SoundCloud content.

## Features

- ✅ Parse SoundCloud URLs from text
- ✅ Validate SoundCloud URLs
- ✅ Store SoundCloud tracks in playlists
- ✅ Remove tracks from playlists
- ✅ UI components for adding/managing tracks
- ✅ Integration with existing WorkoutMusicManager

## Files Added

### 1. SoundCloudManager.swift
- **Location**: `FITDJApplication/Services/SoundCloudManager.swift`
- **Purpose**: Core service for handling SoundCloud URLs and track management
- **Key Features**:
  - URL validation and parsing
  - Track storage and retrieval
  - URL extraction from text

### 2. SoundCloudURLView.swift
- **Location**: `FITDJApplication/Views/SoundCloudURLView.swift`
- **Purpose**: UI for adding SoundCloud URLs
- **Key Features**:
  - URL input field
  - Quick add example button
  - Track list display
  - Remove track functionality

### 3. SoundCloudIntegrationExample.swift
- **Location**: `FITDJApplication/Views/SoundCloudIntegrationExample.swift`
- **Purpose**: Example implementation showing how to use SoundCloud features
- **Key Features**:
  - Complete integration example
  - Track management UI
  - URL input handling

## Usage Examples

### Adding a SoundCloud URL

```swift
// Example SoundCloud URL
let soundCloudURL = "https://soundcloud.com/coredotworld/samm-at-core-medellin-2025?si=3ed0de6206814036ad3bd10893e9e429&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"

// Add to playlist
let success = workoutMusicManager.addSoundCloudURL(soundCloudURL)
if success {
    print("SoundCloud track added successfully!")
}
```

### Parsing URLs from Text

```swift
let text = "Check out this track: https://soundcloud.com/artist/track-name"
let tracks = workoutMusicManager.parseSoundCloudURLFromText(text)
// Returns array of SoundCloudTrack objects
```

### Managing Tracks

```swift
// Get all SoundCloud tracks
let tracks = workoutMusicManager.getSoundCloudTracks()

// Remove a specific track
workoutMusicManager.removeSoundCloudTrack(trackID)

// Clear all tracks
workoutMusicManager.clearSoundCloudTracks()
```

## Integration with WorkoutMusicManager

The SoundCloud functionality has been integrated into the existing `WorkoutMusicManager` class with the following new methods:

- `addSoundCloudURL(_:)` - Add a SoundCloud URL to the playlist
- `getSoundCloudTracks()` - Retrieve all SoundCloud tracks
- `removeSoundCloudTrack(_:)` - Remove a specific track
- `clearSoundCloudTracks()` - Clear all SoundCloud tracks
- `parseSoundCloudURLFromText(_:)` - Extract URLs from text

## UI Integration

The SoundCloud functionality has been added to the Settings view with a new "SoundCloud Tracks" section that includes:

- Add SoundCloud URL button
- View tracks button (shows count)
- Track management interface

## Data Models

### SoundCloudTrack

```swift
struct SoundCloudTrack: Codable, Identifiable {
    let id: String
    let title: String
    let url: String
    let streamURL: String?
    let duration: TimeInterval?
    let artworkURL: String?
}
```

## URL Format Support

The integration supports various SoundCloud URL formats:

- `https://soundcloud.com/artist/track-name`
- `https://soundcloud.com/artist/track-name?si=...`
- URLs with additional parameters and tracking codes

## Example SoundCloud URL

The provided example URL:
```
https://soundcloud.com/coredotworld/samm-at-core-medellin-2025?si=3ed0de6206814036ad3bd10893e9e429&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing
```

This URL will be parsed and added to the workout playlist, allowing users to enjoy this track during their workouts.

## Future Enhancements

Potential future improvements could include:

- Direct SoundCloud API integration for track metadata
- Playback controls for SoundCloud tracks
- Track preview functionality
- Playlist synchronization with SoundCloud
- Advanced track filtering and search

## Testing

To test the SoundCloud integration:

1. Open the Settings view
2. Navigate to the Music section
3. Use the "Add SoundCloud URL" button
4. Paste a SoundCloud URL (or use the example)
5. Verify the track appears in your playlist

## Troubleshooting

### Common Issues

1. **Invalid URL**: Ensure the URL contains "soundcloud.com"
2. **Parse Error**: Check that the URL is properly formatted
3. **Storage Issues**: Verify UserDefaults is working correctly

### Debug Information

The integration includes comprehensive logging:
- URL validation results
- Track parsing success/failure
- Storage operations
- Error messages for troubleshooting

## Conclusion

The SoundCloud integration provides a seamless way for users to add their favorite SoundCloud tracks to workout playlists, enhancing the overall fitness experience with personalized music choices.
