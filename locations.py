from typing import Any, NamedTuple

from BaseClasses import Location

from .data import CHECKS, ROADBLOCKS


class RebornLocation(Location):
    game = "Pokemon Reborn"


class LocationData(NamedTuple):
    code: int
    region: str
    rule: dict[str, Any] | None
    vanilla_item: str
    game_keys: list[str]
    kind: str  # hidden, item_ball, gift, battle_reward, badge
    filler_only: bool  # for missable items
    options: dict[str, list[str]]  # for items created if certains options are set, if {} = always created


LOCATIONS: dict[str, LocationData] = {
    check["name"]: LocationData(check["id"], check["region"], check["rule"], check["vanilla_item"],
                                check["game_keys"], check["kind"], bool(check.get("filler_only")),
                                check.get("options", {}))
    for check in CHECKS if check["status"] == "in_logic"
}
EVENTS: dict[str, tuple[str, dict[str, Any] | None]] = {
    event["name"]: (event["region"], event.get("rule")) for event in ROADBLOCKS["events"]
}

LOCATION_NAME_TO_ID = {name: data.code for name, data in LOCATIONS.items()}
