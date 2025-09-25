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
        currentCue = cue
        isSpeaking = true
        
        // Use ElevenLabs for high-quality AI voice
        generateAndPlayVoice(text: cue.text)
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
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers, .allowAirPlay, .allowBluetoothHFP])
            try audioSession.setActive(true)
            
            // Force audio to system speakers (important for simulator)
            try audioSession.overrideOutputAudioPort(.speaker)
            
            print("✅ Audio session setup successful")
            print("🔊 Audio output routed to: \(audioSession.currentRoute.outputs.first?.portType.rawValue ?? "unknown")")
        } catch {
            print("❌ Audio session setup failed: \(error.localizedDescription)")
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
    
    private func generateAndPlayVoice(text: String) {
        print("🎤 Attempting ElevenLabs API call for: \(text)")
        
        // For now, skip ElevenLabs API to prevent crashes and use system voice
        // TODO: Implement proper ElevenLabs integration with error handling
        fallbackToSystemVoice(text: text)
        return
        
        guard let url = URL(string: "\(baseURL)/text-to-speech/\(voiceID)") else {
            print("❌ Invalid ElevenLabs URL")
            errorMessage = "Invalid ElevenLabs URL"
            fallbackToSystemVoice(text: text)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        let requestBody = ElevenLabsRequest(
            text: text,
            model_id: "eleven_monolingual_v1",
            voice_settings: VoiceSettings(
                stability: 0.5,
                similarity_boost: 0.5
            )
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            errorMessage = "Failed to encode request: \(error.localizedDescription)"
            fallbackToSystemVoice(text: text)
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ ElevenLabs API error: \(error.localizedDescription)")
                    self?.errorMessage = "Voice generation failed: \(error.localizedDescription)"
                    self?.fallbackToSystemVoice(text: text)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 ElevenLabs API response status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("❌ ElevenLabs API returned status: \(httpResponse.statusCode)")
                        self?.fallbackToSystemVoice(text: text)
                        return
                    }
                }
                
                guard let data = data else {
                    print("❌ No voice data received from ElevenLabs")
                    self?.errorMessage = "No voice data received"
                    self?.fallbackToSystemVoice(text: text)
                    return
                }
                
                print("✅ ElevenLabs API success, playing audio data (\(data.count) bytes)")
                self?.playAudioData(data)
            }
        }.resume()
    }
    
    private func playAudioData(_ data: Data) {
        do {
            let audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer.delegate = self
            audioPlayer.volume = 1.0
            audioPlayer.prepareToPlay()
            print("🔊 Playing audio data (volume: \(audioPlayer.volume), duration: \(audioPlayer.duration)s)")
            let success = audioPlayer.play()
            print("🔊 Audio player play() returned: \(success)")
            
            // Store the player to prevent it from being deallocated
            self.currentAudioPlayer = audioPlayer
        } catch {
            print("❌ Failed to play audio: \(error.localizedDescription)")
            errorMessage = "Failed to play audio: \(error.localizedDescription)"
            isSpeaking = false
        }
    }
    
    private func fallbackToSystemVoice(text: String) {
        print("🎤 Using system voice fallback for: \(text)")
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        synthesizer.speak(utterance)
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
            self?.isSpeaking = false
            self?.currentCue = nil
            self?.currentAudioPlayer = nil
        }
        NotificationCenter.default.post(name: .voiceManagerSpeaking, object: false)
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Audio player decode error: \(error?.localizedDescription ?? "Unknown error")")
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = "Audio playback error: \(error?.localizedDescription ?? "Unknown error")"
            self?.isSpeaking = false
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
