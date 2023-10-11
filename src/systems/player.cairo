// Dojo imports

use dojo::world::IWorldDispatcher;

// System trait

#[starknet::interface]
trait IActions<TContractState> {
    fn create(
        self: @TContractState,
        world: IWorldDispatcher,
        player: felt252,
        seed: felt252,
        name: felt252,
    );
    fn play(self: @TContractState, world: IWorldDispatcher, player: felt252, x: u32, y: u32,);
    fn spawn(self: @TContractState, world: IWorldDispatcher, player: felt252,);
}

// System implementation

#[starknet::contract]
mod actions {
    // Core imports

    use array::{ArrayTrait, SpanTrait};
    use poseidon::poseidon_hash_span;

    // Dojo imports

    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Components imports

    use zknight::components::character::{Character, CharacterTrait};
    use zknight::components::game::{Game, GameTrait};
    use zknight::components::map::{Map, MapTrait, Type};
    use zknight::components::tile::{Tile, TileTrait};

    // Entities imports

    use zknight::entities::foe::{Foe, FoeTrait};

    // Internal imports

    use zknight::constants::{
        GROUND_TYPE, KNIGHT_DAMAGE, BARBARIAN_DAMAGE, BOWMAN_DAMAGE, WIZARD_DAMAGE, KNIGHT_HEALTH,
        MOB_HEALTH
    };
    use zknight::datastore::{DataStore, DataStoreTrait};

    // Local imports

    use super::IActions;

    // Errors

