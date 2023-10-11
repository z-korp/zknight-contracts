//! DataStore struct and component management methods.

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Components imports

use zknight::components::character::{Character, CharacterTrait};
use zknight::components::game::{Game, GameTrait};
use zknight::components::map::{Map, MapTrait};
use zknight::components::tile::{Tile, TileTrait};

// Internal imports

use zknight::constants;

/// DataStore struct.
#[derive(Drop)]
struct DataStore {
    world: IWorldDispatcher
}

/// Trait to initialize, get and set components from the DataStore.
trait DataStoreTrait {
    fn new(world: IWorldDispatcher) -> DataStore;
    fn game(ref self: DataStore, player: felt252) -> Game;
    fn map(ref self: DataStore, game: Game) -> Map;
    fn character(ref self: DataStore, game: Game, _type: u8) -> Character;
    fn tile(ref self: DataStore, game: Game, map: Map, index: u32) -> Tile;
    fn ground_neighbors(ref self: DataStore, game: Game, map: Map, tile: Tile) -> Span<Tile>;
    fn set_game(ref self: DataStore, game: Game);
    fn set_map(ref self: DataStore, map: Map);
    fn set_character(ref self: DataStore, character: Character);
    fn set_tile(ref self: DataStore, tile: Tile);
}

/// Implementation of the `DataStoreTrait` trait for the `DataStore` struct.
impl DataStoreImpl of DataStoreTrait {
    fn new(world: IWorldDispatcher) -> DataStore {
        DataStore { world: world }
    }

    fn game(ref self: DataStore, player: felt252) -> Game {
        get!(self.world, player, (Game))
    }

    fn map(ref self: DataStore, game: Game) -> Map {
        get!(self.world, game.game_id, (Map))
    }

    fn character(ref self: DataStore, game: Game, _type: u8) -> Character {
        let character_key = (game.game_id, _type);
        get!(self.world, character_key.into(), (Character))
    }

    fn tile(ref self: DataStore, game: Game, map: Map, index: u32) -> Tile {
        let tile_key = (game.game_id, map.level, index);
        let mut tile: Tile = get!(self.world, tile_key.into(), (Tile));
        // Could be unknown entity if GROUND_TYPE, then set coordinates
        if tile._type == constants::GROUND_TYPE {
            let (tile_x, tile_y) = map.decompose(index);
            tile.x = tile_x;
            tile.y = tile_y;
        };
        tile
    }

    fn ground_neighbors(ref self: DataStore, game: Game, map: Map, tile: Tile) -> Span<Tile> {
        let mut neighbors: Array<Tile> = ArrayTrait::new();

        // [Compute] Left neighbor
        if tile.x > 0 {
            let index = map.compose(tile.x - 1, tile.y);
            let new_tile = self.tile(game, map, index);
            if new_tile.is_ground() {
                neighbors.append(new_tile);
            };
        };

        // [Compute] Right neighbor
        if tile.x < map.size - 1 {
            let index = map.compose(tile.x + 1, tile.y);
            let new_tile = self.tile(game, map, index);
            if new_tile.is_ground() {
                neighbors.append(new_tile);
            };
        };

        // [Compute] Top neighbor
        if tile.y > 0 {
            let index = map.compose(tile.x, tile.y - 1);
            let new_tile = self.tile(game, map, index);
            if new_tile.is_ground() {
                neighbors.append(new_tile);
            };
        };

        // [Compute] Bottom neighbor
        if tile.y < map.size - 1 {
            let index = map.compose(tile.x, tile.y + 1);
            let new_tile = self.tile(game, map, index);
            if new_tile.is_ground() {
                neighbors.append(new_tile);
            };
        };

        neighbors.span()
    }

    fn set_game(ref self: DataStore, game: Game) {
        set!(self.world, (game));
    }

    fn set_map(ref self: DataStore, map: Map) {
        set!(self.world, (map));
    }

    fn set_character(ref self: DataStore, character: Character) {
        set!(self.world, (character));
    }

    fn set_tile(ref self: DataStore, tile: Tile) {
        set!(self.world, (tile));
    }
}
