# TreeAR Architecture: MVVM-C

## Overview

The app uses **MVVM-C** (Model-View-ViewModel-Coordinator):

- **Model**: Minimal; game state lives in ViewModels
- **View**: `IntroductionViewController`, `ARViewController` (UIKit)
- **ViewModel**: `IntroductionViewModel`, `ARViewModel` — business logic, state, navigation delegation
- **Coordinator**: `AppCoordinator` — owns navigation flow, presents/dismisses screens

## Flow

```
ContentView (SwiftUI root)
    └── AppCoordinator (@Observable)
    └── IntroductionViewRepresentable → IntroductionViewController
            └── IntroductionViewModel → coordinator.showAR()
    └── fullScreenCover → ARViewRepresentable → ARViewController
            └── ARViewModel → coordinator.dismissAR()
```

## SwiftUI vs UIKit

**SwiftUI is used for:**
- App entry point (`TreeARApp`)
- Root navigation shell (`ContentView`)
- Coordinator state and presentation (fullScreenCover)

**UIKit is required for:**
- AR experience — `ARSCNView` has no native SwiftUI equivalent
- Introduction screen — could be SwiftUI, but kept UIKit for consistency with AR flow

**Recommendation:** The hybrid approach is appropriate. SwiftUI excels as the navigation shell; ARKit mandates UIKit. Converting the intro to SwiftUI would work but adds little value given the AR screen must remain UIKit.
