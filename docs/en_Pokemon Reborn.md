# Complete Pokémon Reborn Archipelago Guide

## What items and locations get shuffled?

Most items are included can be given to the player. This includes:
- Badges
- Type-powering items (Silk Scarf, Never-Melt Ice, etc)
- Choice items + Life Orb + Focus Sash
- Nuggets
- Healing items
- TM and TMX
- Berries
- Story items
- Bicycle
- Rods
- Mega stones
- Z-cristals
- Other rare items

Some rules to consider:
- Crystal Key: is replaced by an item called 'Progressive Crystal Key'. Works the same way as vanilla.
- Lots of checks can be missed if they haven't been checked when the story excepts it. These checks all send filler items to avoid getting blocked due to having missed important items 

## What options do I have?

### Logic options

| Options      | Description | Value |
| ------------ | ----------- | ----- |
| Badges      | Badges are provided by their corresponding Gym Leader, or randomly found anywhere in the multiworld       | `vanilla`, `shuffled`
| Story Gates   | What unlocks the story: beating a Gym Leader without needing its badge, the opposite, or both. See [the story gate guide](story_gate.md) for more information | `leader`, `badge`, `both`

### Quality of life options

| Options      | Description | Value |
| ------------ | ----------- | ----- |
| Experience Multiplier | Password `exppercent`, percentage of XP gained: 100 = vanilla, 150 = 50% more XP, 0 = no XP, and negative means losing XP | A multiplier between `-1000` and `1000`|
| Hard Level Cap | Password `hardcap`, which make it so that Pokémons don't gain XP above the current level cap | `true`, `false` |
| Pinata | Password `pinata`, grind trainers skip battle to immediately give exp candies | `true`, `false` |
| Easy HMs | Password `easyhms`, you don't need to teach a Pokémon a TMX to use it in the overworld as long you have the item and enough badges | `true`, `false` |
| Starter | A mix of several passwords to customize your starter choice | `vanilla`, `eevee`, `vulpix`, `freestarter` |

## What's the deal with passwords?

As you (probably) know, the game has built-in passwords you can input, either at the start of the game during Ame's dialogue or using Data Chips. There even are randomization passwords, but they're handled on the game's side, which isn't compatible with AP's item randomization, or even Pokémon randomization in the case of a run using dexsanity.

For the consistency of this APworld, and because I still have yet to test with potentially game-breaking passwords, I chose to ban passwords to make sure nothing would break the APworld's logic.

To make sure this rule is enforced, Ame will wait for you to connect to the APworld at the start of the game, and you can't input a password in the PC. Data Chips are still part of the game's pool because they have other use than just passwords.

Thankfully, not all passwords are game-breaking, so I still allowed a few of them to be injected in the game through your .yaml. Those are mainly QoL passwords, so they shouldn't affect the logic as much as others.

As I will test with more passwords to make sure nothing is game-breaking, I might, instead of having a whitelist of non-game-breaking passwords, implement a blacklist of some passwords I'm 100% aren't compatible with AP. But passwords aren't a priority for now, so don't expect this change for now. 

If you REALLY want a password to be added in the APworld, send me a message and I'll try to figure out a way to implement it. Or just force your way through your save file to turn it on, but I'm not responsible for any game or logic-breaking sequences that might occur.

## If I randomize badges, won't there be an issue with level caps?

No, the vanilla game already handles it fine by computing based on the number of badges you own, no matter which one it is. If you have 1 badge, your level cap is set to 25, no matter if is Julia or Saphira's badge. And yes, this means you can theorically challenge Julia at level 100.

In the future, it is planned to add an option to compute your level cap based on this rule, or based on the number of gym leaders you've defeated for an experience closer to vanilla.

## What about TMX (HM)?

Same logic applies. Unlike main games where a specific badge unlocks usage for a particular HM, Reborn unlocks TMX usage based on the number of badges you own, and, again, no matter which badge you have. 

Even though I could add an option to change that based on the number of defeated gym leaders, I don't see the point in doing so, unlike level caps because gym leaders were meant to be fought at a certain level, so don't expect one for now.

## How much of the game is planned to be available?

Up until the final battle against Lin or Arceus after the Elite Four. I don't feel like doing the postgame for now.

## How are story splits handled?

So far, the only story splits I've gone through are the policemen in Rhodochrine Jungle, the Aqua and Magma gangs, and whoever gets kidnapped in Belrose Manse. I still have to go through the give/refuse ring variations, and the Reshiram/Zekrom/Mixed routes.

Surprisingly, so far, story splits haven't made logic or locations harder to consider. The only thing I had to account for was the Aqua and Magma gangs providing some different items, which are easily handled by having 2 locations triggering the same check. While I hope it stays that way, I'm still considering the fact I might have done some mistakes by forgetting some stuffs. This will be studied in depth later.

I also expect that future splits, and even the Lin/Anna split, will make things harder to consider. If it happens, I have 3 ways to handle them:
- if all splits provide the same number of items, I can map a check to be triggered by 2 (or more) locations
- if a split provide 1 or 2 more item than another split, I can force that check to only send filler item, so that player not taking that route won't miss on important item
- if a split provide way more items than another split, I'll probably have to add options to force the player onto a specific route, to know in advance how many checks to handle. I don't feel like going that way, and it seems unlikely so far, so let's hope it doesn't happen

## Do I need to use PopTracker?

I strongly advise you to use it, considering how many (hidden) items are in this game.

In addition, I've added a few features to make tracking easier:

- If a hint is located in your game, the location will be highlighted in yellow
- By hovering over a check, the tracker tells you if it's missable
- If a check can no longer be obtained, it shows as a red diamond

## Any ETA for full release?

No, and even if I did, I wouldn't want to share it until I am sure the project is completed and works fine.