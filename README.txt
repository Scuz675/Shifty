Restock merchant-close fix

Fixed:
- duplicate MERCHANT_SHOW on the same vendor open no longer resets processed items
- processed item guard now resets only on MERCHANT_CLOSED

Expected:
- open vendor once, target 1, have 0 -> buys 1 once
- same vendor window stays open -> does not buy again
- close vendor, reopen -> recount bags fresh


Build 2.5.0:
- Non-rotation polish build from current working base
- Bigger visual cleanup for the display overlay
- New tabbed in-game settings panel (General / Forms / Utilities)
- Version now prints in chat on login and via /shifty version
- Help text refreshed and startup module checks added


Build 2.5.1:
- Added overlay option to hide all text
- Settings panel now has stronger visible backgrounds
- Login text simplified to just version + /shifty hint
- Module check removed from automatic login spam and moved to /shifty doctor


Build 2.5.2:
- Built from the confirmed-good 2.5.1 settings panel base
- Hide-all-text now also hides the overlay title text
- Added /shifty doctor, /shifty reset, /shifty lock, /shifty unlock, /shifty export
- Added current role/mode display at top of settings panel
- Added show-only-with-target toggle
- Added reset defaults and debug page without changing rotation files
