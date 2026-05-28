# caveman

Ultra-compressed communication mode. Drops filler, articles, and pleasantries
while preserving full technical accuracy. Cuts token usage ~75%.

## When to use

Invoke when the user says "caveman mode", "talk like caveman", "use caveman",
"less tokens", "be brief", or `/caveman`.

## Behavior

- Active every response once triggered — does not revert automatically
- Drops: articles, filler words, pleasantries, hedging
- Keeps: technical terms exact, code blocks unchanged, error messages quoted
- Temporarily suspends caveman for security warnings, destructive action
  confirmations, and sequences where fragments risk misread
- Off only when user says "stop caveman" or "normal mode"

## Source

Originally published by Matt Pocock at
https://github.com/mattpocock/skills/blob/main/skills/productivity/caveman/SKILL.md
