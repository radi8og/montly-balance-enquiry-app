# MonoBal - The Monthly Balance Tracker 

A simple Flutter app to track your bank balance and spending for the **current month only**. Set a starting balance, log income and expenses, and watch your balance update in real time.

Built it for myself and people like me!

---

## Features

- **Monthly balance tracking** — balance is calculated as `starting balance + this month's transactions`, scoped to the current calendar month.
- **Add Income / Expense** — two floating action buttons open a simple dialog to log a transaction with a title and amount.
- **Edit transactions** — tap any transaction to update its title or amount, with the same overspending validation applied as new entries.
- **Search & filter** — a search bar filters transactions by title in real time, alongside `All` / `Income` / `Expenses` filter chips.
- **Delete transactions** — swipe left on any transaction or tap the trash icon, with a confirmation prompt before removal.
- **Local persistence** — starting balance and transaction history are saved on-device using `shared_preferences`, so data survives app restarts.
- **Dark mode** — toggle between light and dark themes via the app bar icon; preference is remembered across sessions.
- **Currency selection** — choose between ₹, $, €, and £ from the app bar; the choice persists across sessions and updates every balance/amount display and validation message throughout the app.
- **Reset starting balance** — a confirmation-gated option to correct the starting balance mid-month, which also clears that month's logged transactions for a clean restart.

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

## Project Structure

The app is organized into focused files rather than one large `main.dart`:

```
lib/
├── main.dart                     — entry point only, calls runApp(MyApp())
├── app.dart                      — MyApp widget: MaterialApp setup, theme mode state
├── models/
│   └── transaction.dart          — Transaction data class (toJson/fromJson)
├── services/
│   └── storage_service.dart      — all SharedPreferences reads/writes (balance, transactions, theme, currency)
└── theme/
│   ├── app_colors.dart           — color constants
│   └── app_theme.dart            — light/dark ThemeData
└── screens/
    └── balance_home_page.dart    — main UI: balance card, search/filter, transaction list, dialogs
```

`storage_service.dart` is the only file that talks to `shared_preferences` directly — every other file goes through it.

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

### v1.8 — Reset balance now clears the month's transactions
- **Issue:** Resetting the starting balance mid-month left old transactions in place, causing the balance to no longer match the intended fresh start.
- **Fix:** Resetting the starting balance now clears all transactions logged for the current month before applying the new value. First-time balance setup is unaffected, since there are no transactions to clear at that point. The reset confirmation dialog's wording was updated to reflect this.

### v1.9 — Edit transactions, search & filter, currency support
Three features added in this release:

1. **Edit existing transactions**
   - Tapping any transaction in the list opens an Edit dialog pre-filled with its title and amount.
   - The transaction's type (income/expense) stays fixed; only title and amount are editable.
   - Editing an expense re-validates it against the current balance — with the transaction's own prior amount excluded from that check first, so re-saving the same value never falsely triggers an "insufficient balance" error.
   - Cancel discards changes; Save updates the entry in place and persists it.

2. **Search & filter bar**
   - A search field above the list filters transactions by title in real time.
   - `All` / `Income` / `Expenses` filter chips narrow the list further, combining with the search query.
   - Chips scroll horizontally to avoid overflow on narrow screens.

3. **Currency symbol support**
   - A currency picker in the app bar offers ₹, $, €, and £.
   - The selection is saved via `shared_preferences` and restored on launch.
   - Every balance display, transaction amount, and validation message updates to the chosen symbol.

- **Refactor:** the app was also restructured from a single `main.dart` into the modular `lib/` folder layout described above (models, services, theme, screens), with no functional changes.

### v1.9.1 — Currency change resets balance and transactions
- **Issue:** Changing the currency symbol left the existing starting balance and transactions in place, even though their amounts were recorded in a different currency and can't be auto-converted.
- **Fix:** Changing currency now shows a confirmation dialog explaining the effect. On confirmation, the current month's starting balance and transactions are fully cleared (both in memory and in persisted storage), and the user is immediately prompted to set a new starting balance in the newly selected currency. Picking the currency already in use is a no-op.

---

## Known Limitations / Future Scope

- Data is stored **locally per device only** — there's no shared backend, so transactions don't sync across devices or between users.
- Only the current month is viewable; past months' data is retained in storage but not yet browsable in the UI.
- Currency is a **display symbol only** — there's no real exchange-rate conversion, which is why switching currencies clears existing amounts rather than converting them.

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
