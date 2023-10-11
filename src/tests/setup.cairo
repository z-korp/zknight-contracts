mod setup {
    // Dojo imports

    use dojo::world::{IWorldDispatcherTrait, IWorldDispatcher};
    use dojo::test_utils::{spawn_test_world, deploy_contract};

    // Internal imports

    use zknight::components::game::{game, Game};
    use zknight::components::map::{map, Map};
    use zknight::components::tile::{tile, Tile};
    use zknight::components::character::{character, Character};
    use zknight::systems::player::{actions as player_actions, IActionsDispatcher};

    #[derive(Drop)]
    struct Systems {
        player_actions: IActionsDispatcher,
    }

    fn spawn_game() -> (IWorldDispatcher, Systems) {
        // [Setup] Components
        let mut components = ArrayTrait::new();
        components.append(game::TEST_CLASS_HASH);
        components.append(map::TEST_CLASS_HASH);
        components.append(character::TEST_CLASS_HASH);
        let world = spawn_test_world(components);

        // [Setup] Systems
        let player_actions_address = deploy_contract(
            player_actions::TEST_CLASS_HASH, array![].span()
        );
        let systems = Systems {
            player_actions: IActionsDispatcher { contract_address: player_actions_address },
        };

        // [Return]
        (world, systems)
    }
}
