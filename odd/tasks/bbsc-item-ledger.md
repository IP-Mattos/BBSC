# BBSC item ledger
Objective: stop guests permanently losing key items gained in a host's world. Branch: fix/bbport-195-load-race (fork IP-Mattos/BBSC). Strategy: single work unit, feature branch push; no PR. Runner: none for game behaviour; CI build plus pure-function checks where possible.

## Specs
- S1 (user, L1): "Que no se pierdan objetos clave. Juntás uno como invitado y, al volver a casa, desaparece. Además queda marcado como tomado, así que no lo podés juntar de nuevo." The guest ends up holding, at home, the key/unique goods gained in a host's world.
- S2: Records survive a crash or restart: per-character file under the mod data directory.
- S3: Existing behaviour unchanged for hosts, solo play, normal consumables, gems and weapons. Items already held are not duplicated.
- S4: Each restored item and each failure is logged (LOG_INFO + timeline).
- S5 (assumption): a switch in the code's existing style, default on, turns it off.

## Tasks
- T1 | S1-S5 | delegated (context backstop) | status: built (CI pending), in-game untested | commit: see git log (feat(mod): note key items taken as a guest...)

## Log
- L1 (2026-11-03, user, on "Que no se pierdan objetos clave... ¿Querés que la haga en nuestro fork?"): "ok"
- Engram mirror pending: this session ran from the home directory; project scope unresolved.
- 2026-11-03 T1 written by one delegated writer (inline in its own context): hook on 0x016D8850 (give windows only), per-character file item-ledger/owed-<user>-<slot>.txt, restore at home via GiveBbscBossGoods, switch SHADPS4_BBSC_ITEM_LEDGER=0. No unit runner: pure parse/format helpers not compiled standalone (no local toolchain). S1-S5 covered in code; S1 needs an in-game test. Out of scope: repairing old guest-items entries.
