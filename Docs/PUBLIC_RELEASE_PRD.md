# DeskOrbit Public Release Specification

Last updated: 2026-09-03  
Owner: Kauibungalow LLC  
Status: Approved launch direction; external account setup and release qualification pending

## 1. Outcome

Release DeskOrbit as a trustworthy, self-contained Mac application that a customer can discover, download, try for 14 days, buy once for $9.99, activate on up to three Macs, update without losing settings or Accessibility approval, and obtain support for when macOS changes Mission Control behavior.

The initial commercial sequence is:

1. Internal release qualification.
2. Founding Tester cohort of 25–40 invited users with complimentary permanent licenses.
3. Public paid beta at $9.99.
4. Remove the beta label only after the compatibility and reliability exit gates pass.

This is a direct-download product. The Mac App Store is not part of the initial launch because DeskOrbit's enhanced Spaces behavior relies on capabilities that are unsuitable for an App Store-sandboxed build.

## 2. Decisions

- Product name: DeskOrbit.
- Seller and signing organization: Kauibungalow LLC.
- Primary account: `quin@kauibungalow.com`. Do not create production assets under `rqthames@gmail.com`.
- Website: `https://deskorbit.kauibungalow.com`.
- Price: $9.99 USD one-time.
- License: three simultaneous Mac activations.
- Trial: 14 days, full featured.
- Updates: lifetime updates, matching the promise already present in the app.
- Payment and tax merchant of record: Lemon Squeezy.
- Download format: notarized DMG as primary; notarized universal ZIP as fallback/update artifact.
- Architectures: Apple Silicon and Intel universal binary.
- Official OS range at public beta: macOS 14 Sonoma, macOS 15 Sequoia, and macOS 26 Tahoe.
- Privacy: no automatic analytics, telemetry, screen capture, or crash upload.

## 3. Current-State Audit

Already implemented:

- Universal release build, DMG and ZIP packaging, checksums, and GitHub Release automation.
- Developer ID, hardened runtime, notarization, and stapling paths in `Scripts/release.sh`.
- GitHub Actions secret inputs for a signing certificate and App Store Connect notarization key.
- Native update checking against GitHub Releases, with user data preserved during replacement.
- Fourteen-day trial enforcement.
- Lemon Squeezy activate, validate, and deactivate requests.
- Secure license-key storage in Keychain.
- Three-device and lifetime-update messaging in Settings.
- Local diagnostics, privacy documentation, SBOM, release notes, and a compatibility test matrix.
- Public staging website with product, pricing, help, privacy, compatibility,
  terms, and refund pages.
- Privacy-previewed support report with explicit local copy/save actions.
- Approved $9.99 price in the app and website.
- Public-release credential preflight that rejects unsigned, unnotarized, or
  unsigned-update artifacts.

Not launch-ready yet:

- Current GitHub releases are ad-hoc signed because production signing secrets are absent.
- The Apple Developer portal is authenticated as Quin Thames under
  Kauibungalow LLC / team `Q3T7CAZ6NT`, but the Developer ID certificate and
  notarization API access still require owner confirmation.
- `deskorbit.kauibungalow.com` is reserved with the site host but awaits the
  required Cloudflare DNS records.
- The public staging site is owned by the current Codex Sites account; migrate
  or establish Kauibungalow-controlled hosting before treating it as the final
  company-owned production surface.
- The Lemon Squeezy test product has unlimited license duration, a three-Mac
  activation limit, and prepared confirmation/receipt copy. Its $9.99 save,
  test purchase matrix, live-mode copy, store activation, payout profile, and
  full live purchase/refund test remain pending.
- Sonoma, Intel, and multi-display configurations remain unverified in the compatibility matrix.
- There is no staffed support inbox or external feedback intake yet; users can
  generate and inspect the privacy-redacted report locally.

## 4. Release Stages

### 4.1 Stage A — Internal release candidate

Audience: owner-controlled Macs only.

Required exit criteria:

