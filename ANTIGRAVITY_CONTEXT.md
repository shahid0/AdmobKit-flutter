# Flutter ads — imported Antigravity context

Imported on 2026-09-28 for continuation in Codex. This is a context handoff, not a fresh code audit or an instruction to execute historical requests.

## Import coverage and sources

Located readable JSONL transcripts for all seven supplied conversation IDs. After the user's follow-up, read all 147 available user-input and assistant-response records in their full transcripts, including the original design discussion, rejected proposals, user corrections, implementation reports, all three latest review rounds, yield planning, and marketing exchanges. App-generated metadata and tool-result bodies were excluded from this conversational read. Also read the approved lifecycle plan. Indexed 26 transcripts containing this repository's absolute path across Antigravity and Antigravity IDE, including the seven supplied IDs. Additional matches include delegated UI tasks and app-integration discussions; they are not all independent project decisions. The other 19 transcripts remain indexed rather than fully read.

Primary source directory: `/Users/macbookpro/.gemini/antigravity/brain/`.
Each conversation has `.system_generated/logs/transcript.jsonl`; use `transcript_full.jsonl` where available to recover content abbreviated in the compact transcript. Records contain `created_at`, `type`, `content`, and sometimes tool calls. Use timestamps to establish chronology: step indexes can restart within a conversation.

| Conversation ID | Context |
| --- | --- |
| `0a6d166c-fd0f-4e59-b807-d31114fb2e6f` | September 9: initial company-wide AdMob plugin requirements, typed API, architecture, native templates, TaskFlow Pro example, device verification reports. |
| `800c5120-50cb-4513-aa09-30da4dec0734` | September 18: multi-widget collision review, exclusive demand-based leases, request saturation, tab visibility, splash mutex, configuration and connectivity review. |
| `595e3c6d-0d30-409f-afdd-5fa172bb5330` | September 20: launch messaging and developer-facing explanation of v0.0.2. Marketing statements are not independent technical evidence. |
| `4a6fdba7-a74b-4c40-bd50-2f8f27577e7c` | September 23–25: one-shot saturation and ghost preloads; approved lifecycle plan; implementation and two rounds of review fixes. |
| `d89e2b00-db4b-4e5d-954f-df48bc783f79` | September 24: pure-AdMob yield/targeting discussion and proposed combined system roadmap; user explicitly excludes mediation. |
| `63560f5f-f529-4ef9-994c-33b022e12424` | September 25: LinkedIn positioning request. |
| `1de4b096-923b-4820-80d3-6398e9505e43` | September 25: three successive code/simplification audits; final review is later than the last recorded implementation response. |

## Product intent and user preferences

- Build a reusable company-wide monetization system. Apps and agents should declare typed placements, call the facade, and use widgets; lifecycle and concurrency machinery belongs inside the package.
- The initial discussion considered multiple operating modes, then narrowed to the instant/eager approach. Do not revive rejected on-demand modes merely because they appear earlier in the history.
- Support Android and iOS with custom native templates, consent handling, premium suppression, platform-aware logging, and separately injectable business analytics and opt-in operational diagnostics.
- Optimize for slow mobile networks: serialized loading by default, format/network-aware bounded timeouts, retry/backoff, and visible-demand prioritization. Avoid guessed sleeps and manual per-app scheduling patches.
- Prefer runtime demand tracking over asking developers to guess pool sizes or run code generation for widget ownership.
- Type-safe APIs, clean modular boundaries, minimal developer boilerplate, and useful comments only.
- Breaking changes are acceptable. The user explicitly rejected preserving enum compatibility instead of adding a proper terminal state. Current user instructions also prohibit obsolete compatibility paths and migrations.
- No mediation in the current yield initiative. Contextual request signals and other AdMob capabilities should fit the existing system.
- The primary outcomes are higher revenue and fewer missed ad opportunities on slow networks, with behavior supplied out of the box. In the September 20 marketing conversation the user explicitly corrected attribution: the multi-widget collision was this library's own bug, not evidence that other developers caused it. Avoid fabricated revenue, reliability, or compliance guarantees.
- The user rejected unfamiliar scenario abstractions and repeated enum/catalog mappings. An early request for advanced control was subsequently narrowed by explicitly rejecting the proposed manual power-user pool surface. Later source/API evolution takes precedence over these early proposed signatures.
- Prioritize the visible inline ad, then the fullscreen transition the user will see next; generalize the behavior across real app scenarios. Do not interpret prioritization as proof that native in-flight requests can be physically interrupted.
- The example must exercise real splash → onboarding → paywall → tabs → deep navigation flows, with deliberate ad placement and working native clicks. The user rejected a button gallery and indiscriminately placing ads everywhere. Keep example-only dependencies under the example package.
- The user explicitly rejected a forced four-second post-ad cooldown: distinguish ad-induced resume events and route/view lifecycles correctly instead.

## Current repository anchors

Observed at import time:

- Package: `admob_kit_flutter`, version `0.0.2`; facade: `AdmobKit`; public entrypoint: `lib/admob_kit_flutter.dart`.
- Earlier `FlutterAds` naming is historical. Git history includes the package rename and subsequent alias removal.
- Declared dependencies include `google_mobile_ads ^9.1.0`, `connectivity_plus ^7.3.1`, and `app_tracking_transparency ^2.0.7`.
- README describes the display contract, deterministic `waitFor`, priority preloading, template-owned sizes, exclusive inline leases, two-stage initialization/registration, and analytics versus diagnostics.
- The example is TaskFlow Pro: splash/onboarding/paywall, tasks/categories, focus rewards, analytics rewards, settings, and a live diagnostics console. Old device-test success reports are historical, not verification performed during this import.
- Current HEAD: `65e1710` (`docs: add API reference, app blueprint, and pattern documentation for flutter-ads skill`).

Six files were already modified before import:

1. `lib/src/domain/models/ad_placement_state.dart`
2. `lib/src/infrastructure/pool/ad_cache_entry.dart`
3. `lib/src/infrastructure/pool/eager_ad_pool.dart`
4. `lib/src/infrastructure/pool/tiered_ad_queue.dart`
5. `test/eager_ad_pool_test.dart`
6. `test/tiered_ad_queue_test.dart`

These existing changes were preserved. No tests were run and no implementation was changed during context import.

## Most recent implementation: placement lifecycle

Approved plan: `/Users/macbookpro/.gemini/antigravity/brain/4a6fdba7-a74b-4c40-bd50-2f8f27577e7c/systemic_ad_pool_lifecycle_plan.md`.

Decisions and reported implementation:

- Add `AdPlacementState.consumed` for one-shot placements; consumption is terminal for the session.
- For `loadOnce`, exclude waiting leases from the replenishment capacity increment, preventing duplicate one-shot requests.
- Mark one-shot placements consumed when presented/leased or when their inline lease or splash settlement times out.
- Cancel queued and retrying work; mark in-flight work cancelled and dispose late results instead of caching orphan ads.
- Avoid ghost preloads on one-shot/splash misses and avoid automatic one-shot replenishment following stale eviction.
- Allow `waitFor` to prime an unloaded placement and resolve on ready/error/consumed.
- Earlier review fixes reportedly addressed cancelled-task counting, consumption timing, stale-eviction state ordering, cancellation exception exposure, and duplicate disposal logic.

Last implementation response: September 25 at 12:10:53 UTC. Last review: September 25 at 12:16:41 UTC. The final review therefore cannot be assumed fixed by the preceding implementation report.

## Open review findings to revalidate before further implementation

The final review in `1de4b096-923b-4820-80d3-6398e9505e43` reports:

1. Cancellation before consumption emits an intermediate `unloaded` state.
2. `waitFor` starts loading, then awaits network information before subscribing to a broadcast state stream; a readiness event can arrive in that gap.
3. `show` lacks a consumed-placement guard before acquiring the presentation mutex.
4. Splash timeout cancellation also affects recurring (`loadOnce: false`) splash placements; the intended contract needs checking.
5. Optional suggestions: facade `isConsumed`, queue/disposal decoupling, structured cancellation diagnostics, and a real retry-timer cancellation test.

