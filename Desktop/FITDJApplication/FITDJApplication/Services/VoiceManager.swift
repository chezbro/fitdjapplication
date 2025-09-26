//
//  VoiceManager.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import AVFoundation
import Combine

// F-005: AI voice gives instructions, countdowns, and motivation
class VoiceManager: NSObject, ObservableObject {
    @Published var isSpeaking = false
    @Published var currentCue: VoiceCue?
    @Published var errorMessage: String?
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioSession = AVAudioSession.sharedInstance()
    private var currentAudioPlayer: AVAudioPlayer?
    
    // Voice cue queuing to prevent conflicts
    private var voiceQueue: [VoiceCue] = []
    private var isProcessingVoice = false
    
    // Retry logic for ElevenLabs API failures
    private var elevenLabsRetryCount = 0
    private let maxRetries = 2
    
    // ElevenLabs API credentials from instructions.md
    private let apiKey = "sk_af34df5101d4e23cf1b8137164cf638a7a5b643674d0eedd"
    private let voiceID = "egTToTzW6GojvddLj0zd"
    private let baseURL = "https://api.elevenlabs.io/v1"
    
    override init() {
        super.init()
        setupAudioSession()
        synthesizer.delegate = self
    }
    
    // MARK: - Public Methods
    
    func speakCue(_ cue: VoiceCue) {
        print("🎤 Speaking cue: \(cue.text)")
        
        // Queue the voice cue to prevent conflicts
        queueVoiceCue(cue)
    }
    
    func speakText(_ text: String, type: VoiceCueType = .instruction) {
        let cue = VoiceCue(
            id: UUID().uuidString,
            text: text,
            timing: 0,
            type: type
        )
        speakCue(cue)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        currentCue = nil
    }
    
    func pauseSpeaking() {
        synthesizer.pauseSpeaking(at: .immediate)
    }
    
    func resumeSpeaking() {
        synthesizer.continueSpeaking()
    }
    
    // MARK: - Debug Methods
    
    func enableElevenLabsDebugging() {
        UserDefaults.standard.set(false, forKey: "skipElevenLabs")
        print("🎤 ElevenLabs debugging enabled - API calls will be attempted")
    }
    
    func disableElevenLabsDebugging() {
        UserDefaults.standard.set(true, forKey: "skipElevenLabs")
        print("🎤 ElevenLabs debugging disabled - will use system voice only")
    }
    
    func testElevenLabsConnection() {
        print("🎤 ===== ELEVENLABS CONNECTION TEST =====")
        print("🎤 Testing ElevenLabs API connection...")
        
        // Test with a simple request
        speakText("Hello, this is a test of the ElevenLabs voice system.")
    }
    
