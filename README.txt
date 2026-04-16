Restock merchant-close fix

Fixed:
- duplicate MERCHANT_SHOW on the same vendor open no longer resets processed items
- processed item guard now resets only on MERCHANT_CLOSED

Expected:
- open vendor once, target 1, have 0 -> buys 1 once
- same vendor window stays open -> does not buy again
- close vendor, reopen -> recount bags fresh


Build 2.4.1:
- Safe full-package rebuild from 2.3.2 base
- Bear Single rage shaping: Maul less greedy, Savage Bite as true high-rage dump
- Bear AOE keeps Swipe-first flow with a cleaner Demo opener


Build 2.4.2:
- Safe full-package rebuild from 2.4.1 base
- Bear Single: Maul less greedy, Savage Bite pushed later as true high-rage dump
- Bear AOE: Swipe-first cleanup, Maul less greedy, Savage Bite much later
- Core: legacy Bear path thresholds aligned so Bear module and Core do not fight each other


Build 2.4.3:
- Fixed Bear module syntax error from previous 2.4.3 package
- Core Bear path is dispatch-only
- Bear decisions/execution owned by ShiftyBear.lua


Build 2.4.4:
- Quality-of-life: overlay now hides outside Bear, Cat, and Moonkin forms


Build 2.4.5:
- Overlay is now fully click-through
- When hidden it no longer blocks mouse interaction underneath


Build 2.4.6:
- Overlay updates pause while CharacterFrame is visible
- Overlay hides when not targeting and not in combat
- Idol of Ferocity checks now use a cached lookup instead of polling inventory every prediction tick
- Equipment cache resets on PLAYER_ENTERING_WORLD and PLAYER_EQUIPMENT_CHANGED


Build 2.4.8:
- Safe full-package rebuild from 2.4.6 fixed base
- Preserves overlay hide outside Bear/Cat/Moonkin
- Preserves fully click-through overlay behavior
- Moonkin AOE no longer auto-predicts Hurricane
- Hurricane now appears as a manual prompt in the upper-left cooldown icon slot


Build 2.4.9:
- Safe full-package rebuild from 2.4.8 base
- Moonkin AOE fixed so Hurricane remains a prompt only
- Restored actual AOE cast flow: Insect Swarm / Moonfire / Wrath / Starfire
- Reduced Hurricane prompt spam in logs and overlay refreshes
