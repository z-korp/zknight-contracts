// Internal imports

use zknight::components::tile::{Tile, TileTrait};
use zknight::entities::foe::FoeTrait;

#[derive(Copy, Drop)]
struct Barbarian {
    health: u8,
}

impl BarbarianImpl of FoeTrait<Barbarian> {
    #[inline(always)]
    fn new(health: u8, _type: u8) -> Barbarian {
        Barbarian { health: health }
    }

    #[inline(always)]
    fn can_attack(self: Barbarian, tile: Tile, target: Tile) -> bool {
        tile.distance(target) == 1 && self.health > 0
    }

    #[inline(always)]
    fn can_move(self: Barbarian) -> bool {
        self.health > 0
    }

    #[inline(always)]
    fn compute_score(self: Barbarian, tile: Tile, target: Tile) -> u32 {
        tile.distance(target)
    }

    #[inline(always)]
    fn get_hits(self: Barbarian, tile: Tile, target: Tile, size: u32) -> Span<u32> {
        let mut hits: Array<u32> = array![];
        if !self.can_attack(tile, target) {
            return hits.span();
        };
        hits.append(target.index.into());
        hits.span()
    }

    fn next(
        self: Barbarian, tile: Tile, target: Tile, size: u32, ref neighbors: Span<Tile>
    ) -> u32 {
        // [Compute] Current tile score
        let mut result = tile;
        let mut score = self.compute_score(tile, target);

        // [Compute] Lowest score tile
        loop {
            match neighbors.pop_front() {
                Option::Some(neighbor) => {
                    let new_tile = *neighbor;
                    let new_score = self.compute_score(new_tile, target);
                    if new_score < score {
                        score = new_score;
                        result = new_tile;
                    };
                },
                Option::None => { break; },
            };
        };

        result.index
    }
}

#[cfg(test)]
mod tests {
    // Core imports

    use debug::PrintTrait;

    // Internal imports

    use zknight::components::character::{Character, CharacterTrait};
    use zknight::components::tile::{Tile, TileTrait};

    // Local imports

    use super::{Barbarian, FoeTrait};

    // Constants

    const SIZE: u32 = 8;

    #[test]
    #[available_gas(1_000_000)]
    fn test_barbarian_get_hits() {
        let char = CharacterTrait::new(1);
        let barbarian: Barbarian = FoeTrait::new(char.health, char._type);
        let tile = Tile { game_id: 0, level: 0, index: 3 + SIZE * 2, _type: 0, x: 3, y: 2 };
        let target = Tile { game_id: 0, level: 0, index: 3 + SIZE * 1, _type: 0, x: 3, y: 1 };
        let hits = barbarian.get_hits(tile, target, SIZE);
        let expected = 3 + SIZE * 1;
        assert(*hits.at(0) == expected, 'Wrong result');
    }
}
