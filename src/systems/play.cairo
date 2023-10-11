#[system]
mod Play {
    use array::{ArrayTrait, SpanTrait};
    use dict::Felt252DictTrait;
    use traits::Into;
    use nullable::NullableTrait;

    use dojo::world::{Context, IWorld};

    use zknight::constants::{
        GROUND_TYPE, KNIGHT_DAMAGE, BARBARIAN_DAMAGE, BOWMAN_DAMAGE, WIZARD_DAMAGE
    };
    use zknight::components::game::{Game, GameTrait};
    use zknight::components::map::{Map, MapTrait, Type};
    use zknight::components::tile::{Tile, TileTrait};
    use zknight::components::character::{Character, CharacterTrait};
    use zknight::entities::foe::{Foe, FoeTrait};

    use debug::PrintTrait;

    fn execute(ctx: Context, player: felt252, x: u32, y: u32) {
        // [Command] Game entity
        let mut game: Game = get!(ctx.world, player, (Game));

        // [Check] Game is not over
        assert(!game.over, 'Game is over');

        // [Command] Map entity
        let mut map: Map = get!(ctx.world, game.game_id, (Map));

        // [Command] Tile entities
        let length = map.size * map.size;
        let mut tiles: Felt252Dict<Nullable<Tile>> = Default::default();
        let mut index = 0;
        loop {
            if index == length {
                break;
            }
            let tile_key = (game.game_id, map.level, index);
            let mut tile = get!(ctx.world, tile_key.into(), (Tile));
            // Could be unknown entity if GROUND_TYPE, then set coordinates
            if tile._type == GROUND_TYPE {
                let (tile_x, tile_y) = map.decompose(index);
                tile.x = tile_x;
                tile.y = tile_y;
            }
            tiles.insert(index.into(), nullable_from_box(BoxTrait::new(tile)));
            index += 1;
        };

        // [Command] Knight entity
        let knight_key = (game.game_id, CharacterTrait::get_knight_type());
        let mut knight_char = get!(ctx.world, knight_key.into(), (Character));
        knight_char.reset_damage();
        let mut knight_tile = tiles.get(knight_char.index.into()).deref();

        // [Command] Barbarian entity
        let barbarian_key = (game.game_id, CharacterTrait::get_barbarian_type());
        let mut barbarian_char = get!(ctx.world, barbarian_key.into(), (Character));
        barbarian_char.reset_damage();
        let mut barbarian_tile = tiles.get(barbarian_char.index.into()).deref();

        // [Command] Bowman entity
        let bowman_key = (game.game_id, CharacterTrait::get_bowman_type());
        let mut bowman_char = get!(ctx.world, bowman_key.into(), (Character));
        bowman_char.reset_damage();
        let mut bowman_tile = tiles.get(bowman_char.index.into()).deref();

        // [Command] Wizard entity
        let wizard_key = (game.game_id, CharacterTrait::get_wizard_type());
        let mut wizard_char = get!(ctx.world, wizard_key.into(), (Character));
        wizard_char.reset_damage();
        let mut wizard_tile = tiles.get(wizard_char.index.into()).deref();

        // [Check] Target position is in range, target is not a hole
        let new_index = map.compose(x, y);
        let mut new_tile = tiles.get(new_index.into()).deref();
        assert(knight_tile.is_close(new_tile), 'Target position is not in range');
        assert(!new_tile.is_hole(), 'Target position is a hole');

        // [Effect] Pass if target is knight, Attack if the target is a foe, move otherwise
        if new_tile.is_knight() { // Pass
        } else if new_tile.is_barbarian() && barbarian_char.health > 0 {
            // [Command] Update Character
            barbarian_char.take_damage(knight_char._type, KNIGHT_DAMAGE);
            set!(ctx.world, (barbarian_char));

            // [Check] Foe death
            if barbarian_char.health == 0 {
                // [Command] Update Tile
                new_tile.set_ground_type();
                set!(ctx.world, (new_tile));
                // [Effect] Update the map score
                map.increase_score(11);
            };
        } else if new_tile.is_bowman() && bowman_char.health > 0 {
            // [Command] Update Character
            bowman_char.take_damage(knight_char._type, KNIGHT_DAMAGE);
            set!(ctx.world, (bowman_char));

            // [Check] Foe death
            if bowman_char.health == 0 {
                // [Command] Update Tile
                new_tile.set_ground_type();
                set!(ctx.world, (new_tile));
                // [Effect] Update the map score
                map.increase_score(11);
            };
        } else if new_tile.is_wizard() && wizard_char.health > 0 {
            // [Command] Update Character
            wizard_char.take_damage(knight_char._type, KNIGHT_DAMAGE);
            set!(ctx.world, (wizard_char));

            // [Check] Foe death
            if wizard_char.health == 0 {
                // [Command] Update Tile
                new_tile.set_ground_type();
                set!(ctx.world, (new_tile));
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
            tiles.insert(index.into(), nullable_from_box(BoxTrait::new(tile)));
            // [Command] Update previous tile
            knight_tile.set_ground_type();
            tiles.insert(knight_tile.index.into(), nullable_from_box(BoxTrait::new(knight_tile)));
            set!(ctx.world, (knight_tile));
            // [Command] Update new tile
            new_tile.set_knight_type();
            tiles.insert(new_tile.index.into(), nullable_from_box(BoxTrait::new(new_tile)));
            set!(ctx.world, (tile));
            knight_tile = new_tile; // Update knight tile for the next instructions
            // [Command] Update Character
            knight_char.set_index(new_index);
            set!(ctx.world, (knight_char));
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
                let mut hit_tile = tiles.get(hit_index.into()).deref();
                if hit_tile.is_knight() {
                    // [Command] Update Character
                    knight_char.take_damage(barbarian_char._type, BARBARIAN_DAMAGE);
                    set!(ctx.world, (knight_char));
                } else if hit_tile.is_bowman() && bowman_char.health > 0 {
                    // [Command] Update Character
                    bowman_char.take_damage(barbarian_char._type, BARBARIAN_DAMAGE);
                    set!(ctx.world, (bowman_char));
                    // [Check] Foe death
                    if bowman_char.health == 0 {
                        // [Command] Update Tile
                        hit_tile.set_ground_type();
                        set!(ctx.world, (hit_tile));
                        // [Effect] Update the map score
                        map.increase_score(11);
                    };
                } else if hit_tile.is_wizard() && wizard_char.health > 0 {
                    // [Command] Update Character
                    wizard_char.take_damage(barbarian_char._type, BARBARIAN_DAMAGE);
                    set!(ctx.world, (wizard_char));
                    // [Check] Foe death
                    if wizard_char.health == 0 {
                        // [Command] Update Tile
                        hit_tile.set_ground_type();
                        set!(ctx.world, (hit_tile));
                        // [Effect] Update the map score
                        map.increase_score(11);
                    };
                };
                i += 1;
            };
        } else if barbarian.can_move() && knight_char.health > 0 {
            // [Effect] Move Barbarian, update the barbarian position in storage and hashmap
            let new_index = barbarian.next(barbarian_tile, knight_tile, map.size, ref tiles);
            let mut new_tile = tiles.get(new_index.into()).deref();
            // [Command] Update previous tile
            barbarian_tile.set_ground_type();
            tiles
                .insert(
                    barbarian_tile.index.into(), nullable_from_box(BoxTrait::new(barbarian_tile))
                );
            set!(ctx.world, (barbarian_tile));
            // [Command] Update new tile
            new_tile.set_barbarian_type();
            tiles.insert(new_tile.index.into(), nullable_from_box(BoxTrait::new(new_tile)));
            set!(ctx.world, (new_tile));
            barbarian_tile = new_tile; // Update knight tile for the next instructions
            // [Command] Update Character
            barbarian_char.set_index(new_index);
            set!(ctx.world, (barbarian_char));
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
                let mut hit_tile = tiles.get(hit_index.into()).deref();
                if hit_tile.is_knight() {
                    // [Command] Update Character
                    knight_char.take_damage(bowman_char._type, BOWMAN_DAMAGE);
                    set!(ctx.world, (knight_char));
                    // [Break] Hits stop at the first character
                    break;
                } else if hit_tile.is_barbarian() && barbarian_char.health > 0 {
                    // [Command] Update Character
                    barbarian_char.take_damage(bowman_char._type, BOWMAN_DAMAGE);
                    set!(ctx.world, (barbarian_char));
                    // [Check] Foe death
                    if barbarian_char.health == 0 {
                        // [Command] Update Tile
                        hit_tile.set_ground_type();
                        set!(ctx.world, (hit_tile));
                        // [Effect] Update the map score
                        map.increase_score(11);
                    };
                    // [Break] Hits stop at the first character
                    break;
                } else if hit_tile.is_wizard() && wizard_char.health > 0 {
                    // [Command] Update Character
                    wizard_char.take_damage(bowman_char._type, BOWMAN_DAMAGE);
                    set!(ctx.world, (wizard_char));
                    // [Check] Foe death
                    if wizard_char.health == 0 {
                        // [Command] Update Tile
                        hit_tile.set_ground_type();
                        set!(ctx.world, (hit_tile));
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
            let new_index = bowman.next(bowman_tile, knight_tile, map.size, ref tiles);
            let mut new_tile = tiles.get(new_index.into()).deref();
            // [Command] Update previous tile
            bowman_tile.set_ground_type();
            tiles.insert(bowman_tile.index.into(), nullable_from_box(BoxTrait::new(bowman_tile)));
            set!(ctx.world, (bowman_tile));
            // [Command] Update new tile
            new_tile.set_bowman_type();
            tiles.insert(new_tile.index.into(), nullable_from_box(BoxTrait::new(new_tile)));
            set!(ctx.world, (new_tile));
            bowman_tile = new_tile; // Update knight tile for the next instructions
            // [Command] Update Character
            bowman_char.set_index(new_index);
            set!(ctx.world, (bowman_char));
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
                let mut hit_tile = tiles.get(hit_index.into()).deref();
                if hit_tile.is_knight() {
                    // [Command] Update Character
                    knight_char.take_damage(wizard_char._type, WIZARD_DAMAGE);
                    set!(ctx.world, (knight_char));
                } else if hit_tile.is_barbarian() && barbarian_char.health > 0 {
                    // [Command] Update Character
                    barbarian_char.take_damage(wizard_char._type, WIZARD_DAMAGE);
                    set!(ctx.world, (barbarian_char));
                    // [Check] Foe death
                    if barbarian_char.health == 0 {
                        // [Command] Update Tile
                        hit_tile.set_ground_type();
                        set!(ctx.world, (hit_tile));
                        // [Effect] Update the map score
                        map.increase_score(11);
                    };
                } else if hit_tile.is_bowman() && bowman_char.health > 0 {
                    // [Command] Update Character
                    bowman_char.take_damage(wizard_char._type, WIZARD_DAMAGE);
                    set!(ctx.world, (bowman_char));
                    // [Check] Foe death
                    if bowman_char.health == 0 {
                        // [Command] Update Tile
                        hit_tile.set_ground_type();
                        set!(ctx.world, (hit_tile));
                        // [Effect] Update the map score
                        map.increase_score(11);
                    };
                };
                i += 1;
            };
        } else if wizard.can_move() && knight_char.health > 0 {
            // [Effect] Move Wizard, update the wizard position in storage and hashmap
            let new_index = wizard.next(wizard_tile, knight_tile, map.size, ref tiles);
            let mut new_tile = tiles.get(new_index.into()).deref();
            // [Command] Update previous tile
            wizard_tile.set_ground_type();
            tiles.insert(wizard_tile.index.into(), nullable_from_box(BoxTrait::new(wizard_tile)));
            set!(ctx.world, (wizard_tile));
            // [Command] Update new tile
            new_tile.set_wizard_type();
            tiles.insert(new_tile.index.into(), nullable_from_box(BoxTrait::new(new_tile)));
            set!(ctx.world, (new_tile));
            wizard_tile = new_tile; // Update knight tile for the next instructions
            // [Command] Update Character
            wizard_char.set_index(new_index);
            set!(ctx.world, (wizard_char));
        }

        // [Effect] Score and game evalutation
        map.decrease_score(1);
        if knight_char.health == 0 {
            // [Command] Update Game
            game.set_over(true);
            set!(ctx.world, (game));
            // [Command] Update Map
            map.set_over(true);
            set!(ctx.world, (map));
        } else if barbarian_char.health == 0 && bowman_char.health == 0 && wizard_char.health == 0 {
            // [Command] Update Map
            map.increase_level();
            map.set_spawn(false);
            set!(ctx.world, (map));
        } else {
            // [Command] Update Map
            set!(ctx.world, (map));
        }
    }
}
