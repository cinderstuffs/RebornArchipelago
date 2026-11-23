from typing import NamedTuple

from BaseClasses import Item, ItemClassification

from .data import ITEM_TABLE


class RebornItem(Item):
    game = "Pokemon Reborn"


class ItemData(NamedTuple):
    code: int
    symbol: str
    classification: ItemClassification
    quantity: int


ITEMS: dict[str, ItemData] = {
    name: ItemData(data["id"], data["symbol"], ItemClassification[data["classification"]], data.get("quantity", 1))
    for name, data in ITEM_TABLE.items()
}
BADGES = [name for name, data in ITEMS.items() if data.symbol.startswith("BADGE")]
FILLER_ITEMS = [name for name, data in ITEMS.items() if data.classification == ItemClassification.filler]

ITEM_NAME_TO_ID = {name: data.code for name, data in ITEMS.items()}
ITEM_ID_TO_SYMBOL = {data.code: data.symbol for data in ITEMS.values()}
ITEM_ID_TO_QUANTITY = {data.code: data.quantity for data in ITEMS.values()}
