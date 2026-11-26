from unittest import TestCase

from ..options import ExpMultiplier
from .bases import RebornTestBase

EVERSTONE = "Obsidia Slums B1F - Everstone"


class TestExpMultiplier(TestCase):
    def test_values(self) -> None:
        self.assertEqual(ExpMultiplier.from_any(150).percent, 150)
        self.assertEqual(ExpMultiplier.from_any("-200").percent, -200)
        self.assertEqual(ExpMultiplier.from_any(0).percent, 0)
        self.assertIsNone(ExpMultiplier.from_any(ExpMultiplier.default).percent)
        self.assertIn(ExpMultiplier.from_any("random-range-50-300").value, range(50, 301))

    def test_invalid(self) -> None:
        for value in [1001, -1001, "fast"]:
            with self.assertRaises(Exception):
                ExpMultiplier.from_any(value)


class TestDefaultPasswords(RebornTestBase):
    def test_all_off(self) -> None:
        passwords = self.world.fill_slot_data()["passwords"]
        self.assertEqual(passwords, {"easyhms": False, "hardcap": False, "pinata": False, "freerainbow": False,
                                     "storymode": False, "eeveepls": False, "vulpixpls": False, "freestarter": False,
                                     "exppercent": None})

    # pool size = locations with the default options: core test_item_count_equal_locations
    def test_data_chips_in_pool(self) -> None:
        self.assertTrue(self.get_items_by_name("Data Chip"))

    def test_no_everstone_with_vanilla_starter(self) -> None:
        self.assertNotIn(EVERSTONE, self.location_names())


class TestPasswords(RebornTestBase):
    options = {"easy_hms": True, "exp_multiplier": 250,"pinata": True, "starter": "vulpix", "free_rainbow": True,
               "story_mode": True}

    def test_passwords(self) -> None:
        passwords = self.world.fill_slot_data()["passwords"]
        self.assertEqual(passwords, {"easyhms": True, "hardcap": False, "pinata": True, "freerainbow": True,
                                     "storymode": True, "eeveepls": False, "vulpixpls": True, "freestarter": False,
                                     "exppercent": 250})

    # V26 Starter choice >= 100 with a password starter: the Everstone ball of Obsidia Slums B1F is there
    def test_everstone_with_password_starter(self) -> None:
        self.assertIn(EVERSTONE, self.location_names())
        self.assert_pool_fills_locations()


SUSPENSION = "Big Top - Suspension Badge from Ciel"


class TestGoalLuna(RebornTestBase):
    options = {"goal": "defeat_luna"}

    # the checks after Luna stay in the logic (user's choice 2026-11-24); Surf is only needed after Samson
    def test_checks_after_luna_kept(self) -> None:
        self.assertIn(SUSPENSION, self.location_names())
        self.collect_all_but(["TMX3 Surf", "Defeat Luna", "Defeat Ciel"])  # events: from the logic only
        self.assertBeatable(True)


class TestGoalCiel(RebornTestBase):
    options = {"goal": "defeat_ciel"}

    def test_needs_ciel(self) -> None:
        self.collect_all_but(["TMX5 Waterfall", "Defeat Terra", "Defeat Ciel"])  # events: from the logic only
        self.assertBeatable(False)
        self.collect_by_name(["TMX5 Waterfall"])
        self.assertBeatable(True)
