# AGENTS.md

This file provides guidance to agents such as Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Rover iOS SDK, a modular collection of Swift frameworks for mobile experiences, campaigns automation, and marketing. The SDK follows a modular architecture allowing inclusion of only relevant functionality.

## Architecture

### Relationships with External Systems

- **Rover GraphQL API Gateway**: The GraphQL API is used for outbound events and classic experiences, and various legacy features. These outbound events are used for behavioural automation, setting up APNs push tokens, and other local device/user context and preferences into the Rover cloud.
- **Bobcat/Engage API**: Rover is moving towards a new set of cloud services. This is the new API for the Rover platform, and use of the old API will be eventually phased out.

### Modular Design
The SDK is organized into independent modules (Swift Package Manager targets):

- **RoverFoundation**: Core dependency injection container, utilities, and base types
- **RoverData**: HTTP client, event queue, sync coordination, context management
- **RoverUI**: UI services, routing, session management, image handling
- **RoverExperiences**: Rendering of experiences, dynamic UI content. There are versions of the Experiences product, classic and modern. Classic is the old legacy version of experiences, whereas modern is modelled on a subset of SwiftUI. They have separate authoring tools.
- **RoverNotifications**: Push notifications, a legacy version Inbox (sometimes called Notification Center), and Communication Hub (the new Inbox that replaces it)
- **RoverLocation**: Capturing of device location for targeting purposes, along with Geofencing and beacon support. Deprecated for privacy reasons.
- **RoverDebug**: Development tools and settings UI
- **RoverTelephony**: Telephony context provider. Deprecated for privacy reasons.
- **Third-party integrations**: RoverTicketmaster, RoverSeatGeek, RoverAxs, RoverAdobeExperience
- **RoverAppExtensions**: Notification service extension support. This is used to add behaviour at APNs push reception time, such as enabling rich media support, or persisting notification content in local storage.

### Module Dependencies
```
RoverFoundation (base)
├── RoverData (depends on Foundation)
│   ├── RoverUI (depends on Data)
│   │   ├── RoverExperiences (depends on UI, Foundation, Data)
│   │   ├── RoverNotifications (depends on Data, UI)
│   │   └── RoverDebug (depends on UI)
│   ├── RoverLocation (depends on Data)
│   ├── RoverTelephony (depends on Data)
│   ├── RoverTicketmaster (depends on Data)
│   ├── RoverSeatGeek (depends on Data)
│   ├── RoverAxs (depends on Data)
│   └── RoverAdobeExperience (depends on Data)
└── RoverAppExtensions (depends on Foundation)
```

### Dependency Injection
The SDK uses a custom DI container (`Sources/Foundation/Container/`) with assemblers for each module:
- Each module has an `*Assembler.swift` that registers services
- Services are resolved through the main `Rover` singleton
- Supports singleton and transient scopes with factory patterns
- `Assembler` protocol defines module configuration
- `Container` manages service registration
- `Resolver` handles service resolution

Each module follows the pattern:
```swift
class ModuleAssembler: Assembler {
    func assemble(container: Container) {
        // Register services
    }
    
    func containerDidAssemble(resolver: Resolver) {
        // Post-registration configuration
    }
}
```

### Communication Hub (New Inbox)
New messaging feature located in `Sources/Notifications/Communication Hub/`:
- Core Data models for posts and subscriptions
- SwiftUI views for inbox and post detail
- Sync logic using the new Bobcat/Engage API
- Sync participant for syncing when the rest of the SDK is syncing

### Experience Rendering Architecture
The Experiences module has dual rendering paths:
- **Classic Experiences**: Legacy UIKit-based renderer (`Sources/Experiences/ClassicExperiences/`)
- **Modern Experiences**: SwiftUI-style declarative renderer (`Sources/Experiences/Experiences/`)

They are different products with different formats (and different authoring tools to be found elsewhere). Experiences are rendered through a hierarchical node system where each UI element is a `Node` with view-specific implementations in both classic and modern renderers.

### Data Management
- **Event System**: Queue-based event tracking with offline support (`Sources/Data/EventQueue/`)
- **Sync System**: Paginated data synchronization framework (`Sources/Data/SyncCoordinator/`)
- **Context System**: Device and user context collection (`Sources/Data/Context/`)

### External Dependencies
- `ZIPFoundation`: For experience asset archive handling
- `iOS-TicketmasterSDK`: The RoverTicketmaster module directly depends on Ticketmaster's Ignite SDK. However, this strategy is being phased out.


## Development Commands

### Build and Test
```bash
# Build the Testbench app (main development target)

xcodebuild -scheme "Rover Bench" -project "Testbench/Rover Bench.xcodeproj" build
      2>&1 | grep -A2 -B2 "error:" | head -20

### Running Tests
```bash
# Run unit tests for specific modules
xcodebuild test -scheme "RoverFoundation" -project "Testbench/Rover Bench.xcodeproj" -destination "platform=iOS Simulator,name=iPhone 15"
xcodebuild test -scheme "RoverData" -project "Testbench/Rover Bench.xcodeproj" -destination "platform=iOS Simulator,name=iPhone 15"
# (Similar for other modules)

# Alternative: Test using the Example project
xcodebuild test -project Example/Example.xcodeproj -scheme Example -destination "platform=iOS Simulator,name=iPhone 15"

# Test individual modules via workspace (if needed)
xcodebuild test -workspace Example/Example.xcworkspace -scheme RoverFoundation -destination "platform=iOS Simulator,name=iPhone 15"
```

### Package Verification
Since this is a Swift Package, you can verify the package structure:
```bash
swift package dump-package
swift package resolve
```

## Key Files and Patterns

### Entry Points
- `Sources/Foundation/Rover.swift`: Main SDK singleton and container
- `Testbench/Rover Bench/TestbenchApp.swift`: SwiftUI test app
- `Example/Example/AppDelegate.swift`: UIKit example app

### Service Registration
Services are registered in assemblers following this pattern:
```swift
container.register(ServiceProtocol.self) { resolver in
    ServiceImplementation(dependency: resolver.resolve(Dependency.self)!)
}
```

### Core Data Models
- Location: `Sources/Location/Model/RoverLocation.xcdatamodeld/`
- Communication Hub: `Sources/Notifications/Communication Hub/RoverCommHubModel.xcdatamodeld/`

### Extension Points
- Context Providers: `Sources/Data/Context/Providers/` for adding app context
- Route Handlers: Handle deep links and navigation
- Sync Participants: Integrate with server synchronization

## Common Development Patterns

### Adding New Features
1. Create service interface in appropriate module
2. Implement service with dependency injection
3. Register service in module's assembler
4. Add route handler if navigation is needed
5. Update sync participant (or standalone sync participant if it is not using the GraphQL API) if server communication is required

### Testing
- Unit tests are in `Tests/` directory organized by module
- Use XCTest framework with `@testable import` for internal access
- Mock services using the dependency injection container

### Privacy
Each module includes `Resources/PrivacyInfo.xcprivacy` for App Store privacy declarations.

## WORKFLOW INSTRUCTIONS

- You must always ensure tests pass between each step.
- You must always use `swift format -i` on a file after you've edited it.
- If tests do not already exist for the components involved in feature being planned, include steps adding them in the same plan.

### CODE STYLE

- Prefer guard statements over if statements with else blocks.
- Use Swift structured concurrency when possible.
- Never change Public APIs (any API that is marked as public), without explicit consent from the developer. This is an SDK with a public API with existing customers.
