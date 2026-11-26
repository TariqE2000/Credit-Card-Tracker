# Issuer logos

How a card gets its logo, which logos are in the app, and how to add one.

## How it works

A card's logo is looked up in this order. The first one that works wins.

1. **Bundled in the app.** The picture is a file inside the app (`Assets.xcassets/IssuerLogos`), so it
   shows instantly, works offline and nothing is downloaded or hosted anywhere. The app finds it by name:
   an issuer with the opencard-db ID `chase` uses the image set `logo-chase`. Each card carries its
   issuer's ID (`CatalogCard.issuerID`), and the lookup happens when the card is drawn, so adding a logo
   later needs no other change.
2. **LogoAPI.sh.** If no logo is bundled and the issuer has a website in `logoDomains` (`IssuerStyle`),
   the app asks [LogoAPI.sh](https://logoapi.sh) for it. This is the only logo that is downloaded while
   the app runs. Synchrony is confirmed to be there; PenFed, BMO, Credit One and FNBO are listed but not
   checked, and keep the badge if LogoAPI.sh does not have them.
3. **Colored badge.** The issuer's initials on its color. It is always drawn underneath, so a card never
   has a blank spot while a logo loads or if it cannot load.

A card with its own look, such as Apple Card (issued by Goldman Sachs), skips step 1 so it does not show
its bank's logo. See `IssuerStyle.cardOverrides`.

## Logos in the app today

25 issuers, 311 of the 435 US cards in opencard-db v0.4.2. Each file is a transparent PNG, 512 pixels on
the long side, with its shape kept.

| Issuer ID | Source | File in the source |
|---|---|---|
| amex | selfh.st icons | `svg/american-express.svg` |
| bank-of-america | selfh.st icons | `svg/bank-of-america.svg` |
| barclays | VectorLogoZone | `barclays/barclays-icon.svg` |
| brex | VectorLogoZone | `brex/brex-icon.svg` |
| capital-one | selfh.st icons | `svg/capital-one.svg` |
| cfna | College-Canine/financial | `logos/bank/cfna.svg` |
| chase | selfh.st icons | `svg/chase.svg` |
| citi | selfh.st icons | `svg/citibank.svg` |
| citizens | College-Canine/financial | `logos/bank/citizens_bank.svg` |
| cross-river-bank | College-Canine/financial | `logos/bank/crossriver.svg` |
| discover | selfh.st icons | `svg/discover-card.svg` |
| fifth-third | College-Canine/financial | `logos/bank/53.svg` |
| goldman-sachs | VectorLogoZone | `goldmansachs/goldmansachs-icon.svg` |
| hsbc | VectorLogoZone | `hsbc/hsbc-icon.svg` |
| navy-federal | selfh.st icons | `svg/navy-federal-credit-union.svg` |
| patriot-bank | College-Canine/financial | `logos/bank/bankpatriot.svg` |
| pnc | College-Canine/financial | `logos/bank/pnc.svg` |
| regions | College-Canine/financial | `logos/bank/regions.svg` |
| sofi | selfh.st icons | `svg/sofi.svg` |
| td | VectorLogoZone | `tdbank/tdbank-icon.svg` |
| truist | College-Canine/financial | `logos/bank/truist.svg` |
| ubs | VectorLogoZone | `ubs/ubs-icon.svg` |
| us-bank | selfh.st icons | `svg/u-s-bank.svg` |
| usaa | selfh.st icons | `svg/usaa.svg` |
| wells-fargo | selfh.st icons | `svg/wells-fargo.svg` |

The sources:

- [selfh.st icons](https://github.com/selfhst/icons), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
  The license asks for credit, which is why the card list screen and the README say where the logos
  come from.
- [VectorLogoZone](https://github.com/VectorLogoZone/vectorlogozone). The website's code is AGPL-3.0; the
  logos themselves belong to their owners.
- [College-Canine/financial](https://github.com/College-Canine/financial), MIT. Again the logos
  belong to their owners.

Trademarks stay with the banks. These logos only identify the bank a card comes from. This is not legal
advice: check with a lawyer before the app goes on the App Store.

Looks to check on a phone: wide logos (Fifth Third, CFNA, Cross River, PNC, Citizens) look small in the
square tile, and Patriot Bank and Regions look a little grainy.

## Not covered yet

- **Synchrony** loads from LogoAPI.sh (26 of 51 issuers, 337 of 435 cards, are covered with it).
- **25 issuers (98 cards)** have no logo yet and show the colored badge. Add them by hand as you find the
  pictures. The full list, with card counts, is in the spreadsheet "US card issuers and open-source logo
  sources".

## Add a logo

1. Find the logo as an SVG (best) or a large PNG with a transparent background.
2. Find the issuer's ID: it is the `issuer_id` of its cards in opencard-db, for example `synchrony`,
   `penfed` or `us-bank`.
3. Run `scripts/add-logo.sh <issuer-id> <file>`, for example:

   ```
   scripts/add-logo.sh synchrony ~/Downloads/synchrony.svg
   ```

   It needs `rsvg-convert` (`brew install librsvg`) or ImageMagick (`brew install imagemagick`).
4. Add a row to the table above (source and license) and add the ID to `bundledIssuerIDs` in
   `CreditCardTrackerTests/LogoURLTests.swift`.
5. Build and run. No other code changes: cards of that issuer pick up the logo by name.

To replace a logo, run the script again with the same ID.
