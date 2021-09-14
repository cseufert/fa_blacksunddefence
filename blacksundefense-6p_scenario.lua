version = 3 -- Lua Version. Dont touch this
ScenarioInfo = {
    name = "BlackSunDefense-6P",
    description = "Forked Version to add extra slots (https://github.com/cseufert/fa_blacksunddefence). For Original see http://brunobf.blogspot.com/p/black-sun-defense.html for more information.",
    preview = '',
    map_version = 2,
    type = 'skirmish',
    starts = true,
    size = {1024, 1024},
    reclaim = {0, 0},
    map = '/maps/blacksundefense-6p.v0002/blacksundefense-6p.scmap',
    save = '/maps/blacksundefense-6p.v0002/blacksundefense-6p_save.lua',
    script = '/maps/blacksundefense-6p.v0002/blacksundefense-6p_script.lua',
    Configurations = {
        ['standard'] = {
            teams = {
                {
                    name = 'FFA',
                    armies = {'ARMY_1', 'ARMY_2', 'ARMY_3', 'ARMY_4', 'ARMY_5', 'ARMY_6'}
                },
            },
            customprops={ ExtraArmies="ARMY_HQ ARMY_INCOMING_ENEMY" },

        },
    },
    norushoffsetX_ARMY_1=0,
    norushoffsetX_ARMY_2=0,
    norushoffsetX_ARMY_3=0,
    norushoffsetX_ARMY_4=0,
    norushoffsetX_ARMY_5=0,
    norushoffsetX_ARMY_6=0,
    norushoffsetY_ARMY_1=0,
    norushoffsetY_ARMY_2=0,
    norushoffsetY_ARMY_3=0,
    norushoffsetY_ARMY_4=0,
    norushoffsetY_ARMY_5=0,
    norushoffsetY_ARMY_6=0,
    norushradius = 80,
}
