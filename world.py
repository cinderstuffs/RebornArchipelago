from collections.abc import Mapping
from typing import Any

from BaseClasses import LocationProgressType, Region, Tutorial
from Options import OptionGroup
from worlds.AutoWorld import WebWorld, World

from .data import ROADBLOCKS
from .items import FILLER_ITEMS, ITEM_NAME_TO_ID, ITEMS, RebornItem
from .locations import EVENTS, LOCATION_NAME_TO_ID, LOCATIONS, LocationData, RebornLocation
from .options import Badges, EasyHMs, ExpMultiplier, FreeRainbow, HardLevelCap, Pinata, RebornOptions, Starter, \
    StoryGates, StoryMode
from .rules import compile_rule

GOAL_EVENT = ROADBLOCKS["goal"]


class RebornWebWorld(WebWorld):
    game = "Pokemon Reborn"
    setup_en = Tutorial(
        "Multiworld Setup Guide",
        "A guide to setting up Pokemon Reborn for MultiWorld.",
        "English",
        "setup_en.md",
        "setup/en",
        ["cinderstuffs"],
    )
    tutorials = [setup_en]
    option_groups = [
        OptionGroup("Logic Options", [Badges, StoryGates]),
        OptionGroup("QoL Options", [EasyHMs, ExpMultiplier, HardLevelCap, Pinata, Starter, FreeRainbow, StoryMode]),
    ]


class RebornWorld(World):
    """
    Pokémon Reborn is a Pokémon fan game, made by Ame and her team.
    """

    game = "Pokemon Reborn"
    web = RebornWebWorld()
    options_dataclass = RebornOptions
    options: RebornOptions
    item_name_to_id = ITEM_NAME_TO_ID
    location_name_to_id = LOCATION_NAME_TO_ID

    def option_keys(self) -> dict[str, str]:
        return {"story_gates": self.options.story_gates.current_key}

    def create_regions(self) -> None:
        regions = {"Menu": Region("Menu", self.player, self.multiworld)}
        for data in ROADBLOCKS["regions"]:
            regions[data["name"]] = Region(data["name"], self.player, self.multiworld)
        self.multiworld.regions += regions.values()
        options = self.option_keys()
        for data in ROADBLOCKS["regions"]:
            regions[data["entrance_from"]].connect(regions[data["name"]], f"To {data['name']}",
                                                   compile_rule(data["rule"], self.player, options))

        for name, data in LOCATIONS.items():
            if not self.created(data):
                continue
            region = regions[data.region]
            rule = compile_rule(data.rule, self.player, options)
            if self.vanilla_badge(data.kind):  # the leader gives their badge: an event, not a check
                region.add_event(name, data.vanilla_item, rule, RebornLocation, RebornItem)
                continue
            location = RebornLocation(self.player, name, data.code, region)
            location.access_rule = rule
            if data.filler_only:
                location.progress_type = LocationProgressType.EXCLUDED
            region.locations.append(location)

        for name, (region_name, rule) in EVENTS.items():
            regions[region_name].add_event(name, None, compile_rule(rule, self.player, options), RebornLocation,
                                           RebornItem)
        self.multiworld.completion_condition[self.player] = lambda state: state.has(GOAL_EVENT, self.player)

    def vanilla_badge(self, kind: str) -> bool:
        return kind == "badge" and self.options.badges == Badges.option_vanilla

    def created(self, data: LocationData) -> bool:
        return all(getattr(self.options, option).current_key in values for option, values in data.options.items())

    def create_items(self) -> None:
        for location in self.get_locations():  # one vanilla item per AP check created
            if location.address is not None:
                self.multiworld.itempool.append(self.create_item(LOCATIONS[location.name].vanilla_item))

    def create_item(self, name: str) -> RebornItem:
        data = ITEMS[name]
        return RebornItem(name, data.classification, data.code, self.player)

    def get_filler_item_name(self) -> str:
        return self.random.choice(FILLER_ITEMS)

    def passwords(self) -> dict[str, bool | int | None]:
        starter = self.options.starter
        return {
            "easyhms": bool(self.options.easy_hms),
            "hardcap": bool(self.options.hard_level_cap),
            "pinata": bool(self.options.pinata),
            "freerainbow": bool(self.options.free_rainbow),
            "storymode": bool(self.options.story_mode),
            "eeveepls": starter == Starter.option_eevee,
            "vulpixpls": starter == Starter.option_vulpix,
            "freestarter": starter == Starter.option_free_starter,
            "exppercent": self.options.exp_multiplier.percent,
        }

    def fill_slot_data(self) -> Mapping[str, Any]:
        return {**self.options.as_dict("badges", "story_gates", "starter"), "passwords": self.passwords()}
