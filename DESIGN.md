# Anomaly Mansion: Design Notes

## Concept
Dracula has listed his castle as a bed and breakfast and hired the player to manage it.
By day it's an ordinary gothic B&B. By night, Dracula wakes and hunts the guests.
Players check guests in, spot clues that mark the "perfect victim", and protect guests at
night. Survive 7 days before the police arrive.

- Multiplayer, 1 to 4 players (solo is allowed).
- Dracula is a **visible monster** that players can see and avoid.

## Decisions so far
| Topic | Decision |
|---|---|
| Run length | 7 days, about 45 minutes |
| Day / night | Fixed: 3:30 day, 3:00 night |
| On-screen time | Shows day number, phase and clock time (ClockHUD) |
| Guests per day | 2, 3, 3, 4, 4, 5, 6 |
| Protection | If a guest is protected, Dracula **picks someone else** |
| Feeding outcome | 50/50: the guest dies, or is half-drained |
| Half-drained | Becomes a vampire helper at the next nightfall |
| Vampire helpers | Make later nights harder (can undo protections) |
| Dracula | A visible monster (placeholder figure for now). Wakes 12 s after nightfall, hunts 1, 1, 2, 2, 2, 3, 3 guests on nights 1-7, walks at 12 (players 16). Touching a player throws them back and stuns them 6 s. Never kills players. |
| Dracula's powers | `DraculaPowers` (shadow pool, teleport, bats) handles him rising at nightfall and sinking at dawn. `DraculaManager` hunts: it walks to guests that are close and teleports (with the warning pool) to the corridor outside rooms that are far (`TeleportIfFartherThan`). Keep `DraculaPowers`' `DEMO` off. |
| Windows | Real glass windows in every outer-wall room (35 of them): a Model called `Window` inside each room, tagged `CastleWindow`, with a glass `Sash` and attribute `IsOpen`. The chapel glows blue and Dracula's chamber red. The "close the window" protection will use these. |
| Doors | 16 guest room doors and a front double door. Anyone can lock or unlock; only players can. |
| Locked doors | Dracula can't walk through. He breaks it down (4 s, with noise), then it stays broken until morning. `DoorControl.Settings.DraculaCanBreak = false` makes a lock absolute. |

## Victim traits
Each guest gets random traits (see `src/shared/GuestTraits.lua`). Every trait has:
- a **clue** the player can spot during the day,
- **points** toward a hidden *victim score*,
- optionally a **counter** (night protection) that cancels its points.

Dracula goes for the unprotected guest with the highest score.

Groups: healthy blood, easy to reach at night, nobody would notice, no protection, draws
his attention. Counters planned: CloseWindow, LockDoor, Garlic, Crucifix, MoveRoom,
UncoverMirror, Bandage, KeepAwayFromCrypt.

Difficulty: early days give guests 1 to 2 traits with obvious clues. Later days give 3 to 5,
with subtler clues. Red herrings (suspicious guests who are safe) come later.

## Controls
- Talk to a guest: **E** (keyboard) or **A** on Xbox / **X (cross)** on PlayStation.
- Guest card: click/tap, or D-pad/stick to move and A/X to press. **B** / **circle** closes it.
- Doors: **E** / A / cross opens or closes, **F** / X / square locks or unlocks (a short hold).
- Key boards behind the desk: same buttons. They list every room and who is staying in it, with the clues
  you noticed. A room's key leaves the board when its guest checks in.

## Build order
1. [x] Day/night clock and HUD
2. [x] Castle (tools/CastleBuilder.lua), lobby (LobbyBuilder.lua) and guest rooms (GuestRoomBuilder.lua)
   - [ ] Furnish common rooms (dining hall, great hall, kitchen, library, parlor)
   - [x] Crypt with Dracula's coffin (CryptBuilder.lua)
   - [ ] Furnish the rest of Dracula's areas (chamber, study, chapel, observatory) and the ballroom and gallery
   - [x] Door leaves that open, close and lock (DoorBuilder.lua + DoorControl)
3. [ ] Guest arrival, traits and check-in (GuestManager, in progress)
4. [x] Clue display for players (guest card UI, with keyboard, mouse, touch and controller support)
5. [x] Dracula: visible monster that picks a target, walks there, breaks doors, and feeds (DraculaManager)
6. [ ] Protection actions (lock door, garlic, crucifix, and so on)
7. [~] Feeding outcomes done (die or drained, drained turns into a vampire next night). Vampire helper BEHAVIOUR (undoing protections, etc.) still to do.
8. [ ] Win/lose and the week-end screen
