# 365Weapons Admin iOS App

A beautiful, feature-rich companion admin dashboard app for the 365Weapons e-commerce website. Built with SwiftUI and powered by AI agents.

## Features

### Dashboard
- Real-time analytics with interactive charts and graphs
- Revenue tracking with growth indicators
- Order status overview
- Partner performance metrics
- Live activity feed with WebSocket support

### AI-Powered Agents
The app uses an orchestration agent architecture with 3 specialized sub-agents:

1. **Dashboard Agent** - Handles analytics, statistics, revenue data, and business insights
2. **Products Agent** - Manages product catalog, inventory, and product creation
3. **Chat Agent** - General AI assistant with voice capabilities (Whisper + TTS)

### Order Management
- View and filter orders by status
- Update order status
- View order details and customer information
- Track service types (Porting, Optic Cut, Slide Engraving)

### Product Management
- Browse products in grid or list view
- Filter by category
- Create new products
- Update product details and stock status
- Semantic product search powered by LanceDB

### Analytics
- Time-based revenue charts
- Service breakdown pie charts
- Partner performance rankings
- Customer insights and conversion funnel
- Real-time visitor tracking

### AI Chat
- Conversational AI assistant
- Context-aware responses with business data
- Voice input (Whisper speech-to-text)
- Voice output (OpenAI TTS)
- RAG-enhanced answers via LanceDB

## Technology Stack

### Frontend
- **SwiftUI** - Modern declarative UI framework
- **Swift Charts** - Native charting library
- **Combine** - Reactive programming

### Backend Integrations
- **Convex** - Real-time database and backend
- **Clerk** - Authentication
- **PostgreSQL** - Analytics and action tracking
- **LanceDB** - Vector search and RAG

### AI/ML
- **OpenRouter** - LLM access (Claude 3.5 Sonnet)
- **OpenAI Whisper** - Speech-to-text
- **OpenAI TTS** - Text-to-speech
- **LangGraph** - Agent orchestration

## Project Structure

```
365WeaponsAdmin/
├── 365WeaponsAdminApp.swift    # App entry point
├── Agents/
│   ├── OrchestrationAgent.swift  # Main orchestrator
│   ├── DashboardAgent.swift      # Analytics agent
│   ├── ProductsAgent.swift       # Product management agent
│   └── ChatAgent.swift           # AI chat agent
├── Models/
│   └── DataModels.swift          # All data models
├── Networking/
│   ├── ConvexClient.swift        # Convex backend client
│   ├── ClerkAuthClient.swift     # Authentication client
│   ├── OpenRouterClient.swift    # AI chat client
│   ├── OpenAIClient.swift        # Whisper/TTS client
│   ├── PostgreSQLClient.swift    # Analytics database
│   └── LanceDBClient.swift       # Vector search client
├── Services/
│   ├── LangGraphService.swift    # Agent orchestration
│   └── ActionTrackingService.swift # Real-time tracking
├── Views/
│   ├── ContentView.swift         # Main tab view
│   ├── SettingsView.swift        # App settings
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   └── DashboardViewModel.swift
│   ├── Orders/
│   │   └── OrdersView.swift
│   ├── Products/
│   │   └── ProductsView.swift
│   ├── Chat/
│   │   └── AIChatView.swift
│   └── Analytics/
│       └── AnalyticsView.swift
├── Utils/
│   └── Extensions.swift          # Utility extensions
└── Resources/
    └── Assets.xcassets           # App assets
```

## Configuration

### API Keys Required

1. **OpenRouter API Key** - For AI chat capabilities
2. **OpenAI API Key** - For Whisper and TTS
3. **Clerk Publishable Key** - For authentication

Configure these in Settings > API Keys within the app.

### Convex Backend

The app connects to the Convex backend at:
```
https://clear-pony-963.convex.cloud
```

## Building the App

1. Open `365WeaponsAdmin.xcodeproj` in Xcode 15+
2. Select your development team for signing
3. Build and run on iOS 17+ device or simulator

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Testing

The app includes comprehensive unit tests for:
- All agent classes
- Data models
- Networking clients
- Services

Run tests with `Cmd+U` in Xcode.

## Architecture

### Agent System

The app uses a multi-agent architecture:

```
User Input
    ↓
OrchestrationAgent
    ↓ (routes to appropriate agent)
    ├── DashboardAgent → Analytics queries
    ├── ProductsAgent → Product management
    └── ChatAgent → General assistance
    ↓
Response to User
```

### Data Flow

```
Views ←→ ViewModels ←→ Agents ←→ Networking Clients ←→ Backend
```

## License

Proprietary - 365Weapons

## Support

Contact: support@365weapons.com
Website: https://365weapons.com
