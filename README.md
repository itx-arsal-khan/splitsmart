# 💸 SplitSmart - Shared Expenses Made Simple

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

**SplitSmart** is a cross-platform mobile application built with Flutter and Firebase that takes the headache and awkwardness out of splitting shared expenses. Whether you're traveling with friends, living with roommates, or organizing an event, SplitSmart automatically tracks exactly who owes whom in real-time.

## ✨ Features

- **Custom Groups:** Organize expenses by trip, event, or household.
- **Flexible Bill Splitting:** Add bills and split them equally or enter custom amounts.
- **Intelligent Dashboard:** An algorithmic dashboard that simplifies complex group debts into an easy-to-read "Who Owes Who" summary.
- **Daily Reminders:** Automated local push notifications gently remind users of their pending balances so you don't have to.
- **Frictionless Onboarding:** Easily invite friends to your group via WhatsApp using deep links and unique group codes.
- **Real-Time Sync:** Powered by Firebase Firestore, ensuring that all group members see updates instantly.

## 📱 Screenshots

| Home Dashboard | Group Details | Add a Bill | Settle Up |
| --- | --- | --- | --- |
| ![Home](<img width="738" height="1600" alt="image" src="https://github.com/user-attachments/assets/d991208a-410f-4268-8ab5-0d94afc45591" />
) | ![Group](<img width="738" height="1600" alt="image" src="https://github.com/user-attachments/assets/e593334e-8046-4400-9c2d-46ef3e69de46" />
) | ![Bill](<img width="738" height="1600" alt="image" src="https://github.com/user-attachments/assets/811b1f32-b028-4ae8-bfb8-6713cabd5a5a" />
) | ![Settle](<img width="738" height="1600" alt="image" src="https://github.com/user-attachments/assets/4629b76c-75c3-4879-ae51-72c2c7361bdb" />
) |

## 🛠️ Technology Stack

- **Frontend:** Flutter (Dart)
- **Backend (BaaS):** Firebase (Firestore NoSQL Database)
- **Authentication:** Firebase Auth
- **State Management:** Flutter standard state management
- **Key Plugins:** `flutter_local_notifications`, `share_plus`, `app_links`

## 🚀 Getting Started

To run this project locally, follow these steps:

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
- Android Studio or VS Code set up for Flutter development.
- A Firebase account (to connect your own backend).

### Installation
1. **Clone the repository:**
   ```bash
   git clone https://github.com/itx-arsal-khan/splitsmart.git
   cd splitsmart
   ```
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```
3. **Connect to Firebase:**
   - Create a project on the Firebase Console.
   - Run `flutterfire configure` to link this app to your Firebase project.
   - Make sure to enable Firestore and Email/Password Authentication in the Firebase Console.
4. **Run the app:**
   ```bash
   flutter run
   ```

## 👥 The Team

This app was proudly built as a semester project by:
- **Arsal Khan** - *Lead Developer*
- **Abdul Haseeb** - *Developer / Contributor*
- **Asim Nawaz** - *Developer / Contributor*

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
