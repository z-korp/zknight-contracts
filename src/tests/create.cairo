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
fn test_create() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, PLAYER, SEED, NAME);

    // [Assert] Game
    let game = datastore.game(PLAYER);
    assert(game.game_id == 0, 'Wrong game id');
    assert(game.seed == SEED, 'Wrong seed');

    // [Assert] Map
    let map = datastore.map(game);
    assert(map.level == 1, 'Wrong map id');
    assert(map.score == 0, 'Wrong score');
    assert(map.name == NAME, 'Wrong name');

    // [Assert] Knight Character
    let knight_char = datastore.character(game, KNIGHT_TYPE);
    assert(knight_char.health == KNIGHT_HEALTH, 'Wrong knight health');
    assert(knight_char.index == 7 + map.size * 2, 'Wrong knight index');

    // [Assert] Barbarian Character
    let barbarian_char = datastore.character(game, BARBARIAN_TYPE);
    assert(barbarian_char.health == MOB_HEALTH, 'Wrong barbarian health');
    assert(barbarian_char.index == 6 + map.size * 2, 'Wrong barbarian index');

    // [Assert] Bowman Character
    let bowman_char = datastore.character(game, BOWMAN_TYPE);
    assert(bowman_char.health == MOB_HEALTH, 'Wrong bowman health');
    assert(bowman_char.index == 2 + map.size * 4, 'Wrong bowman index');
}
