//
//  AIChatView.swift
//  365WeaponsAdmin
//
//  AI Chat interface with voice capabilities
//

import SwiftUI

struct AIChatView: View {
    @StateObject private var viewModel = AIChatViewModel()
    @EnvironmentObject var orchestrator: OrchestrationAgent
    @FocusState private var isInputFocused: Bool

    @State private var inputText = ""
    @State private var showVoiceMode = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat messages
                messagesView

                // Input area
                inputArea
            }
            .padding(.bottom, 80) // Space for tab bar
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: viewModel.clearHistory) {
                        Image(systemName: "trash")
                            .foregroundColor(.gray)
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showVoiceMode = true }) {
                        Image(systemName: "mic.circle.fill")
                            .foregroundColor(.orange)
                    }

                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(isPresented: $showVoiceMode) {
                VoiceModeView(viewModel: viewModel)
            }
            .sheet(isPresented: $showSettings) {
                ChatSettingsView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Messages View
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Welcome message
                    if viewModel.messages.isEmpty {
                        welcomeView
                    }

                    // Chat messages
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    // Typing indicator
                    if viewModel.isProcessing {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    if let lastId = viewModel.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Welcome View
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("AI Assistant")
                    .font(.title.weight(.bold))

                Text("Ask me anything about your dashboard, orders, products, or business insights.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            // Quick prompts
            VStack(spacing: 12) {
                Text("Try asking:")
                    .font(.caption)
                    .foregroundColor(.gray)

                ForEach(quickPrompts, id: \.self) { prompt in
                    QuickPromptButton(prompt: prompt) {
                        inputText = prompt
                        sendMessage()
                    }
                }
            }
        }
        .padding(.vertical, 40)
    }

    private var quickPrompts: [String] {
        [
            "How are sales doing today?",
            "What orders need attention?",
            "Give me a daily briefing",
            "Show me top selling products"
        ]
    }

    // MARK: - Input Area
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 12) {
                // Text input
                HStack {
                    TextField("Message...", text: $inputText, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .onSubmit {
                            if !inputText.isEmpty {
                                sendMessage()
                            }
                        }

                    if !inputText.isEmpty {
                        Button(action: { inputText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(24)

                // Send button
                Button(action: sendMessage) {
                    Image(systemName: viewModel.isProcessing ? "stop.fill" : "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(inputText.isEmpty && !viewModel.isProcessing ? .gray : .orange)
                }
                .disabled(inputText.isEmpty && !viewModel.isProcessing)
            }
            .padding()
        }
        .background(Color.black)
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let message = inputText
        inputText = ""
        isInputFocused = false

        Task {
            await viewModel.sendMessage(message)
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage

    /// Strip markdown formatting from text for cleaner display
    private func stripMarkdown(_ text: String) -> String {
        var result = text

        // Remove bold (**text** or __text__)
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "__(.+?)__", with: "$1", options: .regularExpression)

        // Remove italic (*text* or _text_)
        result = result.replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "(?<!_)_([^_]+)_(?!_)", with: "$1", options: .regularExpression)

        // Remove headers (# Header)
        result = result.replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: .regularExpression)

        // Remove code blocks (```code```)
        result = result.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)

        // Remove inline code (`code`)
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)

        // Remove bullet points (- item or * item) at start of lines
        result = result.replacingOccurrences(of: "(?m)^[\\-\\*]\\s+", with: "• ", options: .regularExpression)

        // Clean up multiple newlines
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get display text - strip markdown for assistant messages
    private var displayText: String {
        if message.role == .assistant {
            return stripMarkdown(message.content)
        }
        return message.content
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                // AI avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .frame(width: 32, height: 32)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(displayText)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        message.role == .user
                            ? Color.orange
                            : Color.white.opacity(0.1)
                    )
                    .cornerRadius(20)
                    .cornerRadius(message.role == .user ? 20 : 4, corners: message.role == .user ? [.topLeft, .bottomLeft, .bottomRight] : [.topRight, .bottomLeft, .bottomRight])

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            if message.role == .user {
                // User avatar
                ZStack {
                    Circle()
                        .fill(Color.blue)
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .frame(width: 32, height: 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            animationOffset = -5
        }
    }
}

// MARK: - Quick Prompt Button
struct QuickPromptButton: View {
    let prompt: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "sparkle")
                    .font(.caption)
                Text(prompt)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))
            .foregroundColor(.white)
            .cornerRadius(20)
        }
    }
}

// MARK: - Voice Mode View
struct VoiceModeView: View {
    @ObservedObject var viewModel: AIChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isRecording = false
    @State private var audioLevel: CGFloat = 0
    @State private var transcript = ""
    @State private var response = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Visualization
                VoiceVisualization(isRecording: isRecording, audioLevel: audioLevel)

