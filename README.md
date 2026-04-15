# Shifty - Druid Helper (Turtle WoW)

Shifty is a lightweight Druid addon for Turtle WoW (Vanilla 1.12) that provides:
- Rotation assistance (Cat, Bear, Moonkin)
- Automatic self-buffing
- Smart reagent restocking
- Clean UI with minimal clutter

---

## ⚙️ Commands

/shifty
- Opens the settings panel

/shifty single
- Enables single target rotation

/shifty aoe
- Enables AoE rotation

---

## 🧠 Features

### 🔄 Rotations
Supports:
- Cat DPS (single + AoE)
- Bear (threat-focused)
- Moonkin (single + AoE)

Automatically adapts based on:
- current form
- selected mode (single / aoe)

---

### 🛡️ Buff System
- Automatically applies:
  - Mark of the Wild
  - Thorns
- Uses reliable Vanilla-style casting (no spam)
- Only buffs when:
  - not shapeshifted
  - not mounted
  - not dead/ghost

Toggle in settings:
- Use Mark of the Wild
- Use Thorns

---

### 🛒 Restock System
- Automatically buys reagents when opening a vendor
- Uses accurate bag counting (no overbuying)
- Only tops up to your configured amount

Supports:
- Maple Seed
- Stranglethorn Seed
- Ashwood Seed
- Hornbeam Seed
- Ironwood Seed
- Wild Berries
- Wild Thornroot

Behavior:
- Only buys what you are missing
- No repeated purchases while vendor is open
- Rechecks inventory on next vendor open

---

## 🖥️ Settings Layout

### LEFT
[General]
- Display Enabled
- Debug
- Auto Faerie Fire
- Use Mark of the Wild
- Use Thorns

Controls:
- Set Single
- Set AOE
- Reset
- Clear Logs

---

### MIDDLE
[Cat]
- Shred
- Rake
- Tiger's Fury
- Powershift
- Cower
- Claw on adds

[Bear]
- Maul
- Swipe
- Savage Bite
- OOC Powershift
- Demo Roar

---

### RIGHT
[Restock]
- Reagents + quantity controls (±1)

---

## 🎯 Design Philosophy

Shifty is built to be:
- Lightweight (Vanilla-friendly)
- Reliable (no spam loops)
- Modular (buff/restock/rotation separated)
- Practical (real gameplay improvements, not theory)

---

## 🧪 Debugging

Enable Debug in settings to log:
- rotation decisions
- buff activity
- restock actions

Logs are stored in SavedVariables.

---

## 📌 Notes

- Designed for Turtle WoW (Vanilla 1.12)
- Does not rely on modern WoW API features
- Works alongside pfUI and controller setups

---

Enjoy 👍
