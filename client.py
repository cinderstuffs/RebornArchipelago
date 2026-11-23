"""
Bridge between the Archipelago server and the Ruby mod running inside Pokémon Reborn.

The mod connects to this client over TCP on localhost. Both sides exchange JSON objects, one per line:
- client -> mod: "init" (AP locations of the save + what they contain, options, story ids to send), "items" (received
  items), "ap_status"
- mod -> client: "hello", "check" (location ids collected in game), "map" and "story" (for switches and variables that
  close the missable checks), both written in the data storage for the PopTracker pack, which opens the map's tab and shows the missed checks
A location is sent with its game keys ("map:event:page:command") and its kind (item balls and hidden items are resynced from their self switch).
"""
import asyncio
import json
import logging
from collections.abc import Sequence
from typing import Any

import colorama

import Utils
from CommonClient import ClientCommandProcessor, CommonContext, get_base_parser, gui_enabled, handle_url_arg, \
    logger, server_loop
from NetUtils import NetworkItem

from .data import STORY_IDS
from .items import ITEM_ID_TO_QUANTITY, ITEM_ID_TO_SYMBOL
from .locations import LOCATIONS
from .options import StoryGates

MOD_HOST = "127.0.0.1"
DEFAULT_MOD_PORT = 47630
MOD_PROTOCOL_VERSION = 7
MOD_LINE_LIMIT = 1 << 20

mod_logger = logging.getLogger("RebornMod")


class RebornCommandProcessor(ClientCommandProcessor):
    def _cmd_mod(self) -> bool:
        """Show whether the game is connected to this client."""
        ctx = self.ctx
        assert isinstance(ctx, RebornContext)
        self.output("Game connected." if ctx.mod_writer else "Game not connected.")
        return True


