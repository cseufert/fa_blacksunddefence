version = 3 -- Lua Version. Dont touch this
ScenarioInfo = {
    name = "Black Sun Defense (6 Player) - v2.0",
    description = "Forked Version to add extra slots (https://github.com/cseufert/fa_blacksunddefence). For Original see http://brunobf.blogspot.com/p/black-sun-defense.html for more information.",
    preview = '',
    map_version = 2,
    type = 'skirmish',
    starts = true,
    size = {1024, 1024},
    reclaim = {0, 0},
    map = '/maps/BBF_BlackSunDefense.v0002/BBF_BlackSunDefense.scmap',
    save = '/maps/BBF_BlackSunDefense.v0002/BBF_BlackSunDefense_save.lua',
    script = '/maps/BBF_BlackSunDefense.v0002/BBF_BlackSunDefense_script.lua',
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
