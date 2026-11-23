# Credit Card Tracker

**Never forget to pay a card again.**

An iPhone app that keeps all your credit card balances and due dates in one calm place.

If you carry several credit cards, the numbers that matter (what you owe, the minimum payment, the day it
is due) are scattered across a different app or statement for each issuer. Credit Card Tracker puts them on
one screen so you can see your total balance and what is due next without logging in to anything.

> **Status: early MVP.** The onboarding flow is built. The home screen, real sign-in and saving your
> data are not built yet. See [What works today](#what-works-today) and [What is not built yet](#what-is-not-built-yet).

## How it works

The MVP is **manual entry**. There is no bank connection and no paid data provider. You pick the banks
your cards come from and how many cards you have from each, then type in what you can read off your latest
statement or your issuer's app:

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
3. **Who issued your cards?** A searchable list of banks (Chase, American Express, Navy Federal…), each with
   a colored badge or its logo. Tick a bank, then use **−** and **+** to say how many cards you have from
   it (two Chase cards is "Chase × 2"). The button counts cards, not banks ("Continue with 3 cards"). If
   your bank is not in the list, tap **My bank is not listed** and type its name on the next screen.
4. **Card form.** One form per card, with a "Card 2 of 4" progress label. Two cards from the same bank are
   called "Chase 1" and "Chase 2". It shows the balance, minimum
   payment, due date and APR fields. **Save and continue** checks that balance, minimum payment and due
   date are filled in and shows red messages for anything missing or unreadable. **Skip details for now**
   is the only way past a card without details.
5. **Review cards.** Every picked card with its balance and due date, the total balance, and an
   **Incomplete** tag on cards with missing details. From here you can:
   - **Edit** a card, or tap **Add details** on an incomplete one. Both open the same form in edit mode,
     where **Remove this card** also lives (it asks you to confirm),
   - **Add another card**, which reopens the bank list with the banks you already have ticked (you can
     raise their count but not go below the cards you have), runs the form only for the new cards, and
     returns you to Review,
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
- **Pictures of each card.** The list holds banks, not individual cards, so there is no card art. Each card
  shows its bank's colored badge or logo for now. The plan is to build our own open logo set later.

## The issuer list

The banks on **Who issued your cards?** come from [opencard-db](https://github.com/thedavidweng/opencard-db),
an open-source database of credit cards (code MIT, data CC BY 4.0). At the pinned release, `v0.4.2`, it
knows **51 issuers with US cards**, from Chase to small credit unions and the partner banks behind store
and fintech cards. The app only needs the issuers, not the 435 cards.

How the app gets it:

1. **Two small downloads.** Plain HTTPS GETs to the jsDelivr CDN, which is free and needs no account, key
   or request limit (about 37 KB together):
   - `data/issuers.json`, the registry of every issuer and its name (US, Canada and China),
   - `exports/index-issuer.json`, each issuer's card IDs. A card ID starts with its country, so an issuer
     with at least one `us-` card is an American issuer. That is how the app keeps only the US ones.
2. **Saved on the phone.** The result is saved as one small file (a few KB, in Application Support and
   left out of iCloud backups). Later launches show it instantly and do not download again.
3. **Pinned to one release.** A tagged address never changes, so a mistake in opencard-db's newest data
   cannot break the app. To get newer issuers, change `IssuerCatalogSource.tag`, check that the bank list
   still loads, and ship an update. Tags are listed on
   [their releases page](https://github.com/thedavidweng/opencard-db/releases).
4. **If it fails.** With no internet on the very first launch, the screen shows a built-in list of 12
   popular banks (`BuiltInIssuers`) with a **Try again** button. **My bank is not listed** always works.
   A list saved earlier stays on screen if a later download fails. Files with fewer than 20 US issuers
   are treated as a failed download and are never saved.

A few registry names are replaced because they would confuse a US customer (`IssuerStyle.displayNames`):
"TD Canada Trust" is shown as "TD Bank", and the Apple Card's bank is shown as "Goldman Sachs (Apple Card)".

The data has no badge colors, so each issuer's badge comes from `IssuerStyle`: the colors the app already
used for the big banks, and a steady color made from the issuer's ID for everyone else. Big issuers are
listed first, then the rest alphabetically.

**Credit:** the CC BY 4.0 license asks for attribution, so the bottom of the list says "Bank list from
opencard-db (CC BY 4.0)" and links to the project.

## Issuer logos

Logos come from [LogoAPI.sh](https://logoapi.sh), which needs no key, no sign-up and no attribution on its
free tier (capped at 2 million requests a month per site).

- Each issuer can carry a `logoDomain`, its website, such as `capitalone.com`. The table of
  domains is in `IssuerStyle`.
- The app asks for `https://logoapi.sh/icon/{domain}.png` as a PNG, because iOS image views cannot draw
  SVG, with `fallback=404` so a missing logo comes back as an error instead of a stand-in picture.
- The logo is shown on a white tile in the issuer's badge once it has loaded. **If it cannot load, the
  colored badge with the issuer's initials stays.** The colored badge is always underneath, so the screen
  never has a blank spot.
- Chase and Citi are not in LogoAPI.sh's catalog, so those banks show the colored badge.
- In debug builds, a failed logo prints lines starting with `[Logo]` in the Xcode console explaining why.

To add a logo for another issuer, add its opencard-db issuer ID and website to `logoDomains` in
`IssuerStyle`.

## Tech

| | |
| --- | --- |
| Language and UI | Swift 5.9, SwiftUI |
| Platform | iPhone only, iOS 17.0 and later, portrait |
| Project generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml` (the `.xcodeproj` is generated and not committed) |
| Dependencies | None. The app uses only Apple frameworks. |
| Backend | None yet. Supabase is planned for sign-in and saving. |
| Network | Two small downloads of the issuer list from the jsDelivr CDN, plus issuer logos from LogoAPI.sh. No user data is sent. |
| Appearance | Light and dark mode, using the onboarding design's colors |
| Font | Inter, falling back to the system font until the font files are added to the bundle |

### How the code is organized

```
CreditCardTracker/
  App/            App entry point and RootView (onboarding until finished, then home)
  DesignSystem/   Theme (colors, sizes), buttons, card badge, logo, back button
  Models/         Issuer, TrackedCard, CardDetails, DueDate
                  Issuer list: IssuerCatalogStore (load, save, fall back), IssuerCatalogSource (pinned release),
                  OpenCardMapper (files to issuers), IssuerStyle (badges, names), IssuerCatalogCache,
                  IssuerCatalogFetcher, BuiltInIssuers (the 12 built-in issuers)
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

- **One store drives onboarding.** `OnboardingStore` holds the picked issuers with their card counts, the
  cards and their details, and the navigation path. Screens read it and call its methods; the rules (what
  is complete, how many cards are locked, which card comes next) live there so they can be unit tested.
- **One `TrackedCard` per card.** Each has its own ID, so two cards from one issuer have separate forms,
  balances and due dates. Lowering a bank's count keeps the first cards and their details.
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
picker, add another card, issuer logos, a README rewrite, the card list from the CDN, and a bank list with
a card counter instead of a list of card names.

## Placeholders to replace

- Bundle ID `com.tariqe2000.creditcardtracker` in `project.yml`.
- The app icon (the `AppIcon` set is empty).
- The Inter font files. Until they are added to the app bundle, the system font is used.
- The Terms of Service and Privacy Policy links in `Onboarding/AppLinks.swift`, which point to
  `example.com`.
- Sign in with Apple and Google, as described above.

## Credits

- Issuer list: [opencard-db](https://github.com/thedavidweng/opencard-db) by David Weng, code MIT, data
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- Issuer logos: [LogoAPI.sh](https://logoapi.sh).

## License

No license has been chosen yet for this app.
