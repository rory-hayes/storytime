# Promo Code Redemption Setup

This note records the minimal repo-backed setup for Sprint 11 promo-code redemption.

## Real backend promo catalog

`VERIFIED BY CODE INSPECTION`

- Real promo redemption is backed by the backend environment variable `PROMO_CODE_GRANTS`.
- `PROMO_CODE_GRANTS` must be a JSON array of promo definitions.
- Each promo definition supports:
  - `code`: required string, normalized to uppercase
  - `tier`: optional entitlement tier, currently `starter` or `plus`
  - `expires_at`: optional Unix timestamp in seconds; `null` means no expiry

Example:

```json
[
  {
    "code": "SPRINGPLUS2026",
    "tier": "plus",
    "expires_at": 1775001600
  }
]
```

- Redemption happens through `POST /v1/entitlements/promo/redeem`.
- Redemption requires an authenticated parent account.
- Successful redemption creates or updates the authenticated parent's entitlement with source `promo_grant`.
- Invalid, expired, and already-redeemed codes are explicit backend failures.
- Codes are one-time by default in the current repo implementation.

## Repo verification assumptions

`VERIFIED BY CODE INSPECTION`

- Promo catalog entries are configured through environment, not hidden request headers or debug-only backend branches.
- Promo redemptions are currently tracked in backend process memory for repo verification.
- Because redemption state is process-local today, one-time redemption resets when the backend process restarts.
- Durable promo storage and admin tooling remain out of scope for Sprint 11.

## UI test harness

`VERIFIED BY CODE INSPECTION`

- UI tests can seed a promo redemption path with:
  - `STORYTIME_UI_TEST_MODE=1`
  - `STORYTIME_UI_TEST_PROMO_CODE`
  - `STORYTIME_UI_TEST_PROMO_ENTITLEMENT_TIER`
- These variables exist only to make iOS UI coverage deterministic.
- They do not replace the real backend promo catalog or the real parent-auth redemption path.
