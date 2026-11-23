from .bases import RebornTestBase

CUT = ["TMX1 Cut", "Volt Badge"]
ROCK_SMASH = ["TMX7 Rock Smash", "Volt Badge", "Canopy Badge", "Cocoon Badge"]
STRENGTH = ["TMX4 Strength", "Volt Badge", "Canopy Badge", "Cocoon Badge", "Omen Badge", "Blight Badge"]


class TestVanillaBadges(RebornTestBase):
    options = {"badges": "vanilla"}

    def test_leaders_give_badges(self) -> None:
        self.assertNotIn("Volt Badge", [item.name for item in self.multiworld.itempool])
        self.assertIsNone(self.world.get_location("Peridot Gym - Volt Badge from Julia").address)
        self.assertTrue(self.can_reach_region("E2a"))
        self.assertFalse(self.can_reach_region("E2b"))
        self.collect_by_name(["TMX1 Cut"])  # Cut: TMX1 + Julia's badge
        self.assertTrue(self.can_reach_region("E2b"))


class TestLeader(RebornTestBase):
    options = {"badges": "shuffled", "story_gates": "leader"}

    def test_story_needs_field_moves(self) -> None:
        self.assertTrue(self.can_reach_region("E2a"))
        self.assertFalse(self.can_reach_region("E2b"))
        self.collect_by_name(["TMX1 Cut"])
        self.assertFalse(self.can_reach_region("E2b"))  # Cut also needs one badge
        self.collect_by_name(["Volt Badge"])
        self.assertTrue(self.can_reach_region("E5a"))
        self.assertFalse(self.can_reach_region("E5b"))
        self.collect_by_name(ROCK_SMASH)
        self.assertTrue(self.can_reach_region("E6a"))
        self.assertFalse(self.can_reach_region("E6b"))
        self.collect_by_name(["Harbor Key"])
        self.assertTrue(self.can_reach_region("E7"))
        self.assertFalse(self.can_reach_region("E8"))
        self.collect_by_name(STRENGTH)
        self.assertTrue(self.can_reach_region("E11"))
        self.assertBeatable(False)
        keys = self.get_items_by_name("Progressive Crystal Key")
        self.assertEqual(len(keys), 4)
        self.collect(keys[:3])
        self.assertBeatable(False)  # Luna's gate needs the 4 crystals
        self.collect(keys[3:])
        self.assertBeatable(True)

    def test_item_dependencies(self) -> None:
        self.collect_by_name(CUT + ROCK_SMASH)
        self.assertFalse(self.can_reach_location("Slums Playground - Super Repel"))
        self.collect_by_name(["Dull Key"])
        self.assertTrue(self.can_reach_location("Slums Playground - Super Repel"))

    def test_dark_maps_need_flash(self) -> None:
        self.collect_by_name(CUT + ROCK_SMASH)
        self.assertFalse(self.can_reach_location("Beryl Cave B1F - Hidden Link Stone"))
        self.collect_by_name(["TMX8 Flash", "Omen Badge"])
        self.assertTrue(self.can_reach_location("Beryl Cave B1F - Hidden Link Stone"))


class TestBadge(RebornTestBase):
    options = {"badges": "shuffled", "story_gates": "badge"}

    def test_badge_opens_story(self) -> None:
        self.assertFalse(self.can_reach_region("E2a"))
        self.collect_by_name(["Volt Badge"])
        self.assertTrue(self.can_reach_region("E2a"))


class TestBoth(TestBadge):  # same test: "Defeat Julia" is always doable in E1
    options = {"badges": "shuffled", "story_gates": "both"}
