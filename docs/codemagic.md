# iOS releases — via Codemagic, not local Xcode

Antología Poética's iOS builds and App Store/TestFlight uploads are done
through [Codemagic](https://codemagic.io), configured entirely through its
web dashboard — there is no `codemagic.yaml`, `fastlane/`, or similar in this
repo (checked across the full git history). Xcode was needed for the
one-time initial signing setup, done before this repo existed in its current
form; it is **not** needed for routine updates.

## Pushing an update

1. Push the change to the branch Codemagic watches (currently `monorepo`,
   until it's merged to `main`).
2. Start a build from the Codemagic dashboard for the Antología Poética app
   (automatically, if a webhook trigger is configured; otherwise manually).
3. On success, Codemagic uploads the build to App Store Connect
   (TestFlight) — or produces a downloadable `.ipa`, depending on how the
   workflow's publishing step is configured.
4. Promote/release from App Store Connect as usual.

## Signing

Certificates and provisioning profiles are managed at the Codemagic account
level, tied to the Apple Developer account and the app's bundle id
(`com.manucobos.poemario`) — independent of where the Flutter project sits
in the repo. Don't recreate signing from scratch over a build failure;
check what actually failed first (see "Known gotcha" below for one real
example that looks like a signing problem but isn't).

## Monorepo note

The repo was restructured (commit `bf70cf6`) from a single Flutter project
at the repo root into `packages/poemario_core` + `apps/es` + `apps/en`. If a
Codemagic build can't find the Flutter project (`pubspec.yaml`), or resolves
the wrong one, check the workflow's **working/project directory** setting
points at `apps/es` — not the repo root, which is where it lived before the
restructure. A future English Verse workflow needs its own Codemagic app
entry pointed at `apps/en`; it doesn't exist yet.

## Known gotcha: "A required agreement is missing or has expired"

A build can fail at the `fetch-signing-files` step with:

```
GET https://api.appstoreconnect.apple.com/v1/bundleIds?...
returned 403: A required agreement is missing or has expired.
```

This is **not** a Codemagic or repo problem — Apple blocks all App Store
Connect API access account-wide until the Account Holder re-accepts a
pending agreement, which can only be done by logging into
[appstoreconnect.apple.com](https://appstoreconnect.apple.com) directly (no
API workaround exists, by design). Likely candidate given this app has IAP
tips: the Paid Applications Agreement. Check the homepage banner, or
**Business → Agreements, Tax, and Banking**, accept whatever shows pending,
then retry the build.

Seen in practice: 2026-09-22, right after re-pointing the workflow at
`apps/es` for the first post-restructure build. Codemagic had already
correctly resolved the bundle id and called Apple's API by the time this
hit, so it's a sign the path/detection side is fine, not a symptom of it.