class RebornContext(CommonContext):
    game = "Pokemon Reborn"
    items_handling = 0b111  # all items are remote, even our own
    command_processor = RebornCommandProcessor

    def __init__(self, server_address: str | None = None, password: str | None = None) -> None:
        super().__init__(server_address, password)
        self.mod_writer: asyncio.StreamWriter | None = None
        self.scouts_received = False
        self.slot_options: dict[str, Any] = {}
        self.game_map: int | None = None
        self.story: dict[str, bool | int] | None = None  # "S<id>" / "V<id>" => value, see "story" in the mod

    async def server_auth(self, password_requested: bool = False) -> None:
        if password_requested and not self.password:
            await super().server_auth(password_requested)
        await self.get_username()
        await self.send_connect()

    async def connection_closed(self) -> None:
        await super().connection_closed()
        self.scouts_received = False
        self.send_to_mod({"cmd": "ap_status", "connected": False})

    def on_package(self, cmd: str, args: dict[str, Any]) -> None:
        if cmd == "Connected":
            self.scouts_received = False
            slot_data = args["slot_data"]
            self.slot_options = {"story_gates": StoryGates.name_lookup[slot_data.get("story_gates", 0)],
                                 "passwords": slot_data.get("passwords", {})}
            # The mod shows what a location contains as soon as it is collected, so scout everything up front.
            Utils.async_start(self.send_msgs([{
                "cmd": "LocationScouts",
                "locations": sorted(self.server_locations),
                "create_as_hint": 0,
            }]))
            Utils.async_start(self.send_game_map())
            Utils.async_start(self.send_story())
        elif cmd == "LocationInfo":
            self.scouts_received = True
            self.send_init_to_mod()
        elif cmd == "ReceivedItems":
            start = args["index"]
            if start <= len(self.items_received):
                self.send_items_to_mod(start)

    def make_gui(self):
        base = super().make_gui()

        class RebornManager(base):
            base_title = "Pokemon Reborn Client"
            logging_pairs = [("Client", "Archipelago"), ("RebornMod", "Game")]

        return RebornManager

    async def send_game_map(self) -> None:
        """The map the player is on, in the data storage: used by PopTracker to show the current location."""
        await self.set_storage("map", 0, self.game_map)

    async def send_story(self) -> None:
        """The story switches and variables, in the data storage: used by PopTracker to show missed checks."""
        await self.set_storage("story", {}, self.story)

    async def set_storage(self, name: str, default: Any, value: Any) -> None:
        if value is None or self.slot is None:
            return
        await self.send_msgs([{
            "cmd": "Set",
            "key": f"pokemon_reborn_{name}_{self.team}_{self.slot}",
            "default": default,
            "want_reply": False,
            "operations": [{"operation": "replace", "value": value}],
        }])

    # --- mod side ---

    def send_to_mod(self, msg: dict[str, Any]) -> None:
        if self.mod_writer is None:
            return
        self.mod_writer.write((json.dumps(msg) + "\n").encode())

    def send_init_to_mod(self) -> None:
        if self.mod_writer is None or not self.scouts_received:
            return
        locations = []
        for data in LOCATIONS.values():
            item = self.locations_info.get(data.code)
            if item is None:
                continue
            own = item.player == self.slot
            locations.append({
                "id": data.code,
                "keys": data.game_keys,
                "kind": data.kind,
                "item": self.item_names.lookup_in_slot(item.item, item.player),
                "player": self.player_names[item.player],
                "own": own,
                "qty": ITEM_ID_TO_QUANTITY.get(item.item, 1) if own else 1,
            })
        self.send_to_mod({"cmd": "init", "seed": self.server_seed_name, "slot": self.slot, "locations": locations,
                          "options": self.slot_options, "story": STORY_IDS})
        mod_logger.info(f"Sent {len(locations)} locations to the game.")
        self.send_items_to_mod(0)

    def send_items_to_mod(self, start: int) -> None:
        if self.mod_writer is None or not self.scouts_received:
            return
        items = []
        for index, item in enumerate(self.items_received[start:], start):
            assert isinstance(item, NetworkItem)
            symbol = ITEM_ID_TO_SYMBOL.get(item.item)
            if symbol is None:
                logger.warning(f"Unknown item id {item.item} at index {index}, the game will skip it.")
            items.append({
                "index": index,
                "symbol": symbol,
                "qty": ITEM_ID_TO_QUANTITY.get(item.item, 1),
                "name": self.item_names.lookup_in_slot(item.item, self.slot),
                "from": self.player_names[item.player],
                "own_location": item.location if item.player == self.slot and item.location > 0 else None,
            })
        if items:
            self.send_to_mod({"cmd": "items", "items": items})

    async def handle_mod(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        if self.mod_writer is not None:
            mod_logger.info("A new game connection replaces the previous one.")
            self.mod_writer.close()
        self.mod_writer = writer
        mod_logger.info("Game connected.")
        try:
            while not reader.at_eof():
                try:
                    line = await reader.readline()
                except ValueError:  # longer than MOD_LINE_LIMIT: the reader dropped it
                    mod_logger.warning("Message from the game too long, ignored.")
                    continue
                if not line:
                    break
                try:
                    msg = json.loads(line)
                    if not isinstance(msg, dict):
                        raise ValueError("not a JSON object")
                    await self.on_mod_message(msg)
                except Exception:
                    mod_logger.exception(f"Message from the game not handled: {line[:200]!r}")
        except ConnectionError as e:
            mod_logger.warning(f"Game connection error: {e}")
        finally:
            if self.mod_writer is writer:
                self.mod_writer = None
                mod_logger.info("Game disconnected.")
            writer.close()

    async def on_mod_message(self, msg: dict[str, Any]) -> None:
        cmd = msg.get("cmd")
        if cmd == "hello":
            if msg.get("version") != MOD_PROTOCOL_VERSION:
                mod_logger.warning(f"Mod protocol version {msg.get('version')}, "
                                   f"client expects {MOD_PROTOCOL_VERSION}: update the mod.")
            if self.slot is None:
                mod_logger.info("Waiting for the Archipelago server: use /connect.")
            self.send_init_to_mod()
        elif cmd == "map":
            self.game_map = msg.get("id")
            await self.send_game_map()
        elif cmd == "story":
            self.story = msg.get("values")
            await self.send_story()
        elif cmd == "check":
            locations = [location for location in msg.get("locations", []) if location in self.server_locations]
            sent = await self.check_locations(locations)
            for location in sent:
                mod_logger.info(f"Checked {self.location_names.lookup_in_slot(location, self.slot)}.")
        else:
            mod_logger.warning(f"Unknown message from the game: {msg}")


async def main(args) -> None:
    ctx = RebornContext(args.connect, args.password)
    ctx.auth = args.name
    ctx.server_task = asyncio.create_task(server_loop(ctx), name="server loop")
    mod_server = await asyncio.start_server(ctx.handle_mod, MOD_HOST, args.mod_port, limit=MOD_LINE_LIMIT)
    mod_logger.info(f"Waiting for the game on {MOD_HOST}:{args.mod_port}.")

    if gui_enabled:
        ctx.run_gui()
    ctx.run_cli()

    await ctx.exit_event.wait()
    mod_server.close()
    await ctx.shutdown()


def launch_client(*args: Sequence[str]) -> None:
    Utils.init_logging("PokemonRebornClient", exception_logger="Client")
    parser = get_base_parser(description="Pokemon Reborn Client, bridge between the game and Archipelago.")
    parser.add_argument("--name", default=None, help="Slot Name to connect as.")
    parser.add_argument("--mod-port", type=int, default=DEFAULT_MOD_PORT, help="Port the game connects to.")
    parser.add_argument("url", nargs="?", help="Archipelago connection url")
    launch_args = handle_url_arg(parser.parse_args(args), parser)

    colorama.just_fix_windows_console()
    asyncio.run(main(launch_args))
    colorama.deinit()