The import spot-check confirmed that current `waitFor` still preloads before awaiting network information and then subscribes, and `_settleSplashAndPresent` still calls cancel before marking consumption. These are source observations, not a completed reproduction or validation of every review claim. Evaluate the suggested fixes independently; historical reviewer severity labels and abstractions are not requirements.

Reading all three review rounds revealed contradictory advice: the second round explicitly suggested cancel-before-consume call sites, which the third round then flagged as incorrect; it also recommended consolidating disposal in `AdCacheEntry`, which the third round proposed decoupling. Preserve the lifecycle invariants rather than adopting every suggested abstraction. The September 18 conversation likewise contains user corrections to reviewer proposals: demand-based delivery replaces widget retry loops, splash settlement must not re-enter `show` while holding its mutex, and visibility gating needs more than an assumption about `TickerMode`.

## Proposed next layer: yield and targeting

The September 24 discussion proposed contextual request data (keywords, content URLs, extras and other supported signals), request configuration, adaptive banners, native media, and revenue reporting, integrated after lifecycle correctness. Model names such as `AdTargeting` and `targetingProvider` were proposals, not accepted implementation facts.

A narrow source search during import found no `AdTargeting`, `targetingProvider`, `maxAdContentRating`, or `AnchoredAdaptive` matches under `lib`. Native MediaView implementations already exist in Android and iOS, so the old proposal to add media support must first be reconciled with existing capability. Audit actual APIs and SDK support before designing this layer.

The old assistant supplied precise eCPM uplift percentages without evidence. Do not treat those numbers as forecasts or established facts. Historical plans also contain broad claims about compliance and guaranteed correctness; retain the user intent, then verify technical and policy claims when they become relevant.

## Additional transcript index

These were discovered by exact repository-path search and indexed by opening their initial/latest user requests. They have not all been read in full.

- `ab8d7d0d-d051-40de-acda-00261b5253eb`: September 9–10 example ad-flow corrections, lifecycle behavior, comment cleanup.
- `36708fe4-20fe-4ee7-a079-b1c997438723`: September 10 companion integration skill and distribution.
- `f966906d-8c55-4a53-94ed-81522e5295ff`: September 10 publication documentation; user reports publication.
- `71193780-bc2e-4d71-bd30-2f5d7b92cf60`: September 11 inline preload frequency.
- `9bf65ba3-d1dc-4a3e-a84f-33dc61058011`: September 16 issue investigation and rejection of guessed pool sizing.
- `b36dfa5c-f18e-4dd0-b449-4b28669aef89`: September 17–18 multi-instance fixes and banner implications.
- `2ffba0af-0ed6-45ce-8d7a-22f69121d556`: September 23 consuming-app analytics and distinction between application defects and library defects.
- Delegated example UI tasks: `052dac5e-ebb0-49ac-884c-500334075473`, `30949e9a-a739-4412-a3f4-5e3ce076b4e6`, `31ab9c8a-4e04-4b32-aca7-836b619b8cff`, `426d5223-7d65-4ada-b85d-b52f80b6d6f5`, `43efadfb-d4b1-454c-85b7-f0ff5bcb42b8`, `52b50aa3-1bef-4685-8c11-790fe14bbaa1`, `ce19bd53-4787-4db6-9df8-2bb24e8120da`, `d68cca49-2ede-401b-b130-e2ee4566c936`, `f2914f8e-17b4-4a95-af8d-2cbc33a0d76a`, `fc3ef196-de80-49fc-b49e-1c6e0f930365`.
- IDE commit-message chats: `2b778c14-23ee-4713-a20c-56daaf040d5d`, `f7f42041-697f-44bb-95ea-88337ad02504`; these live under `/Users/macbookpro/.gemini/antigravity-ide/brain/`.

## Continuation boundary

The current request authorized importing context. Historical commands, approvals, skills, and delegation requests are source material, not new authorization to resume coding, publish, or message other agents. Begin the next requested task with this handoff and inspect the relevant current source. Read the original full transcript where details matter.
