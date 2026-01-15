//
//  OpenAIClient.swift
//  365WeaponsAdmin
//
//  OpenAI Client for Whisper (STT) and TTS capabilities
//

import Foundation
import AVFoundation
import Combine

// MARK: - OpenAI Configuration
struct OpenAIConfig {
    static let baseURL = "https://api.openai.com/v1"
    static let whisperEndpoint = "\(baseURL)/audio/transcriptions"
    static let ttsEndpoint = "\(baseURL)/audio/speech"

    // Whisper models
    static let whisperModel = "whisper-1"

    // TTS voices
    static let defaultVoice = "alloy"
    static let availableVoices = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]

    // TTS models
    static let ttsModel = "tts-1"
    static let ttsHDModel = "tts-1-hd"
}

// MARK: - OpenAI Client
class OpenAIClient: NSObject, ObservableObject {
    static let shared = OpenAIClient()

    @Published var isRecording: Bool = false
    @Published var isTranscribing: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var audioLevel: Float = 0.0
    @Published var transcribedText: String = ""
    @Published var error: OpenAIError?
    @Published var selectedVoice: String = OpenAIConfig.defaultVoice

    private let session: URLSession
    private var apiKey: String?

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL?
    private var levelTimer: Timer?

    private var cancellables = Set<AnyCancellable>()

    private override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
        super.init()