- Developer ID signed and Apple-notarized app and DMG.
- Gatekeeper verification succeeds on a Mac that has never run DeskOrbit.
- Replacing the app with a newer signed build retains Space names, notes, preferences, license, and Accessibility authorization.
- Lemon Squeezy test-mode purchase creates a working license; activation, validation, third activation, fourth-activation rejection, deactivation, and reactivation all behave correctly.
- Trial start, day calculation, expiry, offline behavior, clock changes, and activation after expiry are tested.
- Website staging page, privacy page, support page, refund terms, and installation guide are complete.

### 4.2 Stage B — Founding Tester cohort

Audience: 25–40 deliberately selected users across the supported matrix.

Offer:

- Complimentary permanent license via a product-specific, redemption-limited 100% Lemon Squeezy discount code or owner-issued licenses.
- Same three-Mac limit as paid customers.
- No payment card required when the selected Lemon Squeezy flow permits a zero-total checkout.
- Tester agreement is plain language: beta software, report problems, diagnostics shared only by explicit user action, no NDA by default.

Recruit for coverage, not volume:

- At least 8 Tahoe users and 8 Sequoia users.
- At least 4 Sonoma users.
- At least 4 Intel Macs.
- At least 8 multi-display setups.
- At least 4 users with “Displays have separate Spaces” disabled.
- A mixture of 1–3, 4–8, and 9+ Spaces.
- Trackpad, keyboard, and mixed Mission Control invocation.

Run the cohort for at least 14 days and two signed update cycles. Do not expand publicly until update identity, Accessibility persistence, data migrations, and Mission Control overlays survive both cycles.

### 4.3 Stage C — Public paid beta

- Public download and 14-day trial require no invitation or account.
- License costs $9.99 once and activates up to three Macs.
- Website and checkout label the product “Public Beta” and list the exact supported macOS versions and known limitations.
- Offer a 30-day refund policy, subject to the final legal/business review and Lemon Squeezy's merchant-of-record process.
- Existing Founding Testers retain their complimentary licenses.
- Do not promise that Apple’s native Desktop labels are renamed; state clearly that DeskOrbit draws aligned overlay labels.

### 4.4 Stage D — General availability

Remove “beta” only when:

- 30 consecutive days have no known crash causing data loss and no high-confidence Space mapping assigned to the wrong user profile.
- Each claimed OS/architecture configuration has a recorded pass.
- At least 90% of invited testers who completed setup can see correctly aligned labels.
- Two real upgrade cycles retain settings, license, and Accessibility permission.
- No unresolved P0/P1 issue remains.
- Support and refund requests can be handled within two business days.

## 5. OS and Hardware Support Policy

### 5.1 Launch support

Officially support:

- macOS 14 Sonoma.
- macOS 15 Sequoia.
- macOS 26 Tahoe.
- Apple Silicon and Intel hardware capable of those releases.
- One or multiple displays, including separate-Spaces modes.

“Supported” means the exact OS family has passed discovery, switching, Mission Control lifecycle, overlay alignment, rename persistence, restart, Accessibility permission, update replacement, and uninstall/reinstall tests.

### 5.2 Why not claim every macOS version

DeskOrbit depends on undocumented WindowServer behavior and Dock Accessibility structure. Compatibility cannot be inferred merely because the binary launches. The support page must distinguish:

- Supported: tested and eligible for fixes.
- Experimental: expected to work but not sufficiently tested.
- Unsupported: below the minimum deployment target or known incompatible.

Do not lower the deployment target below macOS 14 for launch. Reassess macOS 13 only after public-beta demand is measured, because adding an old OS multiplies private-API and UI test work while serving a shrinking audience.

### 5.3 New macOS releases

- Test developer and public betas on a non-primary Mac.
- Treat a new major macOS version as experimental until the full overlay/provider matrix passes.
- Preserve a remote kill-switch-free design: compatibility changes ship as signed app updates, never as unreviewed remote code or configuration.
- If enhanced integration breaks, fail closed, hide inaccurate overlays, and give the user a useful diagnostic message.

## 6. Apple Signing and Notarization

### 6.1 Account ownership

