# Pokemon Reborn Archipelago

An [Archipelago](https://github.com/ArchipelagoMW/Archipelago) randomizer for Pokémon Reborn, a Pokémon fangame.

This is currently a prototype, work is still in progress. For now, only checks up until Luna (9th Gym Leader) have been implemented and tested.

A PopTracker is also available to help. It tracks all maps and items available, while considering logic and roadblocks.

## What does randomization do to this game?

Everything that provides an item becomes a check. This includes:
- Item balls
- Hidden items
- Items given by NPCs

Considering how big this game is, I highly advise you to play with the PopTracker package and the official Pokémon Reborn wiki open.

As of now, neither wild nor trainers' Pokémons are randomized. This is a planned feature, once all of the game's checks are done.

## What's the goal?

Since the game isn't finished yet, the main goal is to defeat Luna.

While the "actual" goal (once development is done) will be to defeat Lin or Arceus, I will probably keep the Luna one, to offer a more accessible goal.

In the future, you will also be able to choose to beat X champions or collect X badges to adapt your run's length.

## I want to play, how do I set it up?

Check [the setup guide](docs/setup_en.md).

## Are there more things I need to know about the game?

Check [the complete Pokémon Reborn AP guide](docs/en_Pokemon%20Reborn.md).

## Roadmap

### Very important priority

- Actually finish the rest of the game's checks
- Detect automatically when the goal is achieved
- Test in a multiworld with other games than just Reborn

### Important priority

- Wild Pokémon randomization
- Trainers' Pokémon randomization
- All Pokémon seen in dex
- Dexsanity
- Shopsanity
- Open world (or at least something that lets you visit late game parts when you have appropriate items)
- More password implementation
- Consider checks specific to route differences and story splits (if needed)
- Add an option to include Flash locations in-logic without the need of owning Flash
- Add an option to increase level cap based on collected badges or defeated gym leaders

### QoL

- Skip the trainer's name input at the start of the game by using the one from the .yaml
- Display a visual clue on hidden items

## AI disclosure

Most of the project's code was done using AI. This includes the Ruby mod, Python client, data it needs to work with, and Poptracker package. It also made some scripts to automate laborious work, such as going through the wiki to list all available items from every area in the game.

I used AI in order to make development faster. Nothing it wrote was out of my skill range, it only made things I can do that would have been much slower than AI doing it. All code made by AI was tested, as well as reviewed and challenged by me.

All design decisions, such as changes made to the game, options, and more, were made by me. AI answered some questions I had regarding the game's logic (especially about story flags activation) to help me make better decisions, but I made sure it never took any decision on its own.

To make sure AI wouldn't get things wrong when it comes to the game's implementation, design, plot, or other important things, it was first trained on several data sources. This includes (but not limited to) the official AP doc, the Pokémon Reborn wiki, the game's source code, and my own notes.