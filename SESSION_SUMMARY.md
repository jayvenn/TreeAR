# TreeAR – Session Summary

Summary of changes made in this session so another person can quickly understand what was done.

---

## 1. Demo-friendly balance (Easy mode)

Balance was tuned so the full game flow can be demoed without dying:

- **Player:** More HP (220), higher damage (28), longer attack range (1.9 m), longer invulnerability after hit (1.4 s), bigger heals (55).
- **Boss (The Hollow):** Less HP (280), slower movement, longer telegraphs, longer idle between attacks, lower damage per attack.
- **Spirit chase:** Longer duration (28 s), slower spirit, and **touch no longer kills you** – the spirit does a small amount of damage (1) and **backs off** for ~2.2 s, then chases again. You only lose if your HP reaches 0 or the timer runs out (then you win). Spirit chase also **fully heals** you when it starts in Easy mode.

---

## 2. Spirit chase behavior change

- **Before:** If the spirit touched you → instant game over.
- **After (Easy):** Touch = 1 damage + spirit retreats for 2.2 s, then chases again. Defeat only when HP hits 0; surviving the countdown = victory.
- **Scene director:** New `retreatSpirit(from:speed:deltaTime:)` moves the spirit away from the player during backoff.
- **Spirit chase tip:** When the chase starts, a one-time tip appears: *“Avoid the spirit. It backs off when it touches you. Survive the timer!”* (5 s).

---

## 3. Intro screen

- **Subtitle:** A subtitle above the “Enter the Jungle” button was added, then **removed** again, so the intro is back to just the sprout animation and button.
- **Difficulty toggle:** The **home screen** now has an **Easy / Nightmare** segmented control above “Enter the Jungle.” The user picks difficulty before starting; the choice is stored in `Constants.isDemoMode` (Easy = true, Nightmare = false).

---

## 4. Single difficulty toggle in code

A single flag drives all difficulty:

- **`Constants.isDemoMode`** (in `Constants.swift`): `true` = Easy, `false` = Nightmare.
- **Easy:** All the demo-friendly values above (tankier player, weaker boss, spirit damage + backoff, full heal at spirit chase).
- **Nightmare:** Original balance (100 HP, 10 dmg, 600 boss HP, harder boss, spirit touch = instant death, no heal at spirit chase).

These files read `Constants.isDemoMode`:

- `Constants.swift` – defines the flag (and now wraps it in `enum Constants` so it can be set from the intro).
- `PlayerCombatState.swift` – `init(isDemo:)` defaults to `Constants.isDemoMode`.
- `BossCombatManager.swift` – `maxHP` computed from the flag.
- `BossAttack.swift` – `telegraphDuration` and `damage` branch on the flag.
- `BossPhase.swift` – `idleDurationRange` and `moveSpeed` branch on the flag.
- `ARExperienceViewModel.swift` – spirit chase duration/speed, touch = damage+backoff vs instant death, and full heal at chase start only in Easy.

---

## 5. Home screen Easy / Nightmare toggle

- **Where:** Intro screen (`IntroductionViewController`), above the “Enter the Jungle” button.
- **Control:** `UISegmentedControl` with segments **“Easy”** and **“Nightmare”**.
- **Behavior:** On load, the selected segment reflects the current `Constants.isDemoMode`. When the user changes the segment, `Constants.isDemoMode` is updated (Easy = index 0, Nightmare = index 1). When “Enter the Jungle” is tapped, the game runs with the selected difficulty.
- **Constants:** `Constants.isDemoMode` was changed from `let` to `static var` and placed inside `public enum Constants` so the intro screen can both read and write it.

---

## Files touched (high level)

| Area | Files |
|------|--------|
| Difficulty / constants | `Core/Constants.swift` (added `isDemoMode`, wrapped in `enum Constants`) |
| Player | `Combat/PlayerCombatState.swift` (demo vs normal stats via `init(isDemo:)`) |
| Boss | `Combat/BossCombatManager.swift`, `Combat/BossAttack.swift`, `Combat/BossPhase.swift` (branch on `isDemoMode`) |
| Spirit chase | `AR/ARExperienceViewModel.swift` (duration, speed, touch = damage+backoff vs instant death, heal at start); `AR/ARSceneDirector.swift` (added `retreatSpirit`) |
| Intro / home | `AR/IntroductionViewController.swift` (Easy/Nightmare segmented control, syncs `Constants.isDemoMode`) |
| UI / animation | `AR/ARViewController.swift` (spirit chase tip, `Constants.animationDuration`) |

---

## How to switch difficulty

- **In app:** Use the **Easy / Nightmare** control on the home screen before tapping “Enter the Jungle.”
- **In code:** Set `Constants.isDemoMode = true` (Easy) or `false` (Nightmare) in `Constants.swift`; the intro toggle will show and update that value when the user changes the segment.
