# Shifty – Druid Rotation Helper (Turtle WoW)

Shifty is a modular Druid rotation and utility addon designed for Turtle WoW (Vanilla 1.12.1).

This version introduces a fully separated rotation system, allowing each role to be optimised independently without affecting others.

## Features
- Bear, Cat, Moonkin separated rotations
- Overlay with current/next spell
- Debug system enabled by default
- Buff + Restock systems

## Commands
/shifty single
/shifty aoe
/shifty show
/shifty hide
/shifty reset

## Hurricane
Hurricane is prompt-only (not auto cast)

Macro:
/run if not SpellIsTargeting() and not CastingBarFrame.channeling then CastSpellByName("Hurricane") end
/run if SpellIsTargeting() then SpellTargetUnit("target") end