    mod errors {}

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl Actions of IActions<ContractState> {
        fn create(
            self: @ContractState,
            world: IWorldDispatcher,
            player: felt252,
            seed: felt252,
            name: felt252,
        ) {
            // [Setup] Datastore
            let mut datastore: DataStore = DataStoreTrait::new(world);

            // [Command] Game entity
            let game_id = world.uuid();
            let mut game = GameTrait::new(player, game_id, seed);
            datastore.set_game(game);

            // [Command] Map entity
            let map = MapTrait::new(game_id, 1, name);
            datastore.set_map(map);

            // [Command] Characters and Tiles
            let raw_types = map.generate(game.seed);
            let mut index = 0;
            let length = raw_types.len();
            loop {
                if index == length {
                    break;
                }

                let raw_type = *raw_types[index];
                let tile_type = map.get_type(raw_type);
                let (x, y) = map.decompose(index);
                let tile = Tile { game_id, level: map.level, x, y, index, _type: raw_type };

                // [Command] Set Tile and Character entities
                match tile_type {
                    Type::Ground(()) => { //
                    },
                    Type::Hole(()) => {
                        // [Command] Set Tile entity
                        datastore.set_tile(tile);
                    },
                    Type::Knight(()) => {
                        // [Command] Set Tile entity
                        datastore.set_tile(tile);
                        // [Command] Set Character entity
                        let knight = Character {
                            game_id: game_id,
                            _type: raw_type,
                            health: KNIGHT_HEALTH,
                            index,
                            hitter: 0,
                            hit: 0
                        };
                        datastore.set_character(knight);
                    },
                    Type::Barbarian(()) => {
                        // [Command] Set Tile entity
                        datastore.set_tile(tile);
                        // [Command] Set Character entity
                        let barbarian = Character {
                            game_id: game_id,
                            _type: raw_type,
                            health: MOB_HEALTH,
                            index,
                            hitter: 0,
                            hit: 0
                        };
                        datastore.set_character(barbarian);
                    },
                    Type::Bowman(()) => {
                        // [Command] Set Tile entity
                        datastore.set_tile(tile);
                        // [Command] Set Character entity
                        let bowman = Character {
                            game_id: game_id,
                            _type: raw_type,
                            health: MOB_HEALTH,
                            index,
                            hitter: 0,
                            hit: 0
                        };
                        datastore.set_character(bowman);
                    },
                    Type::Wizard(()) => {
                        // [Command] Set Tile entity
                        datastore.set_tile(tile);
                        // [Command] Set Character entity
                        let wizard = Character {
                            game_id: game_id,
                            _type: raw_type,
                            health: MOB_HEALTH,
                            index,
                            hitter: 0,
                            hit: 0
                        };
                        datastore.set_character(wizard);
                    },
                };

                index += 1;
            }
        }

        fn play(self: @ContractState, world: IWorldDispatcher, player: felt252, x: u32, y: u32,) {
            // [Setup] Datastore
            let mut datastore: DataStore = DataStoreTrait::new(world);

            // [Command] Game entity
            let mut game: Game = datastore.game(player);

            // [Check] Game is not over
            assert(!game.over, 'Game is over');

            // [Command] Map entity
            let mut map: Map = datastore.map(game);

            // [Command] Knight entity
            let mut knight_char = datastore.character(game, CharacterTrait::get_knight_type());
            knight_char.reset_damage();
            let mut knight_tile = datastore.tile(game, map, knight_char.index);

            // [Command] Barbarian entity
            let mut barbarian_char = datastore
                .character(game, CharacterTrait::get_barbarian_type());
            barbarian_char.reset_damage();
            let mut barbarian_tile = datastore.tile(game, map, barbarian_char.index);

            // [Command] Bowman entity
            let mut bowman_char = datastore.character(game, CharacterTrait::get_bowman_type());
            bowman_char.reset_damage();
            let mut bowman_tile = datastore.tile(game, map, bowman_char.index);

            // [Command] Wizard entity
            let mut wizard_char = datastore.character(game, CharacterTrait::get_wizard_type());
            wizard_char.reset_damage();
            let mut wizard_tile = datastore.tile(game, map, wizard_char.index);

            // [Check] Target position is in range, target is not a hole
            let new_index = map.compose(x, y);
            let mut new_tile = datastore.tile(game, map, new_index);
            assert(knight_tile.is_close(new_tile), 'Target position is not in range');
            assert(!new_tile.is_hole(), 'Target position is a hole');

            // [Effect] Pass if target is knight, Attack if the target is a foe, move otherwise
            if new_tile.is_knight() { // Pass
            } else if new_tile.is_barbarian() && barbarian_char.health > 0 {
                // [Command] Update Character
                barbarian_char.take_damage(knight_char._type, KNIGHT_DAMAGE);
                datastore.set_character(barbarian_char);

                // [Check] Foe death
                if barbarian_char.health == 0 {
                    // [Command] Update Tile
                    new_tile.set_ground_type();
                    datastore.set_tile(new_tile);
                    // [Effect] Update the map score
                    map.increase_score(11);
                };
            } else if new_tile.is_bowman() && bowman_char.health > 0 {
                // [Command] Update Character
                bowman_char.take_damage(knight_char._type, KNIGHT_DAMAGE);
                datastore.set_character(bowman_char);

                // [Check] Foe death
                if bowman_char.health == 0 {
                    // [Command] Update Tile
                    new_tile.set_ground_type();
                    datastore.set_tile(new_tile);
                    // [Effect] Update the map score
                    map.increase_score(11);
                };
            } else if new_tile.is_wizard() && wizard_char.health > 0 {
                // [Command] Update Character
                wizard_char.take_damage(knight_char._type, KNIGHT_DAMAGE);
                datastore.set_character(wizard_char);

                // [Check] Foe death
                if wizard_char.health == 0 {
                    // [Command] Update Tile
                    new_tile.set_ground_type();
                    datastore.set_tile(new_tile);
                    // [Effect] Update the map score
                    map.increase_score(11);
                };
            } else {
                // [Effect] Move Knight, update the knight position in storage and hashmap
                let tile = Tile {
                    game_id: game.game_id,
                    level: map.level,
                    index: new_index,
                    _type: knight_char._type,
                    x,
                    y
                };
                // [Command] Update previous tile
                knight_tile.set_ground_type();
                datastore.set_tile(knight_tile);
                // [Command] Update new tile
                new_tile.set_knight_type();
                datastore.set_tile(new_tile);
                knight_tile = new_tile; // Update knight tile for the next instructions
                // [Command] Update Character
                knight_char.set_index(new_index);
                datastore.set_character(knight_char);
            }

            // [Effect] Barbarian: Attack if possible, move otherwise
            let barbarian: Foe = FoeTrait::new(barbarian_char.health, barbarian_char._type);
            if barbarian.can_attack(barbarian_tile, knight_tile) && knight_char.health > 0 {
                // [Effect] Hit each character in the line of sight
                let hits = barbarian.get_hits(barbarian_tile, knight_tile, map.size);
                let len = hits.len();
                let mut i = 0;
                loop {
                    if i == len {
                        break;
                    }
                    let hit_index = *hits.at(i);
                    let mut hit_tile = datastore.tile(game, map, hit_index);
                    if hit_tile.is_knight() {
                        // [Command] Update Character
                        knight_char.take_damage(barbarian_char._type, BARBARIAN_DAMAGE);
                        datastore.set_character(knight_char);
                    } else if hit_tile.is_bowman() && bowman_char.health > 0 {
                        // [Command] Update Character
                        bowman_char.take_damage(barbarian_char._type, BARBARIAN_DAMAGE);
                        datastore.set_character(bowman_char);
                        // [Check] Foe death
                        if bowman_char.health == 0 {
                            // [Command] Update Tile
                            hit_tile.set_ground_type();
                            datastore.set_tile(hit_tile);
                            // [Effect] Update the map score
                            map.increase_score(11);
                        };
                    } else if hit_tile.is_wizard() && wizard_char.health > 0 {
                        // [Command] Update Character
                        wizard_char.take_damage(barbarian_char._type, BARBARIAN_DAMAGE);
                        datastore.set_character(wizard_char);
                        // [Check] Foe death
                        if wizard_char.health == 0 {
                            // [Command] Update Tile
                            hit_tile.set_ground_type();
                            datastore.set_tile(hit_tile);
                            // [Effect] Update the map score
                            map.increase_score(11);
                        };
                    };
                    i += 1;
                };
            } else if barbarian.can_move() && knight_char.health > 0 {
                // [Effect] Move Barbarian, update the barbarian position in storage and hashmap
                let mut neighbors = datastore.ground_neighbors(game, map, barbarian_tile);
                let new_index = barbarian
                    .next(barbarian_tile, knight_tile, map.size, ref neighbors);
                let mut new_tile = datastore.tile(game, map, new_index);
                // [Command] Update previous tile
                barbarian_tile.set_ground_type();
                datastore.set_tile(barbarian_tile);
                // [Command] Update new tile
                new_tile.set_barbarian_type();
                datastore.set_tile(new_tile);
                barbarian_tile = new_tile; // Update tile for the next instructions
                // [Command] Update Character
                barbarian_char.set_index(new_index);
                datastore.set_character(barbarian_char);
            }

            // [Effect] Bowman: Attack if possible, move otherwise
            let bowman: Foe = FoeTrait::new(bowman_char.health, bowman_char._type);
            if bowman.can_attack(bowman_tile, knight_tile) && knight_char.health > 0 {
                // [Effect] Hit each character in the line of sight, but stop at first hit
                let hits = bowman.get_hits(bowman_tile, knight_tile, map.size);
                let len = hits.len();
                let mut i = 0;
                loop {
                    if i == len {
                        break;
                    }
                    let hit_index = *hits.at(i);
                    let mut hit_tile = datastore.tile(game, map, hit_index);
                    if hit_tile.is_knight() {
                        // [Command] Update Character
                        knight_char.take_damage(bowman_char._type, BOWMAN_DAMAGE);
                        datastore.set_character(knight_char);
                        // [Break] Hits stop at the first character
                        break;
                    } else if hit_tile.is_barbarian() && barbarian_char.health > 0 {
                        // [Command] Update Character
                        barbarian_char.take_damage(bowman_char._type, BOWMAN_DAMAGE);
                        datastore.set_character(barbarian_char);
                        // [Check] Foe death
                        if barbarian_char.health == 0 {
                            // [Command] Update Tile
                            hit_tile.set_ground_type();
                            datastore.set_tile(hit_tile);
                            // [Effect] Update the map score
                            map.increase_score(11);
                        };
                        // [Break] Hits stop at the first character
                        break;
                    } else if hit_tile.is_wizard() && wizard_char.health > 0 {
                        // [Command] Update Character
                        wizard_char.take_damage(bowman_char._type, BOWMAN_DAMAGE);
                        datastore.set_character(wizard_char);
                        // [Check] Foe death
                        if wizard_char.health == 0 {
                            // [Command] Update Tile
                            hit_tile.set_ground_type();
                            datastore.set_tile(hit_tile);
                            // [Effect] Update the map score
                            map.increase_score(11);
                        };
                        // [Break] Hits stop at the first character
                        break;
                    };
                    i += 1;
                };
            } else if bowman.can_move() && knight_char.health > 0 {
                // [Effect] Move Bowman, update the bowman position in storage and hashmap
                let mut neighbors = datastore.ground_neighbors(game, map, bowman_tile);
                let new_index = bowman.next(bowman_tile, knight_tile, map.size, ref neighbors);
                let mut new_tile = datastore.tile(game, map, new_index);
                // [Command] Update previous tile
                bowman_tile.set_ground_type();
                datastore.set_tile(bowman_tile);
                // [Command] Update new tile
                new_tile.set_bowman_type();
                datastore.set_tile(new_tile);
                bowman_tile = new_tile; // Update tile for the next instructions
                // [Command] Update Character
                bowman_char.set_index(new_index);
                datastore.set_character(bowman_char);
            }

            // [Effect] Wizard: Attack if possible, move otherwise
            let wizard: Foe = FoeTrait::new(wizard_char.health, wizard_char._type);
            if wizard.can_attack(wizard_tile, knight_tile) && knight_char.health > 0 {
                // [Effect] Hit each character in the line of sight
                let hits = wizard.get_hits(wizard_tile, knight_tile, map.size);
                let len = hits.len();
                let mut i = 0;
                loop {
                    if i == len {
                        break;
                    }
                    let hit_index = *hits.at(i);
                    let mut hit_tile = datastore.tile(game, map, hit_index);
                    if hit_tile.is_knight() {
                        // [Command] Update Character
                        knight_char.take_damage(wizard_char._type, WIZARD_DAMAGE);
                        datastore.set_character(knight_char);
                    } else if hit_tile.is_barbarian() && barbarian_char.health > 0 {
                        // [Command] Update Character
                        barbarian_char.take_damage(wizard_char._type, WIZARD_DAMAGE);
                        datastore.set_character(barbarian_char);
                        // [Check] Foe death
                        if barbarian_char.health == 0 {
                            // [Command] Update Tile
                            hit_tile.set_ground_type();
                            datastore.set_tile(hit_tile);
                            // [Effect] Update the map score
                            map.increase_score(11);
                        };
                    } else if hit_tile.is_bowman() && bowman_char.health > 0 {
                        // [Command] Update Character
                        bowman_char.take_damage(wizard_char._type, WIZARD_DAMAGE);
                        datastore.set_character(bowman_char);
                        // [Check] Foe death
                        if bowman_char.health == 0 {
                            // [Command] Update Tile
                            hit_tile.set_ground_type();
                            datastore.set_tile(hit_tile);
                            // [Effect] Update the map score
                            map.increase_score(11);
                        };
                    };
                    i += 1;
                };
            } else if wizard.can_move() && knight_char.health > 0 {
                // [Effect] Move Wizard, update the wizard position in storage and hashmap
                let mut neighbors = datastore.ground_neighbors(game, map, wizard_tile);
                let new_index = wizard.next(wizard_tile, knight_tile, map.size, ref neighbors);
                let mut new_tile = datastore.tile(game, map, new_index);
                // [Command] Update previous tile
                wizard_tile.set_ground_type();
                datastore.set_tile(wizard_tile);
                // [Command] Update new tile
                new_tile.set_wizard_type();
                datastore.set_tile(new_tile);
                wizard_tile = new_tile; // Update tile for the next instructions
                // [Command] Update Character
                wizard_char.set_index(new_index);
                datastore.set_character(wizard_char);
            }

            // [Effect] Score and game evalutation
            map.decrease_score(1);
            if knight_char.health == 0 {
                // [Command] Update Game
                game.set_over(true);
                datastore.set_game(game);
                // [Command] Update Map
                map.set_over(true);
                datastore.set_map(map);
            } else if barbarian_char.health == 0
                && bowman_char.health == 0
                && wizard_char.health == 0 {
                // [Command] Update Map
                map.increase_level();
                map.set_spawn(false);
                datastore.set_map(map);
            } else {
                // [Command] Update Map
                datastore.set_map(map);
            }
        }

        fn spawn(self: @ContractState, world: IWorldDispatcher, player: felt252,) {
            // [Setup] Datastore
            let mut datastore: DataStore = DataStoreTrait::new(world);

            // [Command] Game entity
            let game = datastore.game(player);

            // [Check] Map must not be spawned
            let mut map = datastore.map(game);
            assert(!map.spawn, 'Map must not be spawned');

            // [Command] Map entity
            map.spawn = true;
            datastore.set_map(map);

            // [Command] Characters and Tiles
            let seed = poseidon_hash_span(array![game.seed, map.level.into()].span()).into();
            let raw_types = map.generate(seed);
            let mut index = 0;
            let length = raw_types.len();
            loop {
                if index == length {
                    break;
                }

                let raw_type = *raw_types[index];
                let tile_type = map.get_type(raw_type);
                let (x, y) = map.decompose(index);
                let tile = Tile {
                    game_id: game.game_id, level: map.level, x, y, index, _type: raw_type
                };

                // [Command] Set Tile and Character entities
                match tile_type {
                    Type::Ground(()) => { //
                    },
                    Type::Hole(()) => {
                        // [Command] Set Tile entity
                        datastore.set_tile(tile);
                    },
                    Type::Knight(()) => {
                        // [Command] Set Tile entity
                        datastore.set_tile(tile);
                        // [Command] Update Character entity
                        let mut character = datastore
                            .character(game, CharacterTrait::get_knight_type());
                        character.index = index;
                        character.hitter = 0;
                        character.hit = 0;
                        datastore.set_character(character);
                    },
                    Type::Barbarian(()) => {
                        // [Command] Set Tile entity
                        datastore.set_tile(tile);
                        // [Command] Update Character entity
                        let mut character = datastore
                            .character(game, CharacterTrait::get_barbarian_type());
                        character.health = MOB_HEALTH;
                        character.index = index;
                        character.hitter = 0;
                        character.hit = 0;
                        datastore.set_character(character);
                    },
                    Type::Bowman(()) => {
                        // [Command] Set Tile entity
                        datastore.set_tile(tile);
                        // [Command] Update Character entity
                        let mut character = datastore
                            .character(game, CharacterTrait::get_bowman_type());
                        character.health = MOB_HEALTH;
                        character.index = index;
                        character.hitter = 0;
                        character.hit = 0;
                        datastore.set_character(character);
                    },
                    Type::Wizard(()) => {
                        // [Command] Set Tile entity
                        datastore.set_tile(tile);
                        // [Command] Update Character entity
                        let mut character = datastore
                            .character(game, CharacterTrait::get_wizard_type());
                        character.health = MOB_HEALTH;
                        character.index = index;
                        character.hitter = 0;
                        character.hit = 0;
                        datastore.set_character(character);
                    },
                };

                index += 1;
            }
        }
    }

    #[generate_trait]
    impl Internal of InternalTrait {}
}
