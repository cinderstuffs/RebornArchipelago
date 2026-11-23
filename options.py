from dataclasses import dataclass

from Options import Choice, PerGameCommonOptions, Range, Toggle

# Logic options

class Badges(Choice):
    """
    vanilla: each Gym Leader gives their own badge.
    shuffled: badges are found anywhere in the multiworld.
    """

    display_name = "Badges"
    option_vanilla = 0
    option_shuffled = 1
    default = 0


class StoryGates(Choice):
    """
    What unlocks the story. This mainly changes things if badges are shuffled.

    leader: beating the Gym Leader unlocks the story. No need for badges, except for level caps. Basically same as vanilla.
    badge: if selected, the story moves on by itself once you reach the Gym Leader battle if you've already
    acquired it (through badge shuffling). The battle is still available later for checks. If you don't own it, the story is
    blocked until you do, even if you beat the Gym Leader. Read the detailed guide for more information.
    both: you need to both beat the Gym Leader and own their badge, even if badges are shuffled. Story is blocked until both are completed.
    """

    display_name = "Story Gates"
    option_leader = 0
    option_badge = 1
    option_both = 2
    default = 0


# QoL options

class EasyHMs(Toggle):
    """
    Password "easyhms": field moves no longer need a Pokémon that knows the move, only the TMX item.
    """

    display_name = "Easy HMs"


class ExpMultiplier(Range):
    """
    Password "exppercent": percentage of the experience gained. 100 = vanilla, 150 = 50% more experience,
    0 = no experience, negative values make Pokémon lose experience.
    """

    display_name = "Experience Multiplier"
    range_start = -1000
    range_end = 1000
    default = 100

    @property
    def percent(self) -> int | None:
        return None if self.value == 100 else self.value


class HardLevelCap(Toggle):
    """
    Password "hardcap": Pokémon can't gain experience above the level cap.
    """

    display_name = "Hard Level Cap"


class Pinata(Toggle):
    """
    Password "pinata": grind trainers skip battle and immediately give Exp. Candies.
    """

    display_name = "Pinata"


class Starter(Choice):
    """
    Starter passwords.

    vanilla: the usual starters.
    eevee: password "eeveepls", Eevee is offered as a starter.
    vulpix: password "vulpixpls", Vulpix and Alolan Vulpix are offered as starters.
    free_starter: password "freestarter", choose any Pokémon as a starter.
    """

    display_name = "Starter"
    option_vanilla = 0
    option_eevee = 1
    option_vulpix = 2
    option_free_starter = 3
    default = 0


class FreeRainbow(Toggle):
    """
    Password "freerainbow". Made for testing purposes only and isn't meant to be used in a real run.
    """

    display_name = "Free Rainbow"


class StoryMode(Toggle):
    """
    Password "storymode". Made for testing purposes only and isn't meant to be used in a real run.
    """

    display_name = "Story Mode"


@dataclass
class RebornOptions(PerGameCommonOptions):
    badges: Badges
    story_gates: StoryGates
    easy_hms: EasyHMs
    exp_multiplier: ExpMultiplier
    hard_level_cap: HardLevelCap
    pinata: Pinata
    starter: Starter
    free_rainbow: FreeRainbow
    story_mode: StoryMode
