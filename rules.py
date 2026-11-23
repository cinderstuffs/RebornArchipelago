from collections.abc import Callable
from typing import Any

from BaseClasses import CollectionState

from .data import ROADBLOCKS
from .items import BADGES

Rule = Callable[[CollectionState], bool]


def compile_rule(tree: dict[str, Any] | None, player: int, options: dict[str, str]) -> Rule:
    if tree is None:
        return lambda state: True
    if "all" in tree:
        rules = [compile_rule(x, player, options) for x in tree["all"]]
        return lambda state: all(rule(state) for rule in rules)
    if "any" in tree:
        rules = [compile_rule(x, player, options) for x in tree["any"]]
        return lambda state: any(rule(state) for rule in rules)
    if "item" in tree or "event" in tree:
        name, count = tree.get("item", tree.get("event")), tree.get("count", 1)
        return lambda state: state.has(name, player, count)
    if "badges" in tree:
        count = tree["badges"]
        return lambda state: state.has_from_list_unique(BADGES, player, count)
    if "field_move" in tree:
        return compile_rule(ROADBLOCKS["field_moves"][tree["field_move"]]["rule"], player, options)
    if "option" in tree:
        return compile_rule(tree["cases"][options[tree["option"]]], player, options)
    if "soft" in tree:
        return compile_rule(tree["soft"], player, options)
    raise ValueError(f"unknown rule {tree}")