                // Status
                VStack(spacing: 8) {
                    Text(statusText)
                        .font(.headline)

                    if !transcript.isEmpty {
                        Text(transcript)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                Spacer()

                // Record button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.orange)
                            .frame(width: 80, height: 80)

                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Voice Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var statusText: String {
        if isRecording {
            return "Listening..."
        } else if viewModel.isProcessing {
            return "Processing..."
        } else if !response.isEmpty {
            return "Response ready"
        } else {
            return "Tap to speak"
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        transcript = ""
        response = ""

        Task {
            do {
                try await viewModel.startVoiceInput()
            } catch {
                print("Recording error: \(error)")
                isRecording = false
            }
        }
    }

    private func stopRecording() {
        isRecording = false

        Task {
            do {
                let result = try await viewModel.stopVoiceInput()
                transcript = result.transcript
                response = result.response

                // Speak the response
                try await viewModel.speakResponse(result.response)
            } catch {
                print("Processing error: \(error)")
            }
        }
    }
}

// MARK: - Voice Visualization
struct VoiceVisualization: View {
    let isRecording: Bool
    let audioLevel: CGFloat

    @State private var animation = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                    .frame(width: 100 + CGFloat(i) * 40, height: 100 + CGFloat(i) * 40)
                    .scaleEffect(animation && isRecording ? 1.2 : 1.0)
                    .opacity(animation && isRecording ? 0.5 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever()
                            .delay(Double(i) * 0.2),
                        value: animation
                    )
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .scaleEffect(1.0 + audioLevel * 0.3)

            Image(systemName: isRecording ? "waveform" : "mic.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        }
        .onAppear {
            animation = true
        }
    }
}

// MARK: - Chat Settings View
struct ChatSettingsView: View {
    @ObservedObject var viewModel: AIChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("AI Model") {
                    Picker("Model", selection: $viewModel.selectedModel) {
                        Text("Claude 3.5 Sonnet (Default)").tag("anthropic/claude-3.5-sonnet")
                        Text("Claude 3 Haiku (Fast)").tag("anthropic/claude-3-haiku")
                        Text("Claude 3 Opus (Advanced)").tag("anthropic/claude-3-opus")
                    }
                }

                Section("Voice") {
                    Picker("Voice", selection: $viewModel.selectedVoice) {
                        ForEach(viewModel.availableVoices, id: \.id) { voice in
                            Text("\(voice.name) - \(voice.description)").tag(voice.id)
                        }
                    }

                    Toggle("Auto-speak responses", isOn: $viewModel.autoSpeak)
                }

                Section("Behavior") {
                    Toggle("Stream responses", isOn: $viewModel.streamResponses)
                    Toggle("Include business context", isOn: $viewModel.includeContext)
                }

                Section("Data") {
                    Button("Clear Conversation History") {
                        viewModel.clearHistory()
                    }
                    .foregroundColor(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Chat Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - AI Chat ViewModel
@MainActor
class AIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing = false
    @Published var error: Error?

    // Settings
    @Published var selectedModel = "anthropic/claude-3.5-sonnet"
    @Published var selectedVoice = "alloy"
    @Published var autoSpeak = false
    @Published var streamResponses = true
    @Published var includeContext = true

    private let orchestrator = OrchestrationAgent.shared
    private let chatAgent = ChatAgent()
    private let openAI = OpenAIClient.shared

    var availableVoices: [TTSVoice] {
        openAI.getAvailableVoices()
    }

    private var logger: DebugLogger {
        DebugLogger.shared
    }

    @MainActor
    func sendMessage(_ content: String) async {
        logger.log("sendMessage called: '\(content.prefix(50))...'", category: .chat)

        let userMessage = ChatMessage(role: .user, content: content)
        messages.append(userMessage)
        isProcessing = true

        do {
            // Use non-streaming for reliability - streaming has thread safety issues
            logger.log("Calling orchestrator.process()", category: .chat)
            let output = try await orchestrator.process(message: content)
            logger.success("Orchestrator returned: '\(output.response.prefix(100))...'", category: .chat)

            let assistantMessage = ChatMessage(role: .assistant, content: output.response)
            messages.append(assistantMessage)

            if autoSpeak {
                try await speakResponse(output.response)
            }
        } catch {
            logger.error("Chat error: \(error.localizedDescription)", category: .chat)
            self.error = error
            let errorMessage = ChatMessage(role: .assistant, content: "Sorry, I encountered an error: \(error.localizedDescription)")
            messages.append(errorMessage)
        }

        isProcessing = false
    }

    func clearHistory() {
        messages.removeAll()
        orchestrator.clearHistory()
        chatAgent.clearHistory()
    }

    // MARK: - Voice

    func startVoiceInput() async throws {
        try chatAgent.startRecording()
    }

    func stopVoiceInput() async throws -> (transcript: String, response: String) {
        let transcript = try await chatAgent.stopRecording()

        // Process the transcript
        let output = try await orchestrator.process(message: transcript)

        // Add to messages
        messages.append(ChatMessage(role: .user, content: transcript))
        messages.append(ChatMessage(role: .assistant, content: output.response))

        return (transcript, output.response)
    }

    func speakResponse(_ text: String) async throws {
        try await openAI.speak(text: text, voice: selectedVoice)
    }
}

// MARK: - Preview
#Preview {
    AIChatView()
        .environmentObject(OrchestrationAgent.shared)
}
