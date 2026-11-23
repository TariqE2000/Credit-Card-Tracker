# Credit Card Tracker

**Never forget to pay a card again.**

An iPhone app that keeps all your credit card balances and due dates in one calm place.

If you carry several credit cards, the numbers that matter (what you owe, the minimum payment, the day it
is due) are scattered across a different app or statement for each issuer. Credit Card Tracker puts them on
one screen so you can see your total balance and what is due next without logging in to anything.

> **Status: early MVP.** The onboarding flow is built. The home screen, real sign-in and saving your
> data are not built yet. See [What works today](#what-works-today) and [What is not built yet](#what-is-not-built-yet).

## How it works

The MVP is **manual entry**. There is no bank connection and no paid data provider. You choose your cards
from a catalog, then type in what you can read off your latest statement or your issuer's app:

| Field | Required to continue? | Notes |
| --- | --- | --- |
| Balance owed | Yes | A dollar amount, like `2480.15` |
| Minimum payment | Yes | A dollar amount |
| Due date | Yes | Month and day only (`MM / DD`), because a due date repeats every month. Type it or pick it from a calendar. |
| Interest rate (APR) | No | A percent, like `24.99` |

A card whose three required fields are filled in counts as **complete**. You can skip details for a card
and add them later; skipped cards are marked **Incomplete** and do not count toward your totals until you
fill them in.

Plaid, Method and Spinwheel (services that read balances straight from your accounts) were looked at and
are parked for later. Nothing in the app talks to your bank.

## What works today

The onboarding flow, one screen per pull request:

1. **Sign up.** "Continue with Apple" and "Continue with Google" buttons, with a link to log in instead.
   The buttons move you to the next screen; they do not sign anyone in yet.
2. **Log in.** The same two buttons, with a link back to sign up.
3. **Pick your cards.** A searchable list (by card name or bank) of cards with a colored badge or the
   issuer's logo. Select as many as you like; the button counts them ("Continue with 3 cards"). If your
   card is not in the list, tap **My card is not listed** and type its name on the next screen.
4. **Card form.** One form per card, with a "Card 2 of 4" progress label. It shows the balance, minimum
   payment, due date and APR fields. **Save and continue** checks that balance, minimum payment and due
   date are filled in and shows red messages for anything missing or unreadable. **Skip details for now**
   is the only way past a card without details.
5. **Review cards.** Every picked card with its balance and due date, the total balance, and an
   **Incomplete** tag on cards with missing details. From here you can:
   - **Edit** a card, or tap **Add details** on an incomplete one. Both open the same form in edit mode,
     where **Remove this card** also lives (it asks you to confirm),
   - **Add another card**, which reopens the card picker with the cards you already have locked, runs the
     form only for the new cards, and returns you to Review,
   - **Confirm and finish**, which ends onboarding.

There is deliberately no back button or swipe-back on the Review screen, because everything on it can be
edited in place.

After you confirm, a placeholder screen shows how many cards you are tracking. The real home screen is
the next piece of design work.

## What is not built yet

- **Home screen.** Not designed yet. A placeholder stands in.
- **Real sign-in.** The plan is Supabase Auth with Sign in with Apple and Google. The code has
  `TODO(supabase)` markers where the token exchange goes.
- **Saving your data.** Everything lives in memory. If you quit the app, your cards are gone. The plan is
  to save them to the user's account in Supabase.
- **Reminders for due dates.** The tagline promises this; nothing is built for it yet.
- **A bigger card catalog.** See [The card catalog](#the-card-catalog).

## The card catalog

Today the catalog is a **hard-coded list of 13 cards from 8 issuers** in `Models/CardCatalog.swift`:
Chase, American Express, Capital One, Citi, Discover, Wells Fargo, Bank of America and Apple. That is only
a stand-in.

The next step is to replace it with a real, free dataset. The leading candidate is
[opencard-db](https://github.com/thedavidweng/opencard-db), an open-source database of credit card
products (code MIT, data CC BY 4.0). Its US data covers hundreds of cards across about 50 issuers and can be
bundled inside the app as a small JSON file, so it needs no network call, no API key and has no rate limit.
If we use it, the app will credit it in a data-sources screen and in this README. This has not been
decided or built yet.

Cards that are not in the catalog are handled by **My card is not listed**.

## Issuer logos

Logos come from [LogoAPI.sh](https://logoapi.sh), which needs no key, no sign-up and no attribution on its
free tier (capped at 2 million requests a month per site).

- Each catalog entry can carry a `logoDomain`, the issuer's website, such as `capitalone.com`.
- The app asks for `https://logoapi.sh/icon/{domain}.png` as a PNG, because iOS image views cannot draw
  SVG, with `fallback=404` so a missing logo comes back as an error instead of a stand-in picture.
- The logo is shown on a white tile in the card's badge once it has loaded. **If it cannot load, the
  colored badge with the issuer's initials stays.** The colored badge is always underneath, so the screen
  never has a blank spot.
- Chase and Citi are not in LogoAPI.sh's catalog, so those cards show the colored badge.
- In debug builds, a failed logo prints lines starting with `[Logo]` in the Xcode console explaining why.

To add a logo for another issuer, set `logoDomain` on its entry in `CardCatalog`.

## Tech

| | |
| --- | --- |
| Language and UI | Swift 5.9, SwiftUI |
| Platform | iPhone only, iOS 17.0 and later, portrait |
| Project generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml` (the `.xcodeproj` is generated and not committed) |
| Dependencies | None. The app uses only Apple frameworks. |
| Backend | None yet. Supabase is planned for sign-in and saving. |
| Appearance | Light and dark mode, using the onboarding design's colors |
| Font | Inter, falling back to the system font until the font files are added to the bundle |

### How the code is organized

```
CreditCardTracker/
  App/            App entry point and RootView (onboarding until finished, then home)
  DesignSystem/   Theme (colors, sizes), buttons, card badge, logo, back button
  Models/         CatalogCard, CardCatalog, TrackedCard, CardDetails, DueDate
  Onboarding/
    OnboardingStore.swift   The one shared state object for the whole flow
    OnboardingFlow.swift    The NavigationStack and its routes
    FormInput.swift         Reads and formats what the user types
    Screens/                Sign up, Log in, Pick cards, Card form, Review
    Components/             Rows, form pieces, social buttons, due date picker sheet
  Home/           Placeholder home screen
CreditCardTrackerTests/     Unit tests
```

A few design choices worth knowing:

- **One store drives onboarding.** `OnboardingStore` holds the selected cards, their details and the
  navigation path. Screens read it and call its methods; the rules (what is complete, what is locked, which
  card comes next) live there so they can be unit tested.
- **Navigation is a route list.** `NavigationStack` is bound to `OnboardingStore.path`, an array of
  `OnboardingRoute` values (log in, pick cards, add cards, card form, edit card, review).
- **Custom back button.** Pushed screens hide the system bar and use their own `BackButton`. A small
  gesture delegate keeps the edge swipe-back working, and a per-screen lock turns it off on Review. iOS 26
  added a "swipe anywhere to go back" gesture, which the lock also disables.
- **Due dates are month and day only.** `DueDate` has no year; the calendar picker opens on the next time
  that day comes around and stores just the month and day.
- **Money uses `Decimal`**, never floating point.

## Run it

You need a Mac with Xcode 15 or newer.

```sh
brew install xcodegen      # once
xcodegen                   # creates CreditCardTracker.xcodeproj from project.yml
open CreditCardTracker.xcodeproj
```

Pick an iPhone simulator and press Run (⌘R). Run the tests with ⌘U.

The Xcode project is generated, so it is not committed. If you add, move or delete files, run `xcodegen`
again.

## How the project is built

Work is split into **stacked pull requests, one feature each**. Each pull request is based on the branch of
the one before it, so they are reviewed and merged in order:

Project foundation, then sign up, log in, pick your cards, card form, review, not-listed cards with a date
picker, add another card, and issuer logos.

## Placeholders to replace

- Bundle ID `com.tariqe2000.creditcardtracker` in `project.yml`.
- The app icon (the `AppIcon` set is empty).
- The Inter font files. Until they are added to the app bundle, the system font is used.
- The Terms of Service and Privacy Policy links in `Onboarding/AppLinks.swift`, which point to
  `example.com`.
- Sign in with Apple and Google, as described above.

## License

No license has been chosen yet.
