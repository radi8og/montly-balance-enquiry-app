# MonoBal - The Monthly Balance Tracker 

A simple Flutter app to track your bank balance and spending for the **current month only**. Set a starting balance, log income and expenses, and watch your balance update in real time.

Built it for myself and people like me!

---

## Features

- **Monthly balance tracking** — balance is calculated as `starting balance + this month's transactions`, scoped to the current calendar month.
- **Add Income / Expense** — two floating action buttons open a simple dialog to log a transaction with a title and amount.
- **Delete transactions** — swipe left on any transaction or tap the trash icon, with a confirmation prompt before removal.
- **Local persistence** — starting balance and transaction history are saved on-device using `shared_preferences`, so data survives app restarts.
- **Dark mode** — toggle between light and dark themes via the app bar icon; preference is remembered across sessions.
- **Reset starting balance** — a confirmation-gated option to correct the starting balance mid-month without touching existing transaction history.

---

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.3.2
```

No other third-party packages are required — everything else uses Flutter's built-in widgets and APIs.

---

## Change Log

### v1.0 — Initial build
- Basic UI: current balance display, list of transactions, floating buttons to add income/expense.
- In-memory only — data was lost when the app closed.

### v1.1 — Persistence added
- Integrated `shared_preferences` to save starting balance and transactions as JSON.
- Data now loads on app launch and survives restarts.

### v1.2 — Delete functionality
- Added swipe-to-delete (`Dismissible`) and a trash icon on each transaction.
- Delete requires confirmation via dialog.
- Balance recalculates automatically after deletion (derived getter, no manual math needed).
- Added a unique `id` field to the `Transaction` model for reliable deletion targeting.

### v1.3 — Mobile layout fix
- **Bug:** Two `FloatingActionButton.extended` widgets (with text labels) in a `Row` could overflow horizontally on narrow phone screens.
- **Fix:** Switched to compact icon-only `FloatingActionButton`s with tooltips, removing the overflow risk entirely.

### v1.4 — Balance validation & dialog fixes
Four issues fixed in this release:

1. **Negative balance bug**
   - **Issue:** Balance could go below zero if an expense exceeded the available balance.
   - **Fix:** Expenses are now validated against the current balance before being added (see #4 below); this eliminates the negative-balance scenario at the source.

2. **Starting balance dialog UX**
   - **Issue:** No cancel option; dialog handling was incomplete.
   - **Fix:** Added a **Cancel** button and explicit `Navigator.pop()` handling on both Save and Cancel.

3. **Ask for starting balance only once per month**
   - **Issue:** The balance-edit icon allowed changing the starting balance at any time, which could silently distort the "monthly" tracking concept.
   - **Fix:** The starting balance is now saved alongside the month/year it applies to. If it matches the current month on load, it's reused automatically with no prompt. It only prompts fresh at the start of a new month. The free-edit icon was removed from this flow.

4. **Prevent overspending**
   - **Issue:** Users could log an expense larger than their current balance.
   - **Fix:** The "Add Expense" dialog now checks the amount against the current balance. If insufficient, an inline error appears (e.g. *"Insufficient balance (₹30.00 available)"*) and the transaction is blocked. Income has no such restriction.

### v1.5 — Reset balance option (mid-month correction)
- Reintroduced a way to correct starting balance mistakes without violating the "once per month" rule from v1.4.
- Tapping the reset icon now shows a confirmation dialog explaining the effect before the edit dialog opens.
- The edit dialog is pre-filled with the current value (not blank), and existing transactions are never modified — only the starting balance changes, with the displayed balance recalculating instantly.

### v1.6 — Dismissible starting balance dialog
- **Issue:** The starting balance dialog could only be closed via its buttons.
- **Fix:** Set `barrierDismissible: true`, so tapping anywhere outside the dialog now closes it (same effect as Cancel).

### v1.7 — Dark mode
- Added a light/dark theme toggle (sun/moon icon) in the app bar.
- Preference is persisted via `shared_preferences` (`dark_mode` key) and restored on app launch.
- Both themes share the same teal color scheme; only brightness changes, keeping income/expense color coding readable in both modes.

---

## Known Limitations / Future Scope

- Data is stored **locally per device only** — there's no shared backend, so transactions don't sync across devices or between users.
- Only the current month is viewable; past months' data is retained in storage but not yet browsable in the UI.
- No authentication or multi-user support — relevant if this evolves into a shared/family expense tracker for SIH.

---

## Getting Started

```bash
flutter pub get
flutter run
```

To build a shareable release APK:

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`