        setupAudioSession()
    }

    // MARK: - Configuration
    func configure(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Speech-to-Text (Whisper)

    /// Start recording audio for transcription
    @MainActor
    func startRecording() throws {
        guard !isRecording else { return }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")

        guard let recordingURL = recordingURL else {
            throw OpenAIError.recordingFailed("Could not create recording URL")
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true

            // Start level monitoring
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateAudioLevel()
            }
        } catch {
            throw OpenAIError.recordingFailed(error.localizedDescription)
        }
    }

    /// Stop recording and transcribe the audio
    @MainActor
    func stopRecording() async throws -> String {
        guard isRecording, let recorder = audioRecorder, let url = recordingURL else {
            throw OpenAIError.noRecording
        }

        levelTimer?.invalidate()
        levelTimer = nil
        recorder.stop()
        isRecording = false
        audioLevel = 0.0

        // Transcribe the recording
        let transcript = try await transcribeAudio(fileURL: url)

        // Clean up recording file
        try? FileManager.default.removeItem(at: url)

        transcribedText = transcript
        return transcript
    }

    /// Cancel recording without transcribing
    @MainActor
    func cancelRecording() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioRecorder?.stop()
        isRecording = false
        audioLevel = 0.0

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func updateAudioLevel() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        // Normalize from -160...0 dB to 0...1
        let normalizedLevel = max(0, (level + 50) / 50)
        DispatchQueue.main.async {
            self.audioLevel = normalizedLevel
        }
    }

    /// Transcribe audio file using Whisper API
    func transcribeAudio(fileURL: URL, language: String? = nil, prompt: String? = nil) async throws -> String {
        guard let apiKey = apiKey else {
            throw OpenAIError.notConfigured
        }

        isTranscribing = true
        defer { isTranscribing = false }

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: OpenAIConfig.whisperEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add audio file
        let audioData = try Data(contentsOf: fileURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(OpenAIConfig.whisperModel)\r\n".data(using: .utf8)!)

        // Add language if specified
        if let language = language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }

        // Add prompt if specified (for context)
        if let prompt = prompt {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(prompt)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw OpenAIError.apiError(
                code: httpResponse.statusCode,
                message: errorResponse?.error?.message ?? "Transcription failed"
            )
        }

        let transcriptionResponse = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return transcriptionResponse.text
    }

    // MARK: - Text-to-Speech (TTS)

    /// Convert text to speech and play it
    @MainActor
    func speak(text: String, voice: String? = nil, speed: Double = 1.0) async throws {
        guard let apiKey = apiKey else {
            throw OpenAIError.notConfigured
        }

        isSpeaking = true

        do {
            let audioData = try await generateSpeech(text: text, voice: voice ?? selectedVoice, speed: speed)
            try await playAudio(data: audioData)
        } catch {
            isSpeaking = false
            throw error
        }
    }

    /// Generate speech audio data
    func generateSpeech(text: String, voice: String = OpenAIConfig.defaultVoice, speed: Double = 1.0, hd: Bool = false) async throws -> Data {
        guard let apiKey = apiKey else {
            throw OpenAIError.notConfigured
        }

        var request = URLRequest(url: URL(string: OpenAIConfig.ttsEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = TTSRequest(
            model: hd ? OpenAIConfig.ttsHDModel : OpenAIConfig.ttsModel,
            input: text,
            voice: voice,
            speed: speed
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw OpenAIError.apiError(
                code: httpResponse.statusCode,
                message: errorResponse?.error?.message ?? "TTS failed"
            )
        }

        return data
    }

    /// Play audio data
    @MainActor
    private func playAudio(data: Data) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                audioPlayer = try AVAudioPlayer(data: data)
                audioPlayer?.delegate = self
                audioPlayer?.play()

                // Store continuation for delegate callback
                self.playbackContinuation = continuation
            } catch {
                isSpeaking = false
                continuation.resume(throwing: OpenAIError.playbackFailed(error.localizedDescription))
            }
        }
    }

    private var playbackContinuation: CheckedContinuation<Void, Error>?

    /// Stop current speech playback
    @MainActor
    func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        playbackContinuation?.resume()
        playbackContinuation = nil
    }

    // MARK: - Voice Management
    func setVoice(_ voice: String) {
        guard OpenAIConfig.availableVoices.contains(voice) else { return }
        selectedVoice = voice
    }

    func getAvailableVoices() -> [TTSVoice] {
        return OpenAIConfig.availableVoices.map { voice in
            TTSVoice(id: voice, name: voice.capitalized, description: voiceDescription(for: voice))
        }
    }

    private func voiceDescription(for voice: String) -> String {
        switch voice {
        case "alloy": return "Neutral and balanced"
        case "echo": return "Deep and resonant"
        case "fable": return "Warm and expressive"
        case "onyx": return "Deep and authoritative"
        case "nova": return "Warm and friendly"
        case "shimmer": return "Clear and bright"
        default: return "AI voice"
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension OpenAIClient: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.playbackContinuation?.resume()
            self.playbackContinuation = nil
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            if let error = error {
                self.playbackContinuation?.resume(throwing: OpenAIError.playbackFailed(error.localizedDescription))
            } else {
                self.playbackContinuation?.resume()
            }
            self.playbackContinuation = nil
        }
    }
}

// MARK: - Request/Response Types
struct WhisperResponse: Decodable {
    let text: String
}

struct TTSRequest: Encodable {
    let model: String
    let input: String
    let voice: String
    let speed: Double

    enum CodingKeys: String, CodingKey {
        case model, input, voice, speed
    }
}

struct TTSVoice: Identifiable {
    let id: String
    let name: String
    let description: String
}

struct OpenAIErrorResponse: Decodable {
    let error: OpenAIAPIError?
}

struct OpenAIAPIError: Decodable {
    let message: String
    let type: String?
    let code: String?
}

// MARK: - Error Types
enum OpenAIError: Error, LocalizedError {
    case notConfigured
    case invalidResponse
    case recordingFailed(String)
    case noRecording
    case transcriptionFailed(String)
    case ttsFailed(String)
    case playbackFailed(String)
    case apiError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OpenAI API key not configured"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .noRecording:
            return "No recording available"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .ttsFailed(let message):
            return "Text-to-speech failed: \(message)"
        case .playbackFailed(let message):
            return "Audio playback failed: \(message)"
        case .apiError(let code, let message):
            return "API Error (\(code)): \(message)"
        }
    }
}