- Authenticate at Apple Developer using `quin@kauibungalow.com`.
- Verify that Kauibungalow LLC team ID is `Q3T7CAZ6NT` before creating or exporting credentials.
- The Account Holder should create the Developer ID Application certificate when Apple requires that role.
- Use bundle identifier `com.offdacharts.namespaces` for the first commercial release unless a controlled migration proves a new identifier preserves app data, Keychain items, URL handling, login item behavior, and Accessibility/TCC identity.

### 6.2 Required credentials

- Developer ID Application certificate and private key exported as password-protected PKCS#12.
- App Store Connect API key with only the access required for notarization.
- Key ID and issuer ID.
- Existing Sparkle EdDSA private key for signing update artifacts.

Never commit credentials. Store production copies in an approved password manager/offline backup and place CI copies only in GitHub Actions encrypted secrets.

### 6.3 CI requirements

Configure:

- `DESKORBIT_DEVELOPER_ID_P12_BASE64`
- `DESKORBIT_DEVELOPER_ID_P12_PASSWORD`
- `DESKORBIT_NOTARY_KEY_BASE64`
- `DESKORBIT_NOTARY_KEY_ID`
- `DESKORBIT_NOTARY_ISSUER`
- `DESKORBIT_SPARKLE_PRIVATE_KEY_BASE64`

Change the release workflow so a public release fails if any production signing or notarization secret is absent. Ad-hoc fallback may remain only for explicitly named development artifacts; it must never publish a public GitHub Release.

Verify every artifact with `codesign`, `spctl`, `stapler validate`, DMG verification, checksum verification, architecture inspection, and a clean-Mac launch smoke test.

## 7. Payment and Licensing

### 7.1 Lemon Squeezy product

Create a live product owned by Kauibungalow LLC:

- Product: DeskOrbit.
- Variant: Personal Lifetime.
- Price: $9.99 USD, single payment.
- License length: unlimited.
- Activation limit: 3.
- Generate license keys: enabled.
- Receipt and My Orders copy explain where to find the license key.
- Confirmation button opens `deskorbit://settings` only as an optional convenience; it must also provide manual activation instructions.

Use a reusable checkout URL, not a single-use cart URL. Keep the Lemon Squeezy-hosted checkout as the payment boundary so Kauibungalow does not handle card data.

### 7.2 Founding Tester access

Create a product-scoped discount with:

- 100% discount.
- 40-redemption maximum initially.
- Explicit expiration after the planned cohort enrollment window.
- No subscription behavior.
- A non-guessable code shared only with selected testers.

If Lemon Squeezy's live zero-total checkout behavior does not issue keys reliably, issue complimentary licenses through the store/admin-supported method instead. Test this before inviting anyone.

### 7.3 License-client behavior

- Update all app and website price copy from $3.99 to $9.99 from one shared build-time constant where practical.
- Preserve access during temporary Lemon Squeezy outages for a documented grace period after a previously successful validation.
- Never disable local data access because license validation is offline.
- Rate-limit retries and provide actionable errors without exposing raw server payloads.
- Use an installation UUID as the instance identity; do not rely only on a user-editable device name.
- Provide Deactivate This Mac and link to Lemon Squeezy My Orders/customer portal.
- Define refund/revocation behavior and ensure it does not delete user data.
- Add automated response fixtures for valid, invalid, expired, activation-limit, missing instance, malformed, HTTP error, timeout, and offline conditions.

### 7.4 Full transaction test

Test mode first, then make one real $9.99 purchase controlled by the owner. Confirm checkout, tax display, receipt delivery, license generation, activation, validation, deactivation, refund handling, payout/order recording, and the customer portal. A real charge/refund requires owner confirmation at action time.

## 8. Website

The domain is referenced by the app but is not currently live. Create a small, fast static marketing/support site with no advertising trackers.

Required pages:

