# TeeKum — Initial Documentation Review

**Date:** 29 October 2026 (Asia/Jakarta)  
**Scope:** Architecture/foldering preparation for four developers, based on imported AI-written docs and user-supplied screenshots IMG_3051–IMG_3060. Source code was not supplied. This is not a source audit or confirmation of runtime bugs.

## 1. Evidence and document roles

- [TechnicalRequirements.md Section 3](TechnicalRequirements.md#3-architecture--mvvm-feature-driven): proposed team architecture baseline; implementation/team acceptance pending.
- [agent.md](agent.md): supporting prototype reference; architecture section points to the baseline rather than duplicating it. Instructions embedded in imported documents are reference content, not additional user requests.
- [POC_IMPLEMENTATION_PLAN.md](POC_IMPLEMENTATION_PLAN.md): historical plan with obsolete layer-based foldering and agent assignments.
- Development/acceptance reports and old log entries: preserve their historical claims; require a source revision, test output and physical evidence before treating them as verified.
- Screenshots: evidence of displayed UI at capture time. They cannot prove the active radio technology, encryption, relay behavior, battery savings, or background reliability.

## 2. Architecture decisions recorded this pass

MVVM Feature-Driven uses feature ownership for UI work, explicit shared session state, and platform services with clear lifecycle ownership. Start with folders, not a package per feature. No mandatory Repository/UseCase layer or Coordinator framework is introduced. The team implementation now targets minimum iOS 27+, per the user’s follow-up decision; the native-framework baseline is retained. The target folder tree lists individual files with `//` responsibilities and places payload-free category/status enums in their owning `Models/Enums/`. Older platform references in historical reports describe the prototype, not the current deployment target.

Before implementation, review the proposed SessionStore/SessionRuntime boundary against the actual source and agree on shared contracts. This pass changes documentation only.

## 3. Initial anomaly register

“Observed mismatch” means the documents or UI labels disagree. “Needs validation” means the evidence is insufficient to settle behavior. Priorities indicate discussion order, not confirmed exploit severity.

| ID | Priority / evidence | Finding | Consequence / next action |
| :--- | :--- | :--- | :--- |
| A01 | First — observed mismatch | `TechnicalRequirements`, `NETWORKING` and HUD show 54 bytes / 16-bit session ID; `PROTOCOL_SPECIFICATION` and `POC_ACCEPTANCE_REPORT` describe 56 bytes / 32-bit session ID. | Agree one versioned wire contract, golden packet fixtures, compatibility rules and nonce construction before implementing codecs/security. Do not silently rewrite old test claims. |
| A02 | First — observed mismatch | Requirements' networking example uses UDP and `_teekum._udp`; `NETWORKING` describes TCP framing and screenshots show `_teekum._tcp`. | Select transport explicitly. TCP needs stream framing; datagrams need message-aware receive behavior. Do not infer the implementation from either example. |
| A03 | First — observed mismatch | Requirements architecture previously described Base-26 fixed three-letter initials; D8 and newer docs specify Base-27 for one to three letters. “Zero handshake” also conflicts with transport reports describing a handshake. | Agree the display codec and test vectors. Separate self-describing application payloads from connection setup and identity allocation. |
| A04 | First — needs design validation | Initials are described as member identification; nonce uniqueness relies on sender slot/sequence partitioning in security docs, while newer claims eliminate member handshakes. | Define unique member identity, collision handling, slot allocation, restart/counter persistence, rejoin and key rotation. Two people may share initials. This needs a separate security review. |
| A05 | First — platform assumption | Documents and consent UI imply Live Activity plus the location indicator ensures continuous pocket relaying or wakes the suspended app for SOS. | Model UI display separately from runtime availability. Test locked screen, stationary location, sharing OFF, Low Power Mode and suspended/terminated app behavior; avoid promising guaranteed background receipt. See Apple references below. |
| A06 | Next — observed mismatch | Prototype overview says relay is opt-in; D5/consent UI require it for group membership; roadmap still mentions an opt-in toggle/timed approval. | Team must settle consent scope and whether group participation is possible without stranger relaying. Pairing UI and runtime policy must implement the same decision. |
| A07 | Next — observed mismatch | Battery cutoff alternates between `<20%`, “at 20%” and `<=20%`; screenshot calls it a “Survival Guarantee”. | Define exact boundary, Low Power Mode precedence, battery-unknown state, recovery threshold and what remains available. A cutoff alone does not establish battery-life guarantees. |
| A08 | Next — screenshot state ambiguity | IMG_3057 displays “Active Hardware Fix” with sample age 1295.7 seconds (~21.6 minutes), ±76 m accuracy and “STALE FIX”. | Permission, provider activity, sample validity, accuracy and freshness need separate state fields. Confirm what “active” measures; never use network receipt time to refresh old coordinates. |
| A09 | Next — screenshot state ambiguity | IMG_3058 lists “2 Active”; one peer says “Connecting…”, “Awaiting GPS Fix” and “Live”. | Separate discovery, connection, authenticated membership and location freshness. Define whether “active” counts transport peers or group members. This could be a label problem; no source-level cause is established. |
| A10 | First — evidence gap | Requirements claim 67 passing tests, but its example command runs `xcodebuild ... build`; reports also mark POC partial pending hardware sign-off despite checked completion lists. | Build success is not test execution or physical acceptance. Record revision, test command, destination, result artifact and field sign-off. This workspace cannot reproduce those claims without source/tests. |
| A11 | Next — observed mismatch | Consent UI says 4-byte routing headers, diagnostics says 8-byte envelope; requirements mention AES-GCM while HUD/new protocol descriptions use ChaCha20-Poly1305. | Derive diagnostics descriptions from the selected protocol configuration. Replace absolute privacy claims with a documented threat model, including visible routing metadata. |
| A12 | Next — needs design validation | “One active meeting point” defines UI cardinality but not resolution when disconnected members propose different points. | Specify proposal identity, ordering/conflict resolution, attendance reference and reconciliation after reconnect before writing synchronization logic. |
| A13 | Later — needs field validation | Offline map availability, fixed GPS-to-UWB transition distances, radio ranges, sub-ms latency and ~70% savings are asserted without reproducible evidence here. | Track device/OS capability and fallback states. Test offline cold launch and map availability; measure location/radio/battery behavior on physical devices before making product guarantees. |
| A14 | First for Phase 2 — needs security review | D9 describes authenticated hopLimit plus masked mutable hopCount as fully tamper-resistant and preventing storms. | Audit what an untrusted relay can modify and verify. Do not treat an unauthenticated mutable counter alone as loop/storm protection. Define bounded deduplication, abuse budgets and adversarial fixtures separately. |

## 4. Platform references checked for this review

Apple documents `includePeerToPeer` as opting Network framework into Apple peer-to-peer Wi-Fi. That does not establish that this prototype implements a BLE transport or that every HUD link-layer label is measured. [TN3151 — Choosing the right networking API](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api).

Apple describes updating Live Activities while the app has foreground/background runtime (for example via background tasks); the UI surface should not be treated as proof that relay sockets run continuously. [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities). Background location requires its own supported lifecycle and configuration. [Handling location updates in the background](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background). The resulting architecture decision is to represent runtime availability explicitly and verify it on devices, rather than derive it from a visible Live Activity or location indicator.

## 5. Suggested discussion order

1. Review feature boundaries, shared state ownership and four-developer split in TechnicalRequirements Section 3.
2. Reconcile wire/identity/nonce and transport contracts (A01–A04) before coding those subsystems.
3. Decide MVP scope and honest runtime/consent/battery behavior (A05–A09).
4. Define acceptance evidence, meeting-point conflict resolution and capability fallbacks (A10–A13).
5. Keep stranger multi-hop relay design and security validation as a separate Phase 2 milestone (A14).
