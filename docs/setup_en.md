# Pokemon Reborn Setup Guide

## Required Software

- Pokémon Reborn, version 19.5.x minimum
- The `RebornAP.rb` mod and the `.apworld` file
- [Archipelago](https://github.com/ArchipelagoMW/Archipelago/releases)
- [PopTracker](https://poptracker.github.io/) (optional)
- The `pokemon_reborn_ap.zip` data for PopTracker (optional)

## Installation

1. Download `RebornAP.rb` and paste it into your `/patch/Mods` of your Pokémon Reborn folder. Create the folders if needed.
2. Download the `.apworld` for the game, and either run it or paste it into your `custom_worlds` folder from your Archipelago installation.
3. If you want a PopTracker for the game, download the corresponding package and paste it into the `pack` folder of your PopTracker's installation

If the mod gets updated, you'll need to redo these steps to get the latest version.

## Joining a MultiWorld Game

1. In the Archipelago Launcher, use the `Option Creator` menu to select your options. You will get a .yaml file, which you can use to generate a game.
2. Once you've installed the `.apworld`, a 'Pokémon Reborn Client' will appear in the Archipelago Launcher. Select it.
3. Connect to the server with `/connect <address:port>` and enter your slot name.
4. Start the game and load your save.

## Troubleshoot

### The client asks for some permission, or my firewall/antivirus/some other protection warns me about something, have you put a virus in the code?

No, I haven't, and you can literally check the code to make sure I didn't.

Short answer for non-nerd people: the client needs a way to communicate with the game to trigger events, send items, etc, based on the game's internal state and memory. To do that, it opens a socket on port 47630 (a port that's rarely used). The game, through the mod, connects to it when you create or load a save file. Your antivirus is warning you about the socket creation, which you can safely accept.

Keep in mind this logic is the same used in some other AP installations, such as the BizHawk and SNES ones.

### The client doesn't open

Most likely because something else on your PC is using port 47630. Close whatever is using it and try again.