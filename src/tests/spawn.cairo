// Core imports

use debug::PrintTrait;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zknight::constants::{
    SEED, NAME, PLAYER, KNIGHT_HEALTH, MOB_HEALTH, GROUND_TYPE, HOLE_TYPE, KNIGHT_TYPE,
    BARBARIAN_TYPE, BOWMAN_TYPE, WIZARD_TYPE
};
use zknight::datastore::{DataStore, DataStoreTrait};
use zknight::components::game::Game;
use zknight::components::map::{Map, MapTrait};
use zknight::components::tile::{Tile, TileTrait};
use zknight::components::character::{Character};
use zknight::systems::player::IActionsDispatcherTrait;
use zknight::tests::setup::{setup, setup::Systems};


#[test]
#[available_gas(1_000_000_000)]
fn test_spawn() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    let seed = 1000;
    systems.player_actions.create(world, PLAYER, seed, NAME);

    // [Play] Move
    let target_tile = TileTrait::new(7, 2);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);
    // [Play] Move
    let target_tile = TileTrait::new(7, 1);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);
    // [Play] Move
    let target_tile = TileTrait::new(6, 1);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);
    // [Play] Move
    let target_tile = TileTrait::new(6, 0);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);
    // [Play] Move
    let target_tile = TileTrait::new(5, 0);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);
    // [Play] Move
    let target_tile = TileTrait::new(4, 0);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);
    // [Play] Move - TK
    let target_tile = TileTrait::new(4, 1);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);
    // [Play] Attack
    let target_tile = TileTrait::new(4, 2);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);
    // [Play] Attack
    let target_tile = TileTrait::new(4, 2);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);

    // [Assert] Game
    let game = datastore.game(PLAYER);
    assert(game.game_id == 0, 'Wrong game id');
    assert(game.over == false, 'Wrong over status');

    // [Assert] Barbarian Character
    let barbarian_char = datastore.character(game, BARBARIAN_TYPE);
    assert(barbarian_char.health == 0, 'Wrong barbarian health');

    // [Assert] Bowman Character
    let bowman_char = datastore.character(game, BOWMAN_TYPE);
    assert(bowman_char.health == 0, 'Wrong bowman health');

    // [Assert] Wizard Character
    let wizard_char = datastore.character(game, WIZARD_TYPE);
    assert(wizard_char.health == 0, 'Wrong wizard health');

    // [Assert] Map
    let map = datastore.map(game);
    assert(map.level == 2, 'Wrong map level');
    assert(map.spawn == false, 'Wrong spawn');
    assert(map.score == 30, 'Wrong score');

    // [Spawn]
    systems.player_actions.spawn(world, PLAYER);

    // [Assert] Map
    let map = datastore.map(game);
    assert(map.spawn == true, 'Wrong spawn');

    // [Assert] Barbarian Character
    let barbarian_char = datastore.character(game, BARBARIAN_TYPE);
    assert(barbarian_char.health == MOB_HEALTH, 'Wrong barbarian health');
}