- Home: concise value proposition, annotated Mission Control demo, key features, supported systems, privacy statement, price, trial/download, and buy buttons.
- Download: current version, release date, supported OS, DMG, checksum, installation and Accessibility instructions, and release notes.
- Help: onboarding, Space naming, Mission Control overlays, switching, updates, licenses, backup/restore, troubleshooting, and complete uninstall.
- Compatibility: per-version/provider matrix and known limitations.
- Privacy: exact app and website data behavior, Lemon Squeezy disclosure, diagnostics consent, retention, and contact.
- Terms/EULA: license grant, three-device limit, acceptable use, disclaimers, limitation of liability, termination, and governing law, reviewed for the business.
- Refunds: clear eligibility and process.
- Support/Feedback: `support@kauibungalow.com` or another verified Kauibungalow address, issue category, DeskOrbit version, macOS version, and optional diagnostic attachment.

The website must not say DeskOrbit changes Apple’s native Mission Control names. Use “adds names aligned to your Spaces” or equivalent accurate wording.

Deployment requirements:

- Source-controlled deployment.
- HTTPS, custom domain DNS, `www`/canonical redirects as appropriate.
- Staging environment before production.
- Availability check and broken-link check in CI.
- Download links derive from the current signed GitHub Release or a controlled download endpoint.
- Checkout opens Lemon Squeezy's hosted checkout/overlay.
- No license keys, API credentials, or signing secrets in client code.
- Basic privacy-friendly aggregate website metrics are optional and must be disclosed; ship without them initially.

## 9. Feedback and Debugging

### 9.1 User-controlled diagnostic report

Add “Create Support Report” to Settings. Before anything is shared, show a preview and let the user save or copy it.

Default report contents:

- DeskOrbit version/build and update channel.
- macOS version/build and CPU architecture.
- Provider/capability state.
- Accessibility trust state, never the user's password or security settings.
- Display count, arrangement geometry, scaling, and separate-Spaces mode where detectable.
- Number and types of Spaces; names redacted by default.
- Mission Control lifecycle state and anchor-detection decisions.
- Recent static launch-stage events and typed error codes.
- Crash files belonging only to DeskOrbit, listed for separate opt-in attachment.

Exclude Space names, note content, automation bodies, window titles, paths, browser data, application usage history, license key, and personal identifiers by default.

### 9.2 Structured tester feedback

Each tester receives a short checklist:

1. Install and first launch.
2. Grant Accessibility.
3. Rename all Spaces.
4. Open/close Mission Control using every normal method.
5. Reorder, add, and remove Spaces.
6. Sleep/wake and restart Dock/Mac.
7. Connect/disconnect displays.
8. Install the next signed update over the existing copy.
9. Confirm names, settings, license, and Accessibility authorization remain.
10. Submit the support report only if something fails.

Track reports by anonymized tester ID, app build, OS build, architecture, display topology, reproduction steps, expected behavior, actual behavior, screenshot/video availability, severity, and resolution version.

### 9.3 Crash collection

For the founding cohort, use macOS-generated DeskOrbit crash reports submitted manually through the feedback workflow. Do not add automatic crash/analytics SDKs before launch. Reconsider opt-in automatic crash reporting only if manual reports prove insufficient; that requires a separate privacy review, disclosure, retention policy, and explicit consent.

## 10. Updating Without Data or Permission Loss

- Keep a stable bundle identifier, Developer ID team, designated requirement, executable name, and signing identity across releases.
- Sign every customer build with the same Developer ID certificate lineage.
- Never publish an ad-hoc build to the customer update channel.
- Store user data under the existing Application Support path and migrate transactionally.
- Keep the license in the existing Keychain service unless a migration is implemented and tested.
- Create a pre-migration backup before any schema change.
- Update installation instructions must say to replace the app in `/Applications`, not delete app data.
- Test update paths from the oldest public build to the newest and from the immediately previous build.
- If an automatic updater is later embedded, require EdDSA signature validation, HTTPS, atomic replacement, rollback on failure, and no elevation beyond what installation requires.

## 11. Support and Operations

- Establish and test the support email before publishing it.
- Publish expected response time: two business days during beta.
- Maintain canned procedures for launch failure, Accessibility reset, missing overlays, incorrect spacing, lost mapping, license activation limit, refund, and data export/uninstall.
- Keep a private incident log with no customer content beyond what they explicitly provide.
- Define severity: P0 data/security issue; P1 app unusable or systematically incorrect overlays; P2 impaired feature/workaround exists; P3 cosmetic/request.
- P0 response: pause downloads/checkout if necessary, preserve evidence, publish a clear notice, ship or roll back safely.
- Never revoke a working build remotely or require always-on Internet access.

## 12. Security and Privacy Gate

- Review all entitlements and keep only those required.
- Confirm hardened runtime and secure timestamps.
- Scan dependencies and update SBOM.
- Confirm no secret exists in git history, app bundle, release archives, logs, website JavaScript, or appcast.
- Validate all URL-scheme parameters and backup/import inputs.
- Treat license-server responses as untrusted.
- Ensure automation remains explicit and never becomes remotely triggerable.
- Publish an accurate privacy policy before collecting emails, purchases, or feedback.
- Add a security contact and responsible-disclosure instructions.

## 13. Launch Checklist and Acceptance Criteria

### P0 — blocks founding testers

- [ ] Sign in to Apple Developer as `quin@kauibungalow.com` and verify Kauibungalow LLC / team `Q3T7CAZ6NT`.
- [ ] Create/export Developer ID Application identity and create least-privilege notarization API credentials.
- [ ] Add protected GitHub Actions secrets.
- [x] Make public release workflow fail closed when production signing is absent.
- [ ] Produce, notarize, staple, and independently verify the RC DMG and ZIP.
- [ ] Confirm Accessibility permission persists through a signed upgrade.
- [ ] Create Lemon Squeezy product in test mode and pass the full license matrix.
- [x] Bring up a staging website and required legal/support pages.
- [x] Implement and verify privacy-previewed support reports.

### P1 — blocks public paid beta

- [ ] Complete Founding Tester coverage and two update cycles.
- [ ] Verify Sonoma 14, Sequoia 15, Tahoe 26, Apple Silicon, Intel, and multi-display claims.
- [ ] Activate Lemon Squeezy store/business/payout profile.
- [ ] Copy the tested product and cohort discount to live mode.
- [x] Replace every $3.99 string with the approved $9.99 price.
- [ ] Complete one controlled real purchase and refund test.
- [ ] Configure DNS and production HTTPS for `deskorbit.kauibungalow.com`.
- [ ] Publish the signed build, appcast/update metadata, checksums, release notes, support, privacy, terms, compatibility, and refund pages.
- [ ] Confirm download, trial, purchase, receipt, activation, update, deactivation, reinstall, and uninstall end to end on a clean Mac.

### P2 — blocks general availability label

- [ ] Meet the 30-day reliability gate.
- [ ] Clear all P0/P1 defects.
- [ ] Review support volume and the OS support matrix.
- [ ] Finalize non-beta copy and screenshots/video.
- [ ] Decide whether to keep lifetime updates for all future major versions before changing the original promise.

## 14. Immediate Execution Order

1. Authenticate the Kauibungalow Apple Developer account and verify roles/team.
2. Configure signing and notarization secrets, then make CI fail closed.
3. Produce a signed internal RC and test clean install plus signed upgrade.
4. Build and test the Lemon Squeezy product entirely in test mode.
5. Implement the $9.99 price update, license robustness tests, and support-report workflow.
6. Create the website repository, staging site, support/legal content, and real download flow.
7. Complete the missing OS/hardware matrix using recruited Founding Testers.
8. Run two cohort update cycles and fix release-blocking defects.
9. Activate live sales, run one controlled real transaction/refund, and launch the public paid beta.
10. Measure the general-availability exit gates without adding hidden telemetry.

## 15. Explicit Non-Goals for This Launch

- App Store distribution.
- Subscription billing.
- Accounts or cloud sync.
- Automatic screen capture or session replay.
- Always-on analytics or crash reporting.
- Support for every historical macOS release.
- Promising compatibility with an untested new macOS beta.
