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
- Key boards behind the desk: same buttons. They list every room and who is staying in it, with the clues
  you noticed. A room's key leaves the board when its guest checks in.

## Build order
1. [x] Day/night clock and HUD
2. [x] Castle (tools/CastleBuilder.lua), lobby (LobbyBuilder.lua) and guest rooms (GuestRoomBuilder.lua)
   - [ ] Furnish common rooms (dining hall, great hall, kitchen, library, parlor)
   - [x] Crypt with Dracula's coffin (CryptBuilder.lua)
   - [ ] Furnish the rest of Dracula's areas (chamber, study, chapel, observatory) and the ballroom and gallery
   - [ ] Door leaves that open, close and lock (needed for the LockDoor counter)
3. [ ] Guest arrival, traits and check-in (GuestManager, in progress)
4. [x] Clue display for players (guest card UI, with keyboard, mouse, touch and controller support)
5. [ ] Dracula: visible monster that picks a target and hunts
6. [ ] Protection actions (lock door, garlic, crucifix, and so on)
7. [ ] Feeding outcomes, vampire helpers
8. [ ] Win/lose and the week-end screen
