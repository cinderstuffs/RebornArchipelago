from test.bases import WorldTestBase

from ..world import RebornWorld


class RebornTestBase(WorldTestBase):
    game = "Pokemon Reborn"
    world: RebornWorld

    # Story events (Defeat Julia...) are locked items: collect the reachable ones, as the generator does (collect()
    # sweeps again after each item)
    def setUp(self) -> None:
        super().setUp()
        self.multiworld.state.sweep_for_advancements()

    def location_names(self) -> set[str]:
        return {location.name for location in self.world.get_locations()}

    def assert_pool_fills_locations(self) -> None:
        self.assertEqual(len(self.multiworld.itempool), len(self.multiworld.get_unfilled_locations(self.player)))
