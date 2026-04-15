Restock merchant-close fix

Fixed:
- duplicate MERCHANT_SHOW on the same vendor open no longer resets processed items
- processed item guard now resets only on MERCHANT_CLOSED

Expected:
- open vendor once, target 1, have 0 -> buys 1 once
- same vendor window stays open -> does not buy again
- close vendor, reopen -> recount bags fresh
