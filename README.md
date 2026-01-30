# Pelaporan D3TI UNS Mobile App

A mobile application developed for D3TI UNS to facilitate the reporting of incidents and sexual violence cases. This app serves both students (Mahasiswa) and faculty members (Dosen), providing a secure and accessible platform for submitting and managing reports.

## Features

### General
*   **Authentication**: Secure login for both Students and Faculty. Student registration is also supported.
*   **Native Splash Screen**: Professional startup experience.
*   **Notifications**: Real-time updates using local notifications.
*   **Recaptcha**: Integration for security.

### For Students (Mahasiswa)
*   **Dashboard**: Centralized view of activities.
*   **Incident Reporting (Pelaporan Kejadian)**:
    *   Submit new incident reports.
    *   Submit urgent (mendesak) reports.
    *   View history and details of submitted reports.
*   **Sexual Violence Reporting (Pelaporan Kekerasan Seksual)**:
    *   Dedicated channel for sensitive reporting.
    *   Submit reports with necessary details.

### For Faculty (Dosen)
*   **Faculty Dashboard**: Specialized view for faculty members.
*   **Manage Incident Reports**: View and process incident reports.
*   **Manage Sexual Violence Reports**: Handle sensitive cases with appropriate privacy.

## Tech Stack

*   **Framework**: Flutter
*   **Language**: Dart
*   **State Management**: Provider
*   **Networking**: Dio, Http
*   **Local Storage**: Shared Preferences
*   **Notifications**: Flutter Local Notifications
*   **UI/UX**: Google Fonts (Poppins), Cupertino Icons, Shimmer Animation

## Project Structure

The project follows a feature-based folder structure:

```
lib/
├── auth_screen/                  # Authentication screens (Login, Register)
├── components/                   # Shared UI components
├── dosen/                        # Faculty-specific features
│   ├── home/                     # Faculty dashboard
│   ├── pelaporan_kejadian/       # Incident reporting for Faculty
│   └── pelaporan_kekerasan_seksual/ # Sexual violence reporting for Faculty
├── kekerasan_seksual/            # Shared/Public sexual violence resources
├── mahasiswa/                    # Student-specific features
│   ├── home_screen/              # Student dashboard
│   ├── pelaporan_kejadian/       # Incident reporting for Students
│   └── pelaporan_kekerasan_seksual/ # Sexual violence reporting for Students
├── models/                       # Data models
├── services/                     # API and Notification services
├── settings/                     # Settings screen
├── splash_screen/                # Splash screen logic
└── main.dart                     # Entry point and routing
```

## Getting Started

1.  **Prerequisites**: Ensure you have Flutter installed (`flutter doctor`).
2.  **Dependencies**: Run `flutter pub get` to install required packages.
3.  **Run**:
    *   To run on an emulator or device: `flutter run`

## Assets

*   Images are stored in `assets/images/`.
*   Font configuration uses Google Fonts.

## Version

Current version: 1.0.0+1
