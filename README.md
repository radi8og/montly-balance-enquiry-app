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
- **Monthly History (archive)** — browse every past month in reverse chronological order via the navigation drawer, with a summary card per month (starting balance, income, expenses, net savings, ending balance). Past months are read-only — no adding, editing, or deleting.
- **CSV export** — export the current month or any archived month as a `.csv` file (with a running balance-after-transaction column) and share it via the native share sheet.
- **Backup & restore** — export all app data (balances, transactions, theme, currency) as a JSON backup file and share it; restore from a previously exported file, with validation and a confirmation prompt before any data is overwritten.
- **Category tags** — tag each transaction with a category (Food, Rent, Salary, Entertainment, and more), shown as an icon and label on every transaction row and included in CSV exports.
- **Recurring transactions** — set up fixed monthly items (Rent, Salary, subscriptions) that automatically generate a real transaction on the 1st of every month, with the option to pause or delete a rule at any time.
- **Category breakdown chart** — a pie chart with a legend showing where money went (or came from) this month or in any archived month, broken down by category with amounts and percentages.

---

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.3.2
  share_plus: ^10.1.2
  path_provider: ^2.1.4
  file_picker: ^8.1.3
  fl_chart: ^0.69.2
```

- `shared_preferences` — local persistence for balances, transactions, theme, and currency.
- `share_plus` — opens the native share sheet for CSV exports and JSON backups (mobile only — see Known Limitations).
- `path_provider` — resolves a temp directory to write export files to before sharing.
- `file_picker` — lets the user pick a `.json` file when restoring a backup, and provides the native "Save As" dialog for CSV/backup exports on desktop.
- `fl_chart` — renders the category breakdown pie chart.

---

## Project Structure

The app is organized into focused files rather than one large `main.dart`:

```
lib/
├── main.dart                       — entry point only, calls runApp(MyApp())
├── app.dart                        — MyApp widget: MaterialApp setup, theme mode state
├── models/
│   ├── transaction.dart            — Transaction data class (toJson/fromJson), now with category + recurringId
│   └── recurring_transaction.dart  — template for a fixed monthly item (Rent, Salary, etc.)
├── services/
│   ├── storage_service.dart        — all SharedPreferences reads/writes (per-month balances, transactions, recurring templates, theme, currency, backup export/import)
│   ├── csv_service.dart            — builds and saves/shares a month's transactions as CSV (includes Category column)
│   └── backup_service.dart         — builds/shares a full JSON backup, and validates/restores one
├── utils/
│   ├── currency_utils.dart         — shared money formatting and month-key helpers
│   └── category_utils.dart         — category lists, icons, and colors used across dialogs, lists, and the breakdown chart
├── theme/
│   ├── app_colors.dart             — color constants
│   └── app_theme.dart              — light/dark ThemeData
├── widgets/
│   ├── transaction_tile.dart       — shared transaction row (interactive or read-only), shows category + recurring marker
│   └── month_summary_card.dart     — shared balance summary card
└── screens/
    ├── balance_home_page.dart      — current month: balance card, search/filter, transaction list, drawer, dialogs
    ├── archive_screen.dart         — Monthly History: list of past months with summary cards
    ├── month_detail_screen.dart    — read-only view of a single archived month
    ├── recurring_transactions_screen.dart — manage recurring items: add, edit, pause, delete
    └── category_breakdown_screen.dart     — pie chart + legend of spending/income by category
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

### v2.0 — Monthly history, CSV export, and backup/restore
Three major features added in this release, plus a data-model change to support them:

1. **Past months' history (read-only archive)**
   - The starting balance storage model changed from a single value + month key to a `monthKey → balance` map, so every month's starting balance is now retained rather than overwritten. A one-time migration silently upgrades data saved by earlier versions.
   - A navigation drawer (opened from a new menu icon in the app bar) replaces what would otherwise have been a fourth app bar icon, keeping the header free of overflow risk.
   - "Monthly History" lists every past month in reverse chronological order, each as a summary card showing Starting Balance, Total Income, Total Expenses, and Net Savings / Ending Balance.
   - Tapping a month opens a read-only detail view — adding, editing, and swipe-to-delete are all disabled there. The current month is unaffected and remains fully interactive.

2. **CSV export**
   - "Export Month to CSV" is available for the current month (via the drawer) and for any archived month (via its detail screen).
   - The exported file includes ID, Date, Title, Type, Amount, and a running Balance After Transaction column computed chronologically from that month's starting balance.
   - Saved as `MonoBal_[YYYY-MM].csv` and shared through the native share sheet via `share_plus`.

3. **Backup & restore (JSON)**
   - "Data & Backups" in the drawer offers Export Backup and Import / Restore Backup.
   - Export serializes all starting balances, transactions, dark mode preference, and currency symbol into one JSON file (`monobal_backup_YYYY_MM_DD.json`) and opens the share sheet.
   - Restore lets the user pick a `.json` file, validates its structure before touching anything, then shows an explicit warning — *"Restoring will overwrite current local app data. Continue?"* — and only overwrites local storage on confirmation. The app automatically reloads its state afterward. Invalid or corrupted files are rejected with an error message rather than partially applied.

