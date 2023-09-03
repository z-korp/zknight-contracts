use array::{ArrayTrait, SpanTrait};
use traits::Into;
use dict::Felt252DictTrait;
use poseidon::poseidon_hash_span;

use alexandria_data_structures::array_ext::SpanTraitExt;

use zknight::components::tile::{Tile, TileTrait};
use zknight::constants::{SIZE, GROUND_TYPE, HOLE_TYPE, KNIGHT_TYPE, BARBARIAN_TYPE, BOWMAN_TYPE, WIZARD_TYPE};

const MULTIPLIER: u128 = 10000;

#[derive(Component, Copy, Drop, Serde, SerdeLen)]
struct Map {
    #[key]
    game_id: u32,
    level: u32,
    size: u32,
    spawn: bool,
}

// @notice Types
#[derive(Serde, Copy, Drop, PartialEq)]
enum Type {
    Ground: (),
    Hole: (),
    Knight: (),
    Barbarian: (),
    Bowman: (),
    Wizard: (),
}

// Constants

trait MapTrait {
    fn new(game_id: u32, level: u32) -> Map;
    fn compose(self: Map, x: u32, y: u32) -> u32;
    fn decompose(self: Map, index: u32) -> (u32, u32);
    fn generate(self: Map, seed: felt252) -> Span<u8>;
    fn get_type(self: Map, raw_type: u8) -> Type;
    fn get_raw_type(self: Map, _type: Type) -> u8;
}

impl MapImpl of MapTrait {
    fn new(game_id: u32, level: u32) -> Map {
        Map { game_id: game_id, level: level, size: SIZE, spawn: true }
    }

    fn compose(self: Map, x: u32, y: u32) -> u32 {
        _compose(x, y, self.size)
    }

    fn decompose(self: Map, index: u32) -> (u32, u32) {
        _decompose(index, self.size)
    }

    fn generate(self: Map, seed: felt252) -> Span<u8> {
        let seeds: Array<felt252> = array![seed + 'hole', seed + 'knight', seed + 'barbarian', seed + 'bowman', seed + 'wizard'];
        let _types: Array<u8> = array![HOLE_TYPE, KNIGHT_TYPE, BARBARIAN_TYPE, BOWMAN_TYPE, WIZARD_TYPE];
        let numbers: Array<u32> = array![self.size, 1_u32, 1_u32, 1_u32, 1_u32];
        _generate(seeds.span(), numbers.span(), _types.span(), self.size * self.size)
    }

    fn get_type(self: Map, raw_type: u8) -> Type {
        if raw_type == HOLE_TYPE {
            return Type::Hole(());
        } else if raw_type == KNIGHT_TYPE {
            return Type::Knight(());
        } else if raw_type == BARBARIAN_TYPE {
            return Type::Barbarian(());
        } else if raw_type == BOWMAN_TYPE {
            return Type::Bowman(());
        } else if raw_type == WIZARD_TYPE {
            return Type::Wizard(());
        }
        Type::Ground(())
    }

    fn get_raw_type(self: Map, _type: Type) -> u8 {
        match _type {
            Type::Ground(()) => GROUND_TYPE,
            Type::Hole(()) => HOLE_TYPE,
            Type::Knight(()) => KNIGHT_TYPE,
            Type::Barbarian(()) => BARBARIAN_TYPE,
            Type::Bowman(()) => BOWMAN_TYPE,
            Type::Wizard(()) => WIZARD_TYPE,
        }
    }
}

#[inline(always)]
fn _compose(x: u32, y: u32, size: u32) -> u32 {
    x + y * size
}

#[inline(always)]
fn _decompose(index: u32, size: u32) -> (u32, u32) {
    (index % size, index / size)
}

fn _dict_to_span(mut dict: Felt252Dict<u8>, length: u32) -> Span<u8> {
    let mut array : Array<u8> = array![];
    let mut index = 0;
    loop {
        if index == length {
            break;
        }
        array.append(dict.get(index.into()));
        index += 1;
    };
    array.span()
}

fn _generate(seeds: Span<felt252>, numbers: Span<u32>, types: Span<u8>, n_tiles: u32) -> Span<u8> {
    // [Check] Inputs compliancy
    assert(seeds.len() == numbers.len(), 'span lengths mismatch');

    // [Compute] Types
    let mut dict_types : Felt252Dict<u8> = Default::default();
    let mut index = 0;
    let length = seeds.len();
    loop {
        if index == length {
            break;
        };
        let seed = seeds.at(index);
        let number = numbers.at(index);
        let _type = types.at(index);
        __generate(*seed, *number, *_type, n_tiles, ref dict_types);
        index += 1;
    };

    // [Compute] Convert from dict to span
    _dict_to_span(dict_types, n_tiles)
}

fn __generate(seed: felt252, n_objects: u32, _type: u8, n_tiles: u32, ref dict_types: Felt252Dict<u8>) {
    // [Check] Too many objects
    assert(n_objects < n_tiles, 'too many objects');

    let mut objects_to_place = n_objects;
    let mut iter = 0;
    loop {
        // [Check] Stop if all objects have been placed
        if objects_to_place == 0 {
            break;
        }
        // [Check] Stop if all tiles have been checked
        if iter == n_tiles {
            break;
        }
        // [Check] Skip if tile already has a type
        if dict_types.get(iter.into()) != 0 {
            iter += 1;
            continue;
        }
        // [Compute] Uniform random number between 0 and MULTIPLIER
        let rand = _uniform_random(seed + iter.into(), MULTIPLIER);
        let tile_object_probability: u128 = objects_to_place.into() * MULTIPLIER / (n_tiles - iter).into();
        if rand <= tile_object_probability {
            objects_to_place -= 1;
            dict_types.insert(iter.into(), _type);
        };
        iter += 1;
    };
}

#[inline(always)]
fn _uniform_random(seed: felt252, max: u128) -> u128 {
    let hash: u256 = poseidon_hash_span(array![seed].span()).into();
    hash.low % max
}

#[cfg(test)]
mod tests {
    use array::{ArrayTrait, SpanTrait};
    use zknight::constants::SEED;
    use zknight::components::tile::{Tile, TileTrait};
    use super::{Map, MapTrait, Type};
    use debug::PrintTrait;

    #[test]
    #[available_gas(10_000_000)]
    fn test_map_get_type() {
        let map = Map { game_id: 0, level: 0, size: 3, spawn: true };
        assert(map.get_type(0) == Type::Ground(()), 'wrong type');
    }

    #[test]
    #[available_gas(10_000_000)]
    fn test_map_get_raw_type() {
        let map = Map { game_id: 0, level: 0, size: 3, spawn: true };
        assert(map.get_raw_type(Type::Ground(())) == 0, 'wrong raw type');
    }
}