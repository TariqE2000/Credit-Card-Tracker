# Credit Card Tracker

An iPhone app that keeps all your credit card balances and due dates in one calm place.

The MVP is **manual entry**: you pick your cards from a catalog, optionally fill in the balance,
minimum payment, due date and APR for each one, and land on a home screen. There is no paid
data provider (Plaid, Method, Spinwheel are parked for later).

## Run it

You need a Mac with Xcode 15 or newer.

```sh
brew install xcodegen      # once
xcodegen                   # creates CreditCardTracker.xcodeproj from project.yml
open CreditCardTracker.xcodeproj
```

Then pick an iPhone simulator and press Run (⌘R). Run the tests with ⌘U.

The Xcode project is generated, so it is not committed. If you add or move files, run `xcodegen` again.

## Status

Onboarding flow, built one screen per pull request:

1. Sign up
2. Log in
3. Pick your cards
4. Card form
5. Review cards

The home screen has not been designed yet.

## Placeholders to replace

- Bundle ID `com.tariqe2000.creditcardtracker` in `project.yml`.
- The app icon (empty `AppIcon` set).
- The Inter font. Until the font files are added to the app bundle, the system font is used.
- Sign in with Apple / Google: the buttons move to the next screen but do not sign anyone in yet.
