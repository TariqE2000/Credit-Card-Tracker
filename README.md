# Credit Card Tracker

**Never forget to pay a card again.**

An iPhone app that keeps all your credit card balances and due dates in one calm place.

If you carry several credit cards, the numbers that matter (what you owe, the minimum payment, the day it
is due) are scattered across a different app or statement for each issuer. Credit Card Tracker puts them on
one screen so you can see your total balance and what is due next without logging in to anything.

> **Status: early MVP.** The onboarding flow and the home screen, with Pay, Mark paid, adding a card and six
> views (calendar, tiles, by bank, by week, chart, interest), are built. Real sign-in and saving your data are not built yet. See [What works today](#what-works-today) and [What is not built yet](#what-is-not-built-yet).

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

After you confirm, the home screen shows your total balance, your total minimum payments, how much is due
in the next 7 days, and the card due next. Below that is every card, with its due date, balance and minimum
payment. The button above the list ("Due date") opens a menu to sort by due date, balance, minimum payment,
bank or interest rate, and the app remembers your choice. A card missing details is listed last and left out
of the totals, with an "Add details" link.

Tap a card to open its sheet: the balance and minimum payment, a **Pay Chase** button when the bank has a page,
and one button for this month's payment that says **Mark paid** or, once marked, **Mark unpaid**. **Edit card
details** in the sheet opens the same form used during setup, where you can change the balance, minimum
payment, due date and interest rate, or remove the card. A card still missing details opens that form
straight away. The Calendar, Tiles, By bank and By week views open the same sheet.

**Add a card.** The round **+** at the top right opens "Pick your cards" in a sheet, with the cards you
already have ticked and locked. Tick new ones (or "My card is not listed"), then fill in a form for each new
card, and the sheet closes. It is the same screens as "Add another card" on the review screen. If you close
the sheet part way, cards that already got a form stay in the list, without details, ready for "Add details".

**Pay and Mark paid.** The card due within a week gets a banner with two buttons under its name. **Pay** opens the bank's
own web page (for example "Pay Chase"), where you sign in and pay. It opens the way any link opens on an
iPhone: in Safari, or in the bank's app if you have it and the bank has set that link up to open there.
The app never sees your bank password or card number and never makes a payment itself. **Mark paid** moves
the card on to next month's due date, so the banner and "due in 7 days" stop counting it, and a bar at the
bottom offers **Undo** for a few seconds.

The same payment status is on every card's sheet, so any card can be marked, not only the one in the banner.
The button follows the card: **Mark paid** on an unpaid card, **Mark unpaid** on a paid one, which puts its due
date back. A paid card shows "Paid · next due Dec 28" and has no Pay button, because there is nothing left to
pay this month. Pressing and holding a card on the home screen offers the same. Mark paid does not change the
balance you entered. It wears off by itself once the due day has passed, and for now it is only remembered
while the app is open.

Pay links are a hand-made list in `Home/PayLinks.swift`. Each entry holds the lender's name and its page
together, so the button always names the lender it opens ("Pay Chase" opens Chase, "Pay Citi" opens Citi).
A co-branded card pays the lender that issued it: an Amazon, United or Marriott card issued by Chase says
"Pay Chase". The list covers Chase, American Express, Barclays, U.S. Bank, Synchrony, Capital One, Bank of
America, Citi, Wells Fargo, Discover, USAA, Navy Federal, Credit One, Truist, Citizens and FNBO. A card from
any other lender, or a card you typed in yourself, has no Pay button. Chase, Synchrony, Capital One and
Wells Fargo go straight to a sign-in page; the others open the lender's home page, which has a Log in link.

A due date repeats every month, so the home screen works out the next date from the day you entered: a card
entered as "Dec 14" is due on the 14th of every month. In a month too short for that day, the last day of the
month is used.

**Views.** The **Views** button at the top of the home screen opens a page with a row of chips for the
different ways to see your cards. The page remembers the chip you used last. All of them read the same
cards as the home screen.

- **Calendar** shows one month with a dot on every day a card is due, in the color of the card's bank.
  Tap a day to list the cards due on it, and use the arrows to move between months. Because due dates repeat
  every month, every month shows them. "Still ahead this month" adds up the minimums left.
- **Tiles** shows each card as a tile, two to a row, in the order of the same sort button the home screen
  has.
- **By bank** groups the cards under their bank, soonest due first. Each bank shows its card count, total
  balance and total minimum, a line for each card, and a "Pay Chase" link when the bank has one.
- **By week** lists what is due each week (Sunday to Saturday in the US): "This week", "Next week", then the
  dates. Each week adds up its minimum payments. Weeks with nothing due are left out.
- **Chart** draws one bar per card, biggest balance first, with each card's share of your total balance.
  "View as a table" shows the same numbers as text.
- **Interest** lists cards with the highest APR (the yearly interest rate) first, and cards with no APR last
  with an "Add APR" link. The box at the top estimates a month of interest as balance × APR ÷ 12, added up
  over the cards that have an APR. It is a rough guide that only applies when a balance is carried over,
  not what a bank will charge.

## What is not built yet

- **Pay buttons for more lenders.** Only the 16 lenders above have a link. Each link needs to be checked
  by hand, because lenders move their sign-in pages.
- **Saving "paid".** Mark paid is forgotten when the app closes, like the cards themselves.
- **Real sign-in.** The plan is Supabase Auth with Sign in with Apple and Google. The code has
  `TODO(supabase)` markers where the token exchange goes.
- **Saving your data.** Everything lives in memory. If you quit the app, your cards are gone. The plan is
  to save them to the user's account in Supabase.
- **Reminders for due dates.** The tagline promises this; nothing is built for it yet.
- **Pictures of each card.** The list has names and issuers but no card art. Cards show a colored badge or
  the issuer's logo for now.

## The card catalog

The list on **Pick your cards** comes from [opencard-db](https://github.com/thedavidweng/opencard-db), an
open-source database of credit cards (code MIT, data CC BY 4.0). At the pinned release, `v0.4.2`, it has
**435 US cards from 51 issuers**: personal and business, active and discontinued, because people still
carry cards that are no longer sold.

How the app gets it:

1. **One download.** A plain HTTPS GET to the jsDelivr CDN, which is free and needs no account, key or
   request limit: `cdn.jsdelivr.net/gh/thedavidweng/opencard-db@v0.4.2/exports/cards-all.json`. That file
   also holds Canada and China (about 2.3 MB), so the app keeps only the US cards.
2. **Saved on the phone.** The result is saved as one small file (about 65 KB, in Application Support and
   left out of iCloud backups). Later launches show it instantly and do not download again.
3. **Pinned to one release.** A tagged address never changes, so a mistake in opencard-db's newest data
   cannot break the app. To get newer cards, change `CardCatalogSource.tag`, check that Pick cards still
   loads, and ship an update. Tags are listed on
   [their releases page](https://github.com/thedavidweng/opencard-db/releases).
4. **If it fails.** With no internet on the very first launch, Pick cards shows a built-in list of 13
   popular cards (`CardCatalog`) with a **Try again** button. **My card is not listed** always works.
   A list saved earlier stays on screen if a later download fails. A file with fewer than 50 US cards is
   treated as a failed download and is never saved.

The data has names and issuers but no badge colors, so each card's badge comes from its issuer
(`IssuerStyle`): the colors the app already used for the big banks, and a steady color made from the
issuer's ID for everyone else. Big issuers are listed first, then the rest alphabetically.

**Credit:** the CC BY 4.0 license asks for attribution, so the bottom of the list says "Card list from
opencard-db (CC BY 4.0)" and links to the project.

## Issuer logos

A card's logo comes from the first of these that works (details in [docs/issuer-logos.md](docs/issuer-logos.md)):

1. **A logo bundled in the app.** 25 issuers (311 of the 435 US cards) have a picture stored inside the
   app, in `Assets.xcassets/IssuerLogos`. It shows instantly and works offline; nothing is hosted or
   downloaded. Each card carries its issuer's opencard-db ID, and the app looks for the image
   `logo-<issuer-id>`, e.g. `logo-chase`.
2. **[LogoAPI.sh](https://logoapi.sh).** For an issuer with no bundled logo but a website in `logoDomains`
   (`IssuerStyle`), the app downloads the logo while it runs: free, no key, no sign-up, no attribution
   (capped at 2 million requests a month per site). Synchrony is confirmed to be there; a few other
   issuers (PenFed, BMO, Credit One, FNBO) are not checked and keep the badge if it is missing. The app asks for a PNG with
   `fallback=404`, so a missing logo comes back as an error instead of a stand-in picture.
3. **The colored badge** with the issuer's initials. It is always underneath, so the screen never has a
   blank spot.

The other 25 issuers (98 cards) show the colored badge until their logos are added. To add one, run
`scripts/add-logo.sh <issuer-id> <logo.svg>` (see [docs/issuer-logos.md](docs/issuer-logos.md)). Cards
with their own look, such as Apple Card, never pick up their bank's logo.

In debug builds, a LogoAPI.sh logo that fails to load prints lines starting with `[Logo]` in the Xcode
console explaining why.

## Tech

| | |
| --- | --- |
| Language and UI | Swift 5.9, SwiftUI |
| Platform | iPhone only, iOS 17.0 and later, portrait |
| Project generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml` (the `.xcodeproj` is generated and not committed) |
| Dependencies | None. The app uses only Apple frameworks. |
| Backend | None yet. Supabase is planned for sign-in and saving. |
| Network | One download of the card list from the jsDelivr CDN, plus issuer logos from LogoAPI.sh. No user data is sent. |
| Appearance | Light and dark mode, using the onboarding design's colors |
| Font | Inter, falling back to the system font until the font files are added to the bundle |

### How the code is organized

```
CreditCardTracker/
  App/            App entry point and RootView (onboarding until finished, then home)
  DesignSystem/   Theme (colors, sizes), buttons, card badge, logo, back button
  Models/         CatalogCard, TrackedCard, CardDetails, DueDate
                  Card list: CardCatalogStore (load, save, fall back), CardCatalogSource (pinned release),
                  OpenCardMapper (file to cards), IssuerStyle (badges), CardCatalogCache, CardCatalogFetcher,
                  CardCatalog (the 13 built-in cards)
  Onboarding/
    OnboardingStore.swift   The one shared state object for the whole flow
    OnboardingFlow.swift    The NavigationStack and its routes
    FormInput.swift         Reads and formats what the user types
    Screens/                Sign up, Log in, Pick cards, Card form, Review
    Components/             Rows, form pieces, social buttons, due date picker sheet
  Home/           Home screen (DashboardView), its sorting and due date logic, PayLinks (lender pages),
                  AddCardSheet (the + button), CardSheet (what a tapped card opens) and Views/ (the Views page and
                  each of its six views)
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
picker, add another card, issuer logos, a README rewrite, and the card list from the CDN.

## Placeholders to replace

- Bundle ID `com.tariqe2000.creditcardtracker` in `project.yml`.
- The app icon (the `AppIcon` set is empty).
- The Inter font files. Until they are added to the app bundle, the system font is used.
- The Terms of Service and Privacy Policy links in `Onboarding/AppLinks.swift`, which point to
  `example.com`.
- Sign in with Apple and Google, as described above.

## Credits

- Card list: [opencard-db](https://github.com/thedavidweng/opencard-db) by David Weng, code MIT, data
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- Issuer logos: bundled logos from [selfh.st icons](https://selfh.st/icons/)
  ([CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)),
  [VectorLogoZone](https://www.vectorlogo.zone) and
  [College-Canine/financial](https://github.com/College-Canine/financial) (MIT), and
  [LogoAPI.sh](https://logoapi.sh) for the rest. Each logo belongs to its owner; the full list is in
  [docs/issuer-logos.md](docs/issuer-logos.md).

## License

No license has been chosen yet for this app.
