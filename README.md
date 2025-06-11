# Hangout

A Flutter-based mobile application that helps users find fun and interesting activities for their hangouts using AI-powered suggestions and location-based services developed by ITDOGTICS.

## Features

- AI-powered hangout suggestions using Google Generative AI
- Location-based activity recommendations
- Interactive map integration
- Secure user preferences storage
- Firebase Analytics integration for app insights

## Tech Stack

- **Framework**: Flutter 3.6.1+
- **AI Services**: Google Generative AI
- **Backend**: Firebase
- **Location Services**: Geolocator
- **Map Integration**: Flutter Map
- **State Management**: Provider
- **Storage**: Flutter Secure Storage

## Getting Started

### Prerequisites

- Flutter SDK (version 3.6.1 or higher)
- Dart SDK
- Firebase account
- Google Cloud account (for Google Generative AI)

### Installation

1. Clone the repository
2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Create a Firebase project
   - Add your app to the Firebase project
   - Download and place the configuration files in your project

4. Configure Google Generative AI:
   - Create a Google Cloud project
   - Enable the Generative AI API
   - Set up authentication credentials

### Running the App

```bash
flutter run
```

## Project Structure

```
hangout/
├── lib/                  # Source code
├── assets/               # Static assets
├── test/                 # Test files
├── web/                  # Web-specific files
└── .firebase/           # Firebase configuration
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
