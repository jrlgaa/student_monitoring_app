# Forgot Password Feature Implementation TODO

## Status: In Progress

### Step 1: [DONE] Create new lib/auth/forgot_password_page.dart
- Stateful widget w/ theme props
- Email verification phase
- Password reset phase
- DB logic extraction

### Step 2: [DONE] Update lib/auth/login_page.dart
- Remove inline forgot password logic
- Add Navigator.push to new page
- Clean up removed UI/state

### Step 3: [DONE] Update lib/main.dart
- Add /forgot-password route

### Step 4: [PENDING] Test & Verify
- flutter pub get (if needed)
- flutter run
- Test full flow: nav → email verify → reset → back to login → login w/ new pass

Completed steps will be marked [DONE]

### Step 3: [PENDING] Update lib/main.dart
- Add /forgot-password route

### Step 4: [PENDING] Test & Verify
- flutter pub get (if needed)
- flutter run
- Test full flow: nav → email verify → reset → back to login → login w/ new pass

Completed steps will be marked [DONE]
