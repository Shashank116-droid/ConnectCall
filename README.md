# ConnectCall

## Project Description
ConnectCall is a deeply modern, feature-rich real-time audio and video calling application built with Flutter. It leverages WebRTC for secure peer-to-peer communication and heavily utilizes Firebase for signaling, backend infrastructure, and push notifications. With a focus on a premium "Glassmorphism" UI, dynamic micro-animations, and clean architecture, ConnectCall provides an incredible user experience for cross-platform communication.

## Features
- **Audio & Video Calling**: Secure, low-latency WebRTC-based calls without relying on expensive third-party SDKs.
- **Screen Sharing**: Effortless screen sharing during active video calls.
- **Background Push Notifications**: Incoming call alerts delivered reliably via Firebase Cloud Messaging (FCM).
- **Real-time Presence**: Instant "Online/Offline" status indicators for all contacts using Firebase Realtime Database.
- **Profile Customization**: Users can seamlessly upload custom profile avatars (via Firebase Storage) and update their names.
- **Contact Management**: Block or unblock users directly from the contacts list to control incoming calls.
- **Call History**: Detailed call logs marking calls as Missed, Rejected, Busy, or Completed with timestamps and duration.
- **Premium Design Aesthetics**: A fully custom UI featuring Google's "Outfit" font, gorgeous Indigo-to-Teal gradients, glassmorphism dark mode, and buttery-smooth list animations.

## Flutter Version
- Designed for **Flutter 3.24+** (Dart SDK `^3.11.5`)
- Supports Android, iOS, Web, and Desktop environments.

## Packages Used
- **State Management & Routing**: `provider`, `go_router`
- **Calling Core**: `flutter_webrtc`, `uuid`
- **Firebase Services**: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_database`, `firebase_messaging`, `firebase_storage`
- **UI & Aesthetics**: `google_fonts`, `flutter_animate`, `cached_network_image`
- **Hardware & Utilities**: `permission_handler`, `image_picker`, `connectivity_plus`, `intl`

## Architecture
The application strictly follows **Feature-first / Clean Architecture** principles to ensure long-term scalability and maintainability.
- **Layers**: UI Layer (Screens & Widgets) ➔ State Management (Provider) ➔ Services/Repositories ➔ Backend/API.
- **Signaling Mechanism**: A custom "Mesh" network signaling architecture implemented securely via **Cloud Firestore**.

## Backend Used
The entire backend infrastructure is powered by **Google Firebase**:
- **Authentication**: Email & Password auth.
- **Firestore**: Call signaling (SDP offers/answers, ICE candidates) and User data.
- **Realtime Database (RTDB)**: Low-latency presence tracking (online/offline).
- **Cloud Functions (Node.js)**: Serverless functions using the modern FCM Admin SDK (`sendEachForMulticast`) for dispatching push notifications.
- **Cloud Storage**: Secure hosting of user profile pictures with custom security rules.

## Calling SDK Used
Unlike many calling apps that rely on paid, proprietary solutions (like Agora, Twilio, or ZegoCloud), ConnectCall uses **pure `flutter_webrtc`**. This provides raw, highly-customizable WebRTC capabilities directly in Flutter, avoiding vendor lock-in.

## Setup Instructions
1. **Clone the repository**: `git clone <repository_url>`
2. **Install dependencies**: `flutter pub get`
3. **Configure Firebase**:
   - Install the Firebase CLI: `npm install -g firebase-tools`
   - Run `firebase login` and `flutterfire configure` to generate `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
4. **Deploy Backend Infrastructure**:
   - `firebase deploy --only functions` (Deploy Push Notification logic)
   - `firebase deploy --only storage` (Deploy Storage Security Rules)
5. **Run the app**: 
   - Ensure an emulator or physical device is connected.
   - Run `flutter run`.

## Environment Variables/Configuration
- A valid Firebase project is required.
- The `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files must be placed in their respective native directories.
- Firebase Cloud Messaging requires a downloaded service account key if running cloud functions locally, but works automatically when deployed to Firebase.

## Known Limitations
- **Screen Sharing Constraints**: Screen sharing is currently restricted to active Video Calls; attempting to share screens during an audio-only call is disabled.
- **iOS Background Executions**: Background incoming call handling on iOS requires deep integration with Apple's `CallKit`. Currently, Android handles background states smoothly via foreground services and FCM, while iOS prioritizes foreground execution.
- **Large Group Calls**: Because the app utilizes a "Mesh" signaling architecture (N-to-N connections), group calls scale linearly. For exceptionally large groups (e.g., 20+ participants), migrating to an SFU (Selective Forwarding Unit) architecture is recommended to preserve bandwidth and battery life.

## AI Tools Used
- Developed and heavily optimized using **Google Antigravity** (Advanced Agentic AI Coding Assistant).
