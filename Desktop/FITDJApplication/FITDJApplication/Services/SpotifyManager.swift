//
//  SpotifyManager.swift
//  FITDJApplication
//
//  Created by Eric Chesbrough on 9/24/25.
//

import Foundation
import Combine
import AuthenticationServices

// F-002: Spotify Connect functionality
@MainActor
class SpotifyManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userDisplayName: String?
    
    // Spotify credentials from instructions.md
    private let clientID = "e565d85fc0e04aba9093b17589b5e1e3"
    private let clientSecret = "181ab31b7ee84e63a8fde0f27ec44a5b"
    private let redirectURI = "fitdj://spotify-auth-callback"
    
    private let userDefaults = UserDefaults.standard
    private let accessTokenKey = "spotifyAccessToken"
    private let refreshTokenKey = "spotifyRefreshToken"
    private let userDisplayNameKey = "spotifyUserDisplayName"
    
    var accessToken: String?
    private var refreshToken: String?
    
    override init() {
        super.init()
        loadStoredTokens()
    }
    
    // MARK: - Public Methods
    
    func connectToSpotify() {
        isLoading = true
        errorMessage = nil
        
        // Create authorization URL
        let scopes = "user-read-private user-read-email user-read-playback-state user-modify-playback-state user-read-currently-playing"
        let authURL = "https://accounts.spotify.com/authorize?response_type=code&client_id=\(clientID)&scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: authURL) else {
            errorMessage = "Invalid authorization URL"
            isLoading = false
            return
        }
        
        // Open Safari for authentication
        UIApplication.shared.open(url)
    }
    
    func handleAuthCallback(url: URL) {
        guard url.scheme == "fitdj" && url.host == "spotify-auth-callback" else {
            return
        }
        
        // Extract authorization code from URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            errorMessage = "Failed to get authorization code"
            isLoading = false
            return
        }
        
        // Exchange code for access token
        exchangeCodeForToken(code: code)
    }
    
    func disconnectFromSpotify() {
        accessToken = nil
        refreshToken = nil
        userDisplayName = nil
        isConnected = false
        
        // Clear stored tokens
        userDefaults.removeObject(forKey: accessTokenKey)
        userDefaults.removeObject(forKey: refreshTokenKey)
        userDefaults.removeObject(forKey: userDisplayNameKey)
    }
    
    // MARK: - Private Methods
    
    private func exchangeCodeForToken(code: String) {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            errorMessage = "Invalid token URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create basic auth header
        let credentials = "\(clientID):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Create request body
        let body = "grant_type=authorization_code&code=\(code)&redirect_uri=\(redirectURI)"
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
                    self?.handleTokenResponse(tokenResponse)
                } catch {
                    self?.errorMessage = "Failed to parse token response"
                }
            }
        }.resume()
    }
    
    private func handleTokenResponse(_ response: SpotifyTokenResponse) {
        accessToken = response.access_token
        refreshToken = response.refresh_token
        
        // Store tokens
        userDefaults.set(response.access_token, forKey: accessTokenKey)
        if let refreshToken = response.refresh_token {
            userDefaults.set(refreshToken, forKey: refreshTokenKey)
        }
        
        // Get user profile
        fetchUserProfile()
    }
    
    private func fetchUserProfile() {
        guard let accessToken = accessToken else {
            errorMessage = "No access token available"
            return
        }
        
        guard let url = URL(string: "https://api.spotify.com/v1/me") else {
            errorMessage = "Invalid profile URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Failed to fetch profile: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No profile data received"
                    return
                }
                
                do {
                    let profile = try JSONDecoder().decode(SpotifyUserProfile.self, from: data)
                    self?.userDisplayName = profile.display_name ?? profile.id
                    self?.isConnected = true
                    
                    // Store user display name
                    if let displayName = profile.display_name {
                        self?.userDefaults.set(displayName, forKey: self?.userDisplayNameKey ?? "")
                    }
                    
                } catch {
                    self?.errorMessage = "Failed to parse profile data"
                }
            }
        }.resume()
    }
    
    private func loadStoredTokens() {
        accessToken = userDefaults.string(forKey: accessTokenKey)
        refreshToken = userDefaults.string(forKey: refreshTokenKey)
        userDisplayName = userDefaults.string(forKey: userDisplayNameKey)
        
        if accessToken != nil {
            isConnected = true
        }
    }
    
    private func refreshAccessToken() {
        guard let refreshToken = refreshToken else {
            errorMessage = "No refresh token available"
            return
        }
        
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            errorMessage = "Invalid token URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create basic auth header
        let credentials = "\(clientID):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Create request body
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)"
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Failed to refresh token: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No refresh data received"
                    return
                }
                
                do {
                    let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
                    self?.accessToken = tokenResponse.access_token
                    self?.userDefaults.set(tokenResponse.access_token, forKey: self?.accessTokenKey ?? "")
                    
                    if let newRefreshToken = tokenResponse.refresh_token {
                        self?.refreshToken = newRefreshToken
                        self?.userDefaults.set(newRefreshToken, forKey: self?.refreshTokenKey ?? "")
                    }
                    
                } catch {
                    self?.errorMessage = "Failed to parse refresh response"
                }
            }
        }.resume()
    }
}

// MARK: - Data Models

struct SpotifyTokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
    let scope: String
}

struct SpotifyUserProfile: Codable {
    let id: String
    let display_name: String?
    let email: String?
    let country: String?
    let product: String?
}
