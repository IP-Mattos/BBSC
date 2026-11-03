# BBSC item ledger
Objective: stop guests permanently losing key items gained in a host's world. Branch: fix/bbport-195-load-race (fork IP-Mattos/BBSC). Strategy: single work unit, feature branch push; no PR. Runner: none for game behaviour; CI build plus pure-function checks where possible.

## Specs
- S1 (user, L1): "Que no se pierdan objetos clave. Juntás uno como invitado y, al volver a casa, desaparece. Además queda marcado como tomado, así que no lo podés juntar de nuevo." The guest ends up holding, at home, the key/unique goods gained in a host's world.
- S2: Records survive a crash or restart: per-character file under the mod data directory.
- S3: Existing behaviour unchanged for hosts, solo play, normal consumables, gems and weapons. Items already held are not duplicated.
- S4: Each restored item and each failure is logged (LOG_INFO + timeline).
- S5 (assumption): a switch in the code's existing style, default on, turns it off.

- S6 (user-approved list, item 2): "Que avise cuando algo falla. Hoy tocás la campana y no pasa nada." An on-screen notice appears when a host rang the sign but the join failed, reusing the mod's existing notice mechanism.
- S7 (item 3): "Que detecte versiones distintas... Debería decir 'tu amigo tiene otra versión' apenas se cruzan." A player meeting an incompatible BBSC build is told so, if the existing channels can carry it; otherwise report what is possible.
- S8 (item 5): "Altar y mesa más rápidos." The workshop tool checks open well below the current ~90 s after entering the host's Dream, with the same result.
- S9 (item 6, L3): a guest whose character has an oath (covenant) rune equipped in their own world can still be found and summoned for co-op, the same as without it. Invasions, PvP, the duel bell and covenant rewards stay as they are, and the guest still joins as a friendly phantom, never as an adversary.
## Tasks
- T1 | S1-S5 | delegated (context backstop) | status: built (CI pending), in-game untested | commit: see git log (feat(mod): note key items taken as a guest...)

- T2 | S6 | delegated (context backstop) | status: built (CI pending), in-game untested | commit: feat(mod): tell the guest when a host's bell did not become a join
- T3 | S7 | delegated (context backstop) | status: built (CI pending), in-game untested | commit: feat(mod): warn a guest when the host that rang runs another BBSC
- T4 | S8 | delegated (context backstop) | status: built (CI pending), in-game untested, speed unmeasured | commit: perf(mod): find the Dream's workshop checks in one memory walk
- T5 | S9 | inline (no Write-rule reason) | status: cause confirmed, role rewrite built, in-game untested | commit: feat(mod): log the sign role a guest posts and a host asks for
## Log
- L1 (2026-11-03, user, on "Que no se pierdan objetos clave... ¿Querés que la haga en nuestro fork?"): "ok"
- Engram mirror pending: this session ran from the home directory; project scope unresolved.
- 2026-11-03 T1 written by one delegated writer (inline in its own context): hook on 0x016D8850 (give windows only), per-character file item-ledger/owed-<user>-<slot>.txt, restore at home via GiveBbscBossGoods, switch SHADPS4_BBSC_ITEM_LEDGER=0. No unit runner: pure parse/format helpers not compiled standalone (no local toolchain). S1-S5 covered in code; S1 needs an in-game test. Out of scope: repairing old guest-items entries.
- L2 (2026-11-03, user, on grouping items 1, 2, 3 and 5 into one DLL for one test session): "si"
- L3 (2026-11-03, user): "pero no deberia pasar"
- 2026-11-03 T5 inline: capture p10124 shows the guest's own sign with role 23 while the Hunter oath rune is on and role 7 after it comes off (ManagerScan, same minute the host rang); SosStatus event_bits stay 32 either way. 0x01872360 (SosStatus.Update) asks a search for roles 7 (bit 1), 8, 18, 21-23 (bit 0x10), 24-25 only, so a role-23 sign is not asked for by a plain host. The routine that sets the role is not found yet, so no patch is shipped; only read-only role logging (SummonPost.Build 0x01E90E30, InsertType, ManagerScan). Next test: guest with the rune on, then off; read the `BBSC sign roles:` lines of both players.
- 2026-11-03 T5 inline: test3 logs of both players confirm the cause: guest role 23 with the Hunter rune, role 7 without; host "search asks for role 7" only. SummonPost.Build now posts role 21-23 as 7. Build only; in-game test pending, including that the guest joins as a white phantom and not as an adversary.