- **New files:** `services/csv_service.dart`, `services/backup_service.dart`, `utils/currency_utils.dart`, `widgets/transaction_tile.dart`, `widgets/month_summary_card.dart`, `screens/archive_screen.dart`, `screens/month_detail_screen.dart`. See Project Structure above.
- **New dependencies:** `share_plus`, `path_provider`, `file_picker`.

### v2.0.1 — Drawer access and export-file bug fixes
Two issues found shortly after v2.0 shipped:

1. **Drawer was unreachable**
   - **Issue:** The navigation drawer added in v2.0 had no button to open it — the app bar's custom app icon occupied the `leading` slot, so Flutter didn't auto-generate its usual hamburger button, leaving "Monthly History" and the rest of the drawer inaccessible.
   - **Fix:** Added an explicit menu icon (☰) as the first app bar action, wired to a `GlobalKey<ScaffoldState>` that opens the drawer directly.

2. **CSV and backup exports reported success but wrote nothing (desktop)**
   - **Issue:** On Windows/macOS/Linux, `share_plus`'s file-sharing support is unreliable and can silently drop the attached file, sharing only the text caption. Switching to `file_picker`'s native "Save As" dialog fixed the dialog appearing, but the file still wasn't written — `file_picker`'s `saveFile()` only returns the chosen path on desktop; it does not write the given bytes itself there, unlike on mobile/web.
   - **Fix:** `CsvService` and `BackupService` now branch by platform. Desktop writes the file explicitly to the path returned by the Save As dialog; mobile keeps using the `share_plus` share sheet, which works reliably there. Export feedback messages now show the actual saved path, or an accurate "cancelled" message if the Save As dialog was dismissed.

### v2.1 — Category tags, recurring transactions, and a spending breakdown chart
Three features added in this release:

1. **Category tags**
   - Every transaction can now be tagged with a category — Food, Rent, Transport, Entertainment, Utilities, Shopping, Health, or Other for expenses; Salary, Freelance, Gift, Investment, or Other for income.
   - The Add and Edit dialogs include a category dropdown (icon + name per option), scoped to the right list for the transaction's type.
   - Each transaction row shows a category-specific icon and the category name alongside the date.
   - Transactions saved before this field existed default to "Other" on load, so old data and old backups keep working without a manual migration step.
   - CSV exports now include a Category column between Title and Type.

2. **Recurring transactions**
   - "Recurring Transactions" in the drawer manages a list of fixed monthly templates (e.g. Rent, Salary, a subscription) — each with a title, amount, category, and an active/paused toggle.
   - On the 1st of every month, every *active* template automatically generates a real transaction for that month, without requiring the user to open the app on that exact date — generation runs on every app load and catches up on any month that hasn't been processed yet.
   - A separate "processed months" record (not the transaction list itself) tracks which templates have already fired for which months, so deleting a generated transaction afterward doesn't cause it to silently reappear on the next launch.
   - Auto-generated entries display a small repeat icon next to their title so they're visually distinguishable from manually-added ones.
   - Recurring templates and their processed-months record are included in JSON backups, so restoring a backup doesn't cause rules to re-fire and duplicate transactions.
   - Auto-generated expenses are added unconditionally, without the usual overspending validation — blocking a rent payment because the balance is momentarily too low would defeat the purpose of automating it.

3. **Category breakdown chart**
   - A new pie chart screen (via the `fl_chart` package) shows where money went — or came from — for a given month, broken down by category with a percentage-labeled legend below the chart.
   - An Expenses/Income toggle switches which side is charted.
   - Reachable from the drawer for the current month, and from a new icon on each archived month's detail screen — the same screen and logic serve both cases.
   - Each category has a fixed, distinct color, reused consistently between chart slices and legend swatches.

---

## Known Limitations / Future Scope

- Data is stored **locally per device only** — there's no shared backend, so transactions don't sync across devices or between users.
- Currency is a **display symbol only** — there's no real exchange-rate conversion, which is why switching currencies clears the current month's amounts rather than converting them. This also means archived months from before a currency change will render their stored numbers using whatever currency symbol is *currently* selected, since the symbol isn't stored per-transaction.
- Backups are plain, unencrypted JSON files — anyone with the file can read its contents, so treat exported backups like any other personal financial data.
- On desktop (Windows/macOS/Linux), CSV and backup exports use a native "Save As" dialog rather than a share sheet, since `share_plus` doesn't reliably support file sharing on those platforms. Mobile (Android/iOS) uses the native share sheet as usual.
- Recurring items are only scoped to "the 1st of every month" — there's no option for a different day of the month, a different frequency (weekly, yearly), or an end date.

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
