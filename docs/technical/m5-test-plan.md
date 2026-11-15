# M5 test plan — life, work and ownership

Automated: `tests/test_runner.tscn` (economy has no buy/sell or crafting exploits, deterministic job board, job payment and XP, skill levels widen the zone, rent debt, bounded cart income, room upgrades and crafting, save migration 4→5) and `tests/smoke_test.tscn` (shop, room shop, jobs board, the repair minigame, workbench, cart, overnight resolution, save/load).

## Manual checks

1. New game → Jonah → "Got any work?" → then "Could you spare some scrap?" — 4 scrap.
2. Cork board on the yellow building → take a job; the journal-less board shows "Taken (1/2)".
3. Go to the job's object (prompt "Repair") → press E when the needle is in the green zone. Three misses fail without losing scrap; success pays money, +1 relationship, XP toast.
4. Scrap heap by the bins: salvage once; a second time the same day gives nothing.
5. Jonah → "Let's trade" → buy and sell; selling pays half value.
6. Mrs Halloway → "About my room..." → buy the workbench; it appears in your room. Craft a repair kit.
7. Buy the mattress → max health +1 in the HUD.
8. Sleep 7 nights with little money → rent-short toast, no penalty; earn money → debt is taken on the next morning.
9. Reach repair level 3 and Jonah friend → Jonah offers the cart; it appears on the plaza. Stock kits, open, sleep → morning report toast.
10. Fix the fountain → it stays fixed after saving and loading; it never reappears on the board.
11. Russian: all new screens and toasts translated, no gendered forms for the player.
12. Gamepad: every work screen is navigable with the D-pad and A; B/Esc closes.
