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
fn test_play_attack_move() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, PLAYER, SEED, NAME);
    let game = datastore.game(PLAYER);
    let map = datastore.map(game);

    // [Play] Attack
    let target_tile = TileTrait::new(6, 2);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);

    // [Assert] Barbarian Character
    let barbarian_char = datastore.character(game, BARBARIAN_TYPE);
    assert(barbarian_char.health == 0, 'Wrong barbarian health');

    // [Assert] Barbarian Tile doesn't exist anymore
    let barbarian_tile = datastore.tile(game, map, barbarian_char.index);
    assert(barbarian_tile._type == GROUND_TYPE, 'Wrong barbarian type');

    // [Assert] Bowman Character
    let bowman_char = datastore.character(game, BOWMAN_TYPE);
    assert(bowman_char.health == MOB_HEALTH, 'Wrong bowman health');
    assert(bowman_char.index == 2 + map.size * 3, 'Wrong bowman index');

    // [Play] Move
    let target_tile = TileTrait::new(6, 2);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);

    // [Assert] Knight Character
    let knight_char = datastore.character(game, KNIGHT_TYPE);
    assert(knight_char.health == KNIGHT_HEALTH, 'Wrong knight health');
    assert(knight_char.index == 6 + map.size * 2, 'Wrong knight index');

    // [Assert] Knight Tile
    let knight_tile = datastore.tile(game, map, knight_char.index);
    assert(knight_tile._type == KNIGHT_TYPE, 'Wrong new knight type');
    assert(knight_tile.x == target_tile.x, 'Wrong new knight x');
    assert(knight_tile.y == target_tile.y, 'Wrong new knight y');

    // [Assert] Bowman Character
    let bowman_char = datastore.character(game, BOWMAN_TYPE);
    assert(bowman_char.health == MOB_HEALTH, 'Wrong bowman health');
    assert(bowman_char.index == 2 + map.size * 2, 'Wrong bowman index');

    // [Assert] Bowman Tile
    let bowman_tile = datastore.tile(game, map, bowman_char.index);
    assert(bowman_tile._type == BOWMAN_TYPE, 'Wrong bowman type');
    assert(bowman_tile.x == 2, 'Wrong bowman x');
    assert(bowman_tile.y == 2, 'Wrong bowman y');

    // [Assert] Game
    let map = datastore.map(game);
    assert(map.score == 9, 'Wrong score');
}


#[test]
#[available_gas(1_000_000_000)]
fn test_play_pass() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, PLAYER, SEED, NAME);
    let game = datastore.game(PLAYER);
    let map = datastore.map(game);

    // [Assert] Knight Character
    let knight_char = datastore.character(game, KNIGHT_TYPE);
    assert(knight_char.health == KNIGHT_HEALTH, 'Wrong knight health');
    assert(knight_char.index == 7 + map.size * 2, 'Wrong knight index');

    // [Play] Pass
    let target_tile = TileTrait::new(7, 2);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);

    // [Assert] Knight Character
    let knight_char = datastore.character(game, KNIGHT_TYPE);
    assert(knight_char.health == KNIGHT_HEALTH - 1, 'Wrong knight health');
    assert(knight_char.index == 7 + map.size * 2, 'Wrong knight index');
}


#[test]
#[available_gas(1_000_000_000)]
fn test_play_team_kill() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    let seed = 1000;
    systems.player_actions.create(world, PLAYER, seed, NAME);

    // [Play] Move
    let target_tile = TileTrait::new(6, 3);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);
    // [Play] Move
    let target_tile = TileTrait::new(5, 3);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);
    // [Play] Move
    let target_tile = TileTrait::new(5, 4);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);
    // [Play] Move
    let target_tile = TileTrait::new(5, 5);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);
    // [Play] Pass
    let target_tile = TileTrait::new(5, 5);
    systems.player_actions.play(world, PLAYER, target_tile.x, target_tile.y);

    // [Assert] Barbarian Character
    let game = datastore.game(PLAYER);
    let barbarian_char = datastore.character(game, BARBARIAN_TYPE);
    assert(barbarian_char.health == 0, 'Wrong barbarian health');

    // [Assert] Map
    let map = datastore.map(game);
    assert(map.score == 10, 'Wrong score');
}