    func printDebugInfo() {
        print("🎤 ===== VOICE MANAGER DEBUG INFO =====")
        print("🎤 ElevenLabs API Key: \(apiKey.prefix(10))...\(apiKey.suffix(4))")
        print("🎤 ElevenLabs Voice ID: \(voiceID)")
        print("🎤 ElevenLabs Base URL: \(baseURL)")
        print("🎤 Skip ElevenLabs: \(UserDefaults.standard.bool(forKey: "skipElevenLabs"))")
        print("🎤 Audio session category: \(audioSession.category.rawValue)")
        print("🎤 Audio session mode: \(audioSession.mode.rawValue)")
        print("🎤 Audio session active: \(audioSession.isOtherAudioPlaying)")
        print("🎤 Available system voices: \(AVSpeechSynthesisVoice.speechVoices().count)")
        print("🎤 Current synthesizer speaking: \(synthesizer.isSpeaking)")
        print("🎤 Current audio player: \(currentAudioPlayer != nil ? "Active" : "None")")
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            // Set up audio session for playback with proper options that work with music
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .allowAirPlay, .allowBluetoothHFP, .defaultToSpeaker])
            
            // Activate the audio session
            try audioSession.setActive(true)
            
            print("✅ Audio session setup successful")
            print("🔊 Audio output routed to: \(audioSession.currentRoute.outputs.first?.portType.rawValue ?? "unknown")")
        } catch {
            print("❌ Audio session setup failed: \(error.localizedDescription)")
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
            
            // Try a simpler audio session setup as fallback
            do {
                try audioSession.setCategory(.playback)
                try audioSession.setActive(true)
                print("✅ Fallback audio session setup successful")
            } catch {
                print("❌ Fallback audio session setup also failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func queueVoiceCue(_ cue: VoiceCue) {
        print("🎤 Queuing voice cue: \(cue.text)")
        voiceQueue.append(cue)
        processNextVoiceCue()
    }
    
    private func processNextVoiceCue() {
        guard !isProcessingVoice, !voiceQueue.isEmpty else { 
            print("🎤 Voice processing busy or queue empty")
            return 
        }
        
        isProcessingVoice = true
        let cue = voiceQueue.removeFirst()
        currentCue = cue
        isSpeaking = true
        
        print("🎤 Processing voice cue: \(cue.text)")
        elevenLabsRetryCount = 0 // Reset retry count for new cue
        generateAndPlayVoiceWithRetry(text: cue.text)
    }
    
    private func onVoiceCueComplete() {
        isProcessingVoice = false
        currentCue = nil
        isSpeaking = false
        
        // Process next cue in queue
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.processNextVoiceCue()
        }
    }
    
    private func ensureAudioSessionForVoice() -> Bool {
        do {
            // Temporarily reconfigure audio session for voice playback
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .allowAirPlay, .allowBluetoothHFP, .defaultToSpeaker])
            try audioSession.setActive(true)
            
            print("🎤 Audio session configured for voice playback")
            print("🎤 Audio session category: \(audioSession.category.rawValue)")
            print("🎤 Audio session mode: \(audioSession.mode.rawValue)")
            print("🎤 Other audio playing: \(audioSession.isOtherAudioPlaying)")
            
            return true
        } catch {
            print("❌ Failed to configure audio session for voice: \(error.localizedDescription)")
            return false
        }
    }
    
    private func generateAndPlayVoiceWithRetry(text: String) {
        generateAndPlayVoice(text: text)
    }
    
    private func generateAndPlayVoice(text: String) {
        print("🎤 ===== ELEVENLABS API DEBUG START =====")
        print("🎤 Attempting ElevenLabs API call for: \(text)")
        print("🎤 Text length: \(text.count) characters")
        print("🎤 API Key: \(apiKey.prefix(10))...\(apiKey.suffix(4))")
        print("🎤 Voice ID: \(voiceID)")
        print("🎤 Base URL: \(baseURL)")
        
        // Check if we should skip ElevenLabs (for debugging)
        let skipElevenLabs = UserDefaults.standard.bool(forKey: "skipElevenLabs")
        if skipElevenLabs {
            print("🎤 ⚠️ ElevenLabs API disabled by user preference")
            print("🎤 Using system voice fallback")
            fallbackToSystemVoice(text: text)
            return
        }
        
        // Ensure audio session is properly configured for voice playback
        if !ensureAudioSessionForVoice() {
            print("🎤 ⚠️ Audio session not ready for ElevenLabs, using fallback")
            fallbackToSystemVoice(text: text)
            return
        }
        
        // Validate API key
        guard !apiKey.isEmpty && apiKey.hasPrefix("sk_") else {
            print("❌ Invalid ElevenLabs API key format")
            print("❌ API Key: \(apiKey)")
            errorMessage = "Invalid ElevenLabs API key format"
            fallbackToSystemVoice(text: text)
            return
        }
        
        // Validate voice ID
        guard !voiceID.isEmpty else {
            print("❌ Empty voice ID")
            errorMessage = "Empty voice ID"
            fallbackToSystemVoice(text: text)
            return
        }
        
        // Validate text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ Empty or whitespace-only text")
            errorMessage = "Empty text provided"
            fallbackToSystemVoice(text: text)
            return
        }
        
        // Build URL
        let endpoint = "\(baseURL)/text-to-speech/\(voiceID)"
        print("🎤 Endpoint URL: \(endpoint)")
        
        guard let url = URL(string: endpoint) else {
            print("❌ Failed to create URL from: \(endpoint)")
            errorMessage = "Invalid ElevenLabs URL: \(endpoint)"
            fallbackToSystemVoice(text: text)
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.timeoutInterval = 30.0 // 30 second timeout
        
        print("🎤 Request headers:")
        print("🎤   Content-Type: application/json")
        print("🎤   xi-api-key: \(apiKey.prefix(10))...\(apiKey.suffix(4))")
        print("🎤   Timeout: 30 seconds")
        
        // Create request body
        let requestBody = ElevenLabsRequest(
            text: text,
            model_id: "eleven_monolingual_v1",
            voice_settings: VoiceSettings(
                stability: 0.5,
                similarity_boost: 0.5
            )
        )
        
        print("🎤 Request body:")
        print("🎤   Text: \(text)")
        print("🎤   Model ID: eleven_monolingual_v1")
        print("🎤   Stability: 0.5")
        print("🎤   Similarity Boost: 0.5")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            print("🎤 Request body encoded successfully (\(request.httpBody?.count ?? 0) bytes)")
        } catch {
            print("❌ Failed to encode request body: \(error.localizedDescription)")
            print("❌ Encoding error details: \(error)")
            errorMessage = "Failed to encode request: \(error.localizedDescription)"
            fallbackToSystemVoice(text: text)
            return
        }
        
        print("🎤 Starting ElevenLabs API request...")
        let startTime = Date()
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            DispatchQueue.main.async {
                print("🎤 ===== ELEVENLABS API RESPONSE =====")
                print("🎤 Request duration: \(String(format: "%.2f", duration)) seconds")
                
                if let error = error {
                    print("❌ Network error occurred:")
                    print("❌   Error: \(error.localizedDescription)")
                    print("❌   Error code: \((error as NSError).code)")
                    print("❌   Error domain: \((error as NSError).domain)")
                    print("❌   User info: \((error as NSError).userInfo)")
                    
                    if let urlError = error as? URLError {
                        print("❌   URLError code: \(urlError.code.rawValue)")
                        print("❌   URLError description: \(urlError.localizedDescription)")
                        
                        switch urlError.code {
                        case .timedOut:
                            print("❌   → Request timed out")
                        case .notConnectedToInternet:
                            print("❌   → No internet connection")
                        case .cannotConnectToHost:
                            print("❌   → Cannot connect to ElevenLabs servers")
                        case .networkConnectionLost:
                            print("❌   → Network connection lost")
                        default:
                            print("❌   → Other network error")
                        }
                    }
                    
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    self?.handleElevenLabsFailure(text: text, error: error.localizedDescription)
                    return
                }
                
                // Check HTTP response
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP Response:")
                    print("📡   Status Code: \(httpResponse.statusCode)")
                    print("📡   Status Description: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                    print("📡   Headers: \(httpResponse.allHeaderFields)")
                    
                    switch httpResponse.statusCode {
                    case 200:
                        print("✅ HTTP 200 - Success")
                    case 400:
                        print("❌ HTTP 400 - Bad Request (check API key, voice ID, or request format)")
                    case 401:
                        print("❌ HTTP 401 - Unauthorized (invalid API key)")
                    case 403:
                        print("❌ HTTP 403 - Forbidden (insufficient permissions)")
                    case 404:
                        print("❌ HTTP 404 - Voice not found (check voice ID)")
                    case 422:
                        print("❌ HTTP 422 - Unprocessable Entity (invalid request data)")
                    case 429:
                        print("❌ HTTP 429 - Rate limit exceeded")
                    case 500:
                        print("❌ HTTP 500 - Internal server error")
                    case 503:
                        print("❌ HTTP 503 - Service unavailable")
                    default:
                        print("❌ HTTP \(httpResponse.statusCode) - Unexpected status")
                    }
                    
                    if httpResponse.statusCode != 200 {
                        print("❌ ElevenLabs API returned error status: \(httpResponse.statusCode)")
                        self?.errorMessage = "ElevenLabs API error: \(httpResponse.statusCode) - \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                        self?.handleElevenLabsFailure(text: text, error: "HTTP \(httpResponse.statusCode)")
                        return
                    }
                } else {
                    print("❌ No HTTP response received")
                    self?.errorMessage = "No HTTP response received"
                    self?.handleElevenLabsFailure(text: text, error: "No HTTP response")
                    return
                }
                
                // Check response data
                guard let data = data else {
                    print("❌ No response data received")
                    self?.errorMessage = "No response data received"
                    self?.handleElevenLabsFailure(text: text, error: "No response data")
                    return
                }
                
                print("📊 Response data:")
                print("📊   Size: \(data.count) bytes")
                print("📊   First 100 bytes: \(data.prefix(100).map { String(format: "%02x", $0) }.joined(separator: " "))")
                
                // Check if data looks like audio (starts with common audio file headers)
                let audioHeaders = [
                    [0x52, 0x49, 0x46, 0x46], // WAV/RIFF
                    [0xFF, 0xFB], // MP3
                    [0xFF, 0xF1], // AAC
                    [0x4F, 0x67, 0x67, 0x53], // OGG
                ]
                
                let firstBytes = data.prefix(4).map { Int($0) }
                let isAudioData = audioHeaders.contains { header in
                    firstBytes.prefix(header.count).elementsEqual(header)
                }
                
                if isAudioData {
                    print("✅ Response data appears to be valid audio")
                } else {
                    print("⚠️ Response data doesn't look like audio - might be error message")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("⚠️ Response content: \(responseString)")
                    }
                }
                
                print("✅ ElevenLabs API success, playing audio data (\(data.count) bytes))")
                self?.playAudioData(data)
            }
        }.resume()
    }
    
    private func handleElevenLabsFailure(text: String, error: String) {
        elevenLabsRetryCount += 1
        
        if elevenLabsRetryCount <= maxRetries {
            print("🔄 ElevenLabs failed (attempt \(elevenLabsRetryCount)/\(maxRetries + 1)), retrying in \(elevenLabsRetryCount) seconds...")
            print("🔄 Error: \(error)")
            
            let retryDelay = Double(elevenLabsRetryCount)
            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                self?.generateAndPlayVoice(text: text)
            }
        } else {
            print("❌ ElevenLabs failed after \(maxRetries) retries, using fallback voice")
            fallbackToSystemVoice(text: text)
        }
    }
    
    private func playAudioData(_ data: Data) {
        print("🔊 ===== AUDIO PLAYBACK DEBUG =====")
        print("🔊 Attempting to play audio data...")
        print("🔊 Data size: \(data.count) bytes")
        
        do {
            // Ensure we have valid audio data
            guard data.count > 0 else {
                print("❌ Empty audio data received")
                errorMessage = "Empty audio data received"
                isSpeaking = false
                return
            }
            
            // Ensure audio session is ready for playback
            if !ensureAudioSessionForVoice() {
                print("❌ Audio session not ready for playback")
                errorMessage = "Audio session not ready"
                isSpeaking = false
                return
            }
            
            print("🔊 Creating AVAudioPlayer with data...")
            let audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer.delegate = self
            audioPlayer.volume = 1.0
            
            print("🔊 Audio player created successfully")
            print("🔊 Audio player properties:")
            print("🔊   Duration: \(audioPlayer.duration) seconds")
            print("🔊   Volume: \(audioPlayer.volume)")
            print("🔊   Number of channels: \(audioPlayer.numberOfChannels)")
            print("🔊   Format: \(audioPlayer.format)")
            
            // Check if audio session is ready
            print("🔊 Audio session status:")
            print("🔊   Category: \(audioSession.category.rawValue)")
            print("🔊   Mode: \(audioSession.mode.rawValue)")
            print("🔊   Is active: \(audioSession.isOtherAudioPlaying)")
            print("🔊   Output route: \(audioSession.currentRoute.outputs.first?.portType.rawValue ?? "unknown")")
            
            // Prepare the audio player
            print("🔊 Preparing audio player...")
            guard audioPlayer.prepareToPlay() else {
                print("❌ Failed to prepare audio player")
                errorMessage = "Failed to prepare audio player"
                isSpeaking = false
                return
            }
            print("✅ Audio player prepared successfully")
            
            // Check if there's already audio playing
            if let currentPlayer = currentAudioPlayer, currentPlayer.isPlaying {
                print("🔊 Stopping current audio player...")
                currentPlayer.stop()
            }
            
            print("🔊 Starting audio playback...")
            let success = audioPlayer.play()
            print("🔊 Audio player play() returned: \(success)")
            
            if !success {
                print("❌ Audio player failed to start playing")
                print("❌ Possible causes:")
                print("❌   - Audio session not properly configured")
                print("❌   - Another app is using the audio system")
                print("❌   - Audio data format not supported")
                print("❌   - Device volume is muted")
                errorMessage = "Audio player failed to start"
                isSpeaking = false
                return
            }
            
            print("✅ Audio playback started successfully")
            
            // Store the player to prevent it from being deallocated
            self.currentAudioPlayer = audioPlayer
            
            // Post notification that we're speaking
            NotificationCenter.default.post(name: .voiceManagerSpeaking, object: true)
            
        } catch {
            print("❌ Failed to create/play audio: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            if let nsError = error as NSError? {
                print("❌ Error domain: \(nsError.domain)")
                print("❌ Error code: \(nsError.code)")
                print("❌ Error user info: \(nsError.userInfo)")
            }
            errorMessage = "Failed to play audio: \(error.localizedDescription)"
            isSpeaking = false
        }
    }
    
    private func fallbackToSystemVoice(text: String) {
        print("🎤 ===== SYSTEM VOICE FALLBACK =====")
        print("🎤 Using system voice fallback for: \(text)")
        print("🎤 Text length: \(text.count) characters")
        
        // Check available voices
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
        print("🎤 Available system voices: \(availableVoices.count)")
        
        if availableVoices.count > 0 {
            print("🎤 First few voices:")
            for (index, voice) in availableVoices.prefix(5).enumerated() {
                print("🎤   \(index + 1). \(voice.name) (\(voice.language))")
            }
        }
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.volume = 1.0
        
        // Try to find a good English voice
        let englishVoices = availableVoices.filter { $0.language.hasPrefix("en") }
        if let englishVoice = englishVoices.first {
            utterance.voice = englishVoice
            print("🎤 Using English voice: \(englishVoice.name) (\(englishVoice.language))")
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            print("🎤 Using default English voice")
        }
        
        print("🎤 Utterance settings:")
        print("🎤   Rate: \(utterance.rate)")
        print("🎤   Volume: \(utterance.volume)")
        print("🎤   Voice: \(utterance.voice?.name ?? "Default")")
        print("🎤   Language: \(utterance.voice?.language ?? "Unknown")")
        
        // Check if synthesizer is ready
        if synthesizer.isSpeaking {
            print("🎤 ⚠️ Synthesizer is already speaking, stopping current speech")
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        print("🎤 Starting system voice synthesis...")
        synthesizer.speak(utterance)
        print("🎤 System voice synthesis started")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = true
        }
        NotificationCenter.default.post(name: .voiceManagerSpeaking, object: true)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.currentCue = nil
        }
        NotificationCenter.default.post(name: .voiceManagerSpeaking, object: false)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.currentCue = nil
        }
        NotificationCenter.default.post(name: .voiceManagerSpeaking, object: false)
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🔊 Audio player finished playing successfully: \(flag)")
        DispatchQueue.main.async { [weak self] in
            self?.currentAudioPlayer = nil
            self?.onVoiceCueComplete()
        }
        NotificationCenter.default.post(name: .voiceManagerSpeaking, object: false)
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Audio player decode error: \(error?.localizedDescription ?? "Unknown error")")
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = "Audio playback error: \(error?.localizedDescription ?? "Unknown error")"
            self?.onVoiceCueComplete()
        }
        NotificationCenter.default.post(name: .voiceManagerSpeaking, object: false)
    }
}

// MARK: - Data Models

struct ElevenLabsRequest: Codable {
    let text: String
    let model_id: String
    let voice_settings: VoiceSettings
}

struct VoiceSettings: Codable {
    let stability: Double
    let similarity_boost: Double
}
