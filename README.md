
# CareBridge

**CareBridge** is a mobile application designed to foster community connection and support, inspired by the "Harmony Hub" concept. The app bridges the gap between volunteers, donors, organizations, and vulnerable groups, promoting a culture of kindness and support.

---

## Table of Contents

- [Problem Statement](#problem-statement)
- [Solution](#solution)
- [Features](#features)
- [Getting Started](#getting-started)
- [Modules Overview](#modules-overview)
- [Future Improvements](#future-improvements)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

---

## Problem Statement

- Lack of a centralized platform to connect volunteers with community needs.
- Difficulty in organizing and promoting charity events effectively.
- Limited awareness of vulnerable groups and how to support them.
- Challenges in collecting and managing donations securely.
- Inefficient communication among volunteers, donors, and organizations.

---

## Solution

CareBridge provides:
- A user-friendly mobile app for organizations to post volunteer opportunities.
- A structured system for users to browse and participate in charity events.
- A dedicated section for articles that educate users on social issues.
- A built-in donation feature for secure transactions.
- A chat system for instant communication between users and organizations.

---

## Features

- **User Management:** Register, log in, edit profile, and manage account securely.
- **Volunteer & Donation Posts:** Create, view, edit, and manage posts for volunteering and donations.
- **Article Module:** Read, share, and listen to articles about vulnerable groups.
- **Chat Module:** Real-time messaging between users and organizations.
- **Notification Module:** Unread message indicators and notification page.
- **Donation Module:** Make donations easily with real-time progress tracking.
- **Donation History:** Track and view past contributions.

---

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install)
- [Dart](https://dart.dev/get-dart)
- [Firebase Account](https://firebase.google.com/)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/care_bridge.git
   cd care_bridge
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup:**
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective directories.
   - Configure Firebase Authentication and Firestore in the Firebase Console.

4. **Run the app:**
   ```bash
   flutter run
   ```

---

## Modules Overview

### User Management
- Register, log in, and manage user profiles.
- Email verification and password requirements.
- Profile setup with username and profile picture.
- Data stored securely in Firebase Firestore.

### Login & Registration
- Secure login with Firebase Authentication.
- Account lockout after 3 failed attempts.
- Password reset via email.

### Profile
- View and edit profile details.
- Real-time updates with Firebase and local cache.
- Text-to-speech (TTS) for accessibility.

### Settings
- Change password and log out.
- Securely update credentials and clear local data.

### View Profile
- View other users’ profiles and posts.
- Messaging features for direct communication.

### Article Module
- Browse, read, and share articles.
- TTS and sharing as images supported.

### Post Module
- Create, edit, and delete volunteer/donation posts.
- Restrictions for post integrity.

### Chat Module
- Recent chats, new chat creation, and full conversation view.
- User-friendly chat interface.

### Notification Module
- Unread message indicators.
- Notification page with message details.

### Donation Module
- Make donations with e-wallet or online transaction.
- Real-time campaign progress and confirmation.

### Donation History
- Track and view past donations.

---

## Future Improvements

- AI-powered recommendations for volunteer opportunities.
- Social media integration for better outreach.

---

