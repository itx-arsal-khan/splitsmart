# SplitSmart 💸

SplitSmart is a modern, sleek, and dynamic bill-splitting and expense management application built with **Flutter** and **Firebase**. It takes the hassle out of shared expenses by allowing users to create groups, add bills, and easily keep track of "who owes who." 

With its smooth animations, pill-shaped modern UI, and real-time database synchronization, SplitSmart offers a premium user experience for managing finances with friends, family, or roommates.

---

## ✨ Key Features

* **Real-Time Synchronization:** Powered by Firebase Cloud Firestore. All groups, bills, and balances sync instantly across devices.
* **Authentication:** Secure user sign-up and login using Firebase Authentication.
* **Modern, Dynamic UI:** Features a completely custom design system with highly rounded (pill-shaped) inputs, bouncy micro-animations for button presses and cards, and a vibrant color palette.
* **Smart Dashboard:** 
  * Instantly view the **"Who Owes Who"** breakdown.
  * Access **Quick Actions** like "Add a Bill" and "Settle Up".
  * Scroll through a horizontal list of your active groups.
  * View a chronological **Recent Activity** timeline.
* **Group Management:**
  * Create custom groups (e.g., Trip, Home, Couple, Event).
  * Add or remove members from your groups by searching registered users.
  * Delete groups when they are no longer needed (automatically clears associated bills).
* **Expense Tracking:** 
  * Add detailed bills with custom titles, amounts, and category icons.
  * Costs are automatically distributed among group members.
* **Seamless "Settle Up" Flow:** 
  * Settle debts directly from the main dashboard or from within a specific group.
  * Interactive "Select Member" screens make it foolproof to pay back exact amounts.
  * Generates settlement receipts in the activity timeline.

---

## 🛠 Tech Stack

* **Frontend:** [Flutter](https://flutter.dev/) (Dart)
* **Backend:** [Firebase](https://firebase.google.com/)
  * **Firebase Authentication** (User identity management)
  * **Cloud Firestore** (NoSQL database for real-time data storage)

---

## 📂 Project Structure

```text
lib/
│
├── main.dart                 # Application entry point & Theme setup
├── screens/                  # All app screens (UI)
│   ├── login_screen.dart     # User authentication
│   ├── home_dashboard.dart   # Main dashboard 
│   ├── group_detail_screen.dart # Group specifics and member balances
│   ├── add_bill_screen.dart  # Form to add new expenses
│   ├── settle_up_flow_screen.dart # Member selection for settling debts
│   ├── history_screen.dart   # Timeline of all activities and bills
│   └── ...                   
│
├── services/                 
│   └── backend_service.dart  # Centralized Firebase logic (Auth, Firestore CRUD)
│
├── theme/                    
│   ├── app_colors.dart       # Curated color palette
│   └── app_styles.dart       # Typography, Spacing, and corner Radii (radiusXl)
│
└── widgets/                  # Reusable UI components
    ├── custom_button.dart    # Animated bouncy buttons
    ├── custom_card.dart      # Animated bouncy cards
    ├── custom_text_field.dart# Pill-shaped modern inputs
    └── avatar_widget.dart    # User profile initials
```

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (Latest Version)
* Android Studio / VS Code
* A Firebase Account

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/splitsmart_app.git
   cd splitsmart_app
   ```

2. **Fetch Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   * Create a new project in the [Firebase Console](https://console.firebase.google.com/).
   * Add an Android and/or iOS app to your Firebase project.
   * Download the `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) and place them in their respective native folders.
   * Ensure Firestore Database and Firebase Authentication (Email/Password) are enabled in your console.

4. **Run the App**
   ```bash
   flutter run
   ```

*(Note: When you create a new account for the first time, SplitSmart will automatically generate demo data (friends, groups, and bills) so you can immediately interact with the dashboard!)*
