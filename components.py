from worlds.LauncherComponents import Component, Type, components, launch


def run_client(*args: str) -> None:
    from .client import launch_client

    launch(launch_client, name="Pokemon Reborn Client", args=args)


components.append(
    Component(
        "Pokemon Reborn Client",
        func=run_client,
        game_name="Pokemon Reborn",
        component_type=Type.CLIENT,
        supports_uri=True,
    )
)
