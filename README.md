# TPH MyLeave

## Getting Started

This project is a starting point for a Flutter application.

Create a `test.env` file from `.env.example` before running the app:

```bash
cp .env.example test.env
```

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


You can put a **short architecture explanation** in your GitHub README like this:

---

# 📁 Project Folder Structure

This project follows a **feature-based architecture with service and provider layers**, making the code modular, scalable, and easy to maintain.

```
lib
│
├── main.dart
├── core
├── models
├── services
├── features
├── widgets
└── providers
```

---

# 📂 Folder Responsibilities

## `main.dart`

Application entry point.

Responsibilities:

* Initialize Supabase
* Setup global providers
* Configure the main app widget
* Load the application router

---

## `core/`

Contains **shared infrastructure code used across the entire app**.

### `config/`

Application configuration.

Example:

* Supabase initialization
* API endpoints
* environment settings

```
supabase_config.dart
```

---

### `constants/`

Central place for **static constants** used across the app.

Examples:

* role names
* leave statuses
* default values

```
app_constants.dart
```

---

### `router/`

Handles **application navigation and routing**.

Responsibilities:

* define app routes
* manage navigation between pages
* protect routes (auth check)

```
app_router.dart
```

---

### `utils/`

Reusable helper functions used throughout the project.

Examples:

* date formatting
* form validation
* small utility functions

```
date_utils.dart
validators.dart
```

---

# 📂 `models/`

Defines **data models representing database entities**.

Each model corresponds to a **Supabase table**.

Examples:

| Model                | Purpose                               |
| -------------------- | ------------------------------------- |
| `company.dart`       | Company information                   |
| `employee.dart`      | Employee profile                      |
| `leave_request.dart` | Leave application record              |
| `leave_type.dart`    | Types of leave (Annual, Medical etc.) |

Models are responsible for:

* JSON serialization
* mapping database records
* structuring application data

---

# 📂 `services/`

Handles **communication with Supabase backend**.

Responsibilities:

* authentication
* database queries
* CRUD operations

Services isolate backend logic from UI.

Examples:

| Service                 | Responsibility           |
| ----------------------- | ------------------------ |
| `auth_service.dart`     | login / logout           |
| `company_service.dart`  | company related queries  |
| `employee_service.dart` | employee management      |
| `leave_service.dart`    | leave request operations |

---

# 📂 `features/`

Contains **feature-based UI modules**.

Each feature groups together:

* pages
* controllers
* feature logic

This improves **code organization and scalability**.

---

## `auth/`

Authentication module.

Files:

```
login_page.dart
register_page.dart
auth_controller.dart
```

Responsibilities:

* user login
* registration
* auth state management

---

## `dashboard/`

Main landing page after login.

```
dashboard_page.dart
```

Displays:

* summary
* quick actions
* navigation to other features

---

## `leave/`

Employee leave application module.

Files:

```
apply_leave_page.dart
leave_history_page.dart
leave_details_page.dart
leave_controller.dart
```

Responsibilities:

* submit leave requests
* view leave history
* display leave details

---

## `approval/`

Manager leave approval module.

Files:

```
approval_list_page.dart
approval_details_page.dart
approval_controller.dart
```

Responsibilities:

* view pending leave requests
* approve / reject leave

---

## `company/`

Company management module.

Files:

```
company_page.dart
company_controller.dart
```

Responsibilities:

* manage company information
* manage employees

---

# 📂 `widgets/`

Reusable UI components used across multiple pages.

Examples:

| Widget                   | Purpose                   |
| ------------------------ | ------------------------- |
| `primary_button.dart`    | consistent button style   |
| `loading_indicator.dart` | loading spinner           |
| `leave_card.dart`        | display leave information |

This improves **UI consistency and reduces code duplication**.

---

# 📂 `providers/`

Manages **application state using Provider**.

Providers act as a bridge between **UI and services**.

Examples:

| Provider                 | Responsibility       |
| ------------------------ | -------------------- |
| `auth_provider.dart`     | authentication state |
| `employee_provider.dart` | employee data        |
| `leave_provider.dart`    | leave request state  |

---

# 🧠 Architecture Overview

```
UI (features)
     ↓
providers (state management)
     ↓
services (Supabase API)
     ↓
database (Supabase)
```

This layered structure ensures:

* clean separation of concerns
* easier testing
* maintainable codebase
* scalable architecture

---
