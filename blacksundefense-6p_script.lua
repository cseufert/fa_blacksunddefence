-- #############################################################################
-- ## Black Sun Defense 
-- ## Version: 1.0
-- ## by BBF <bb.figueiredo@gmail.com>
-- ## 01/17/2016 (dd/mm/yy)
-- ##
-- ## For more information check out this blog:
-- ## http://brunobf.blogspot.com/p/black-sun-defense.html
-- ##
-- ## This script uses part of scripts by the following:
-- ## Jotto
-- ## tecxx <tecxx@rrs.at>
-- ## Manimal
-- ## GPG (www.gaspowered.com)
-- ##
-- ## Original Map Terrain by GPG ( Seton's Clutch )
-- ##
-- ##
-- ## If I'm missing someone, please do tell me so I can add you.
-- ##
-- ##
-- ## This script may be freely used on other maps if
-- ## proper respects are given, and copyrights are followed.
-- ##
-- #############################################################################
-- ##
-- ## Version History:
-- ## 1.0 - Fixed the issue where the highest difficulty would spawn a Black Sun with 0 of health.
-- ##       The map folder is being renamed from BBF_BSD_XX to BBF_BlackSunDefense since the FAF lobby uses folders name on game creation.
-- ##       The BBF_BSD_09 (0.9) that can be found on the FAF vault was not uploaded by me, and this is the official bugfix to my map.
-- ##
-- ## 0.9 - This "version" was not released by me, so I decided to skip the number to avoid any confusion.
-- ##
-- ## 0.8 - Fixed the damn desynch problem. It was indeed caused by using Objectives.KillOrCapture() in late game.
-- ##       Added map expansion back... balanced normal difficulty a little more.
-- ##
-- ## 0.7 - Added Dialog stuff back
-- ##       The map now starts completly open/expanded (this is my last attempt against the desynch)
-- ##       I had to change the story and now the gates are indestructible until... (you'll see)
-- ##
-- ## 0.6 - Tweaked wave progression, difficulty, and default map options
-- ##       Call GetTimeSeconds() once at each loop in the gate thread and round the result (could this be the cause for the desynch?)
-- ##       Removed Dialog stuff, and switched to plain old text (could be the reason for the desynch also?)
-- ##
-- ## 0.5 - Merged config into script file (to avoid messing with the broken GPGNet map uploader)
-- ##       Changed all math.random to Utilities.RandomInt() (could math.random cause a desynch ?)
-- ##       Changed some marker positions (fixed the hidrocarbon layout for player 3/4)
-- ##
-- ## 0.4 - Premodified the paths so the included library would work and uploaded again...
-- ##       Since I was able to delete the old version, I ket the same version
-- ##
-- ## 0.4 - Removed the "\n" characters from the scenario
-- ##       But this time GPGNet screwed paths for extra library...
-- ##
-- ## 0.3 - Initial public version
-- ##       GPGNet screwed up the scenario file (DO NOT DOWNLOAD)
-- ##
-- #############################################################################


--##########################################
--# Imports
--##########################################
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua');
local ScenarioFramework = import('/lua/ScenarioFramework.lua');
local Utilities = import('/lua/utilities.lua');
local Entity = import('/lua/sim/Entity.lua').Entity;
local Objectives = ScenarioFramework.Objectives;
local Cinematics = import('/lua/cinematics.lua');

--##########################################
--# Global Vars
--##########################################
local playercount = 0; -- how many defender players
local gates = {};   -- gate pointers
local killCount = { ARMY_1 = 0, ARMY_2 = 0, ARMY_3 = 0, ARMY_4 = 0, ARMY_HQ = 0, ARMY_INCOMING_ENEMY = 0}; -- gate kills for scoreboard
local canPrintText = false; -- are we past OnPopulate

--##########################################
--# Defines
--##########################################
local ARMY_ENEMY = "ARMY_INCOMING_ENEMY";
local ARMY_HQ = "ARMY_HQ";
local DEFENSE_MARK = "HILL_CENTER";
local SCATHIS_BP = 'url0401';

--##########################################
--# Config
--##########################################
local DebugEnabled = false;
local DebugCheat = false;

-- Time desired before we reach the last wave class:
local mapDesiredTime = 60 * 40;

-- Time before players may begin their assault on the gates:
local mapExpandTimer = mapDesiredTime - (60 * 12);

-- Time to show the intermission about the gates to the players:
local mapIntermissionTimer = 60 * 10;

-- Gates per player
local gatesPerPlayer = 2;

-- Wave Delays:
local minWaveDelay = 30;
local maxWaveDelay = 60;            


-- Wave Classes
local waveTable = {
{}, -- # class 01 - land scout
{}, -- # class 02 - t1 land
{}, -- # class 03 - air scout
{}, -- # class 04 - t2 land
{}, -- # class 05 - t1/t2 air
{}, -- # class 06 - t3 land
{}, -- # class 07 - t3 air
{}, -- # class 08 - sub com
{}, -- # class 09 - t4 exp
{}, -- # class 10 - scathis / aeon t2 missile
};

-- upgrades list for SCU's
local upgradeTable = {
    -- aeon
    A={
        'Shield',
        'ShieldHeavy',
        'StabilitySuppressant',
        'SystemIntegrityCompensator',
        },
    -- cybran
    R={
        'CloakingGenerator',
        'EMPCharge',
        'FocusConvertor',
        'NaniteMissileSystem',
        'SelfRepairSystem',
        'StealthGenerator', -- NOTE requires cloaking generator first
        },
    -- uef
    E={
        'AdvancedCoolingUpgrade',
        'HighExplosiveOrdnance',
        'RadarJammer',
        'Shield',
        'ShieldGeneratorField',
        },
    -- seraphim
    S={
        'DamageStabilization',
        'Missile',
        'Overcharge',
        'Shield',
        },
};

-- defines possible formations for the units
-- Where did these last 2 come from ? I didn't found them in formations.lua (they cannnot be directly assigned I suppose)
local formationTable = {
    'AttackFormation',
    'GrowthFormation',
    'None',
-- #    'SixWideFormation', 
-- #    'TravellingFormation',
};

--##########################################
--# Main Functions (Invoked by engine)
--##########################################

--##########################################
--##########################################
function OnPopulate()

    SetupGameOptions();
    ScenarioUtils.InitializeArmies();
    SetupAlliances();

end


--##########################################
--##########################################
function OnStart(self)
        SetupM1();
end



--##########################################
--##########################################
-- this function creates all mex and hydrocarbon markers
-- resource scale script (c) Jotto, reworked by tecxx, and again by BBF
function ScenarioUtils.CreateResources()
    -- fetch markers and iterate them
    local markers = ScenarioUtils.GetMarkers();
    local armies = ListPlayerArmies();
    
    for markerName, tblData in pairs(markers) do
        -- spawn resource ?
        local spawnIt = false;
        if (tblData.resource) then
            -- look at the marker name for a player id (ex: Mass_1_23 (1 would match))
            local owner = nil;
            local p1,p2 = markerName:find('%d+');
            if( p1 != nil and p2 != nil ) then
                owner = 'ARMY_' .. markerName:sub(p1,p2);
            end
            
            -- if we found an owner
            if( owner != nil ) then
                for i,army in armies do
                    if( army == owner ) then
                        spawnIt = true;
                    end
                end
            else
                -- if there's no owner, spawn it
                spawnIt = true;
            end
        end

        if (spawnIt) then
            -- check type of resource and set parameters
            local bp, albedo, sx, sz, lod;
            if (tblData.type == "Mass") then
                albedo = "/env/common/splats/mass_marker.dds";
                bp = "/env/common/props/massDeposit01_prop.bp";
                sx = 2;
                sz = 2;
                lod = 100;
            else
                albedo = "/env/common/splats/hydrocarbon_marker.dds";
                bp = "/env/common/props/hydrocarbonDeposit01_prop.bp";
                sx = 6;
                sz = 6;
                lod = 200;
            end
            -- create the resource
            CreateResourceDeposit(tblData.type, tblData.position[1], tblData.position[2], tblData.position[3], tblData.size);
            -- create the resource graphic on the map
            CreatePropHPR(bp, tblData.position[1], tblData.position[2], tblData.position[3], Random(0,360), 0, 0);
            -- create the resource icon on the map
            CreateSplat(
                tblData.position,           -- # Position
                0,                          -- # Heading (rotation)
                albedo,                     -- # Texture name for albedo
                sx, sz,                     -- # SizeX/Z
                lod,                        -- # LOD
                0,                          -- # Duration (0 == does not expire)
                -1,                         -- # army (-1 == not owned by any single army)
                0                           -- # ???
            );
        end
    end
end


--##########################################
--##########################################
-- I use this method to debug stuff in realtime
function OnF3()

    if( not DebugEnabled ) then
        return
    end
    
    -- Do Something

end

--##########################################
--# Custom Functions (Not invoked by engine)
--##########################################


--##########################################
--##########################################
function SetupGameOptions()

    ScenarioInfo.Options.Victory = 'sandbox';           -- custom victory condition
    ScenarioInfo.Options.CivilianAlliance = 'enemy';

    Utilities.UserConRequest("ui_ForceLifbarsOnEnemy"); --show enemy life bars

    if( DebugEnabled ) then
        -- #ScenarioInfo.Options.difficultyAdjustment = 0.5;
        -- #minWaveDelay = 1;
        -- #maxWaveDelay = 10;
        ScenarioInfo.Options.startupDelay = 2;
        mapIntermissionTimer = 60 * 999;
        mapExpandTimer = 60 * 1;
        mapDesiredTime = 60 * 5;
    end

    if (ScenarioInfo.Options.difficultyAdjustment == nil) then
        ScenarioInfo.Options.difficultyAdjustment = 0.5;
    end
    
    if (ScenarioInfo.Options.startupDelay == nil) then
        ScenarioInfo.Options.startupDelay = 120;
    end

    pLOG("Map Name (version): " .. ScenarioInfo.name );
    pLOG("DebugEnabled: " .. tostring(DebugEnabled) );
    pLOG("DebugCheat: " .. tostring(DebugCheat) );
    pLOG("difficultyAdjustment: " .. ScenarioInfo.Options.difficultyAdjustment);
    pLOG("startupDelay: " .. ScenarioInfo.Options.startupDelay);
    
end



--##########################################
--##########################################
function SetupAlliances()

    -- count number of players
    local armies = ListArmies();
    playercount = table.getn(armies) - 2;   -- num armies minus 2 ai players

    pLOG("PlayerCount: "..playercount);

  -- for each defender army
    for i, army in ListPlayerArmies() do
        SetupBuildRestrictions(army)

        -- set alliances
        SetAlliance(army, ARMY_ENEMY, 'Enemy'); 
        SetAlliance(army, ARMY_HQ, 'Ally'); 
        SetAlliedVictory(army, true); 

        -- set alliance with all defender players!
        for j, army2 in ListPlayerArmies() do
            if (army != army2) then 
                SetAlliance(army, army2, 'Ally'); 
            end
        end         
    end

    -- enemy and hq are enemies
    SetAlliance(ARMY_ENEMY, ARMY_HQ, 'Enemy'); 
    SetAlliance(ARMY_HQ, ARMY_ENEMY, 'Enemy');
    
    SetIgnoreArmyUnitCap(ARMY_ENEMY, true);
    SetIgnorePlayableRect(ARMY_ENEMY, true);
    
end


--##########################################
--##########################################
function SetupBuildRestrictions(army)
    ScenarioFramework.AddRestriction(army, categories.WALL);
end


--##########################################
--##########################################
function SetupWaveTable()
    -- TODO: Theses need balancing... 
    -- We need to focus on the usefull units, and avoid being too strong
    -- Class 1:
    WaveAdd( 1 , 'ual0101', 1 ); -- aeon t1 scout
    WaveAdd( 1 , 'url0101', 1 ); -- cybran t1 scout
    WaveAdd( 1 , 'uel0101', 1 ); -- uef t1 scout
    WaveAdd( 1 , 'xsl0101', 1 ); -- seraphim t1 combat scout
    
    -- Class 2:
    WaveAdd( 2 , 'ual0106', 1 ); -- aeon t1 assault bot
    WaveAdd( 2 , 'ual0201', 1 ); -- aeon t1 light tank
    WaveAdd( 2 , 'ual0104', 1 ); -- aeon t1 aa
    WaveAdd( 2 , 'ual0103', 1 ); -- aeon t1 arty
    
    WaveAdd( 2 , 'url0106', 1 ); -- cybran t1 light assault
    WaveAdd( 2 , 'url0107', 1 ); -- cybran t1 heavy assault
    WaveAdd( 2 , 'url0104', 1 ); -- cybran t1 aa
    WaveAdd( 2 , 'url0103', 1 ); -- cybran t1 arty
    
    WaveAdd( 2 , 'uel0106', 1 ); -- uef t1 light assault
    WaveAdd( 2 , 'uel0201', 1 ); -- uef t1 medium tank
    WaveAdd( 2 , 'uel0104', 1 ); -- uef t1 aa
    WaveAdd( 2 , 'uel0103', 1 ); -- uef t1 arty
    
    WaveAdd( 2 , 'xsl0201', 1 ); -- seraphim t1 medium tank
    WaveAdd( 2 , 'xsl0104', 1 ); -- seraphim t1 anti air
    WaveAdd( 2 , 'xsl0103', 1 ); -- seraphim t1 light artillery
    
    -- Class 3:
    WaveAdd( 3 , 'uaa0101', 1 );    -- aeon t1 air scout
    WaveAdd( 3 , 'ura0101', 1 );    -- cybran t1 air scout
    WaveAdd( 3 , 'uea0101', 1 );    -- uef t1 air scout
    WaveAdd( 3 , 'xsa0101', 1 );    -- seraphim t1 air scout
    
    -- Class 4:
    WaveAdd( 4 , 'ual0202', 1 ); -- aeon t2 tank
    WaveAdd( 4 , 'xal0203', 1 ); -- aeon t2 assault tank
    WaveAdd( 4 , 'ual0205', 1 ); -- aeon t2 aa
    WaveAdd( 4 , 'ual0111', 1 ); -- aeon t2 missile
    WaveAdd( 4 , 'ual0307', 1 ); -- aeon t2 shield
    
    WaveAdd( 4 , 'drl0204', 1 ); -- cybran t2 rocket
    WaveAdd( 4 , 'url0202', 1 ); -- cybran t2 tank
    WaveAdd( 4 , 'url0203', 1 ); -- cybran t2 amphibious tank
    WaveAdd( 4 , 'url0205', 1 ); -- cybran t2 aa
    WaveAdd( 4 , 'url0111', 1 ); -- cybran t2 missile launcher
    WaveAdd( 4 , 'url0306', 1 ); -- cybran t2 stealth
    WaveAdd( 4 , 'xrl0302', 1 ); -- cybran t2 mobile bomb
    
    WaveAdd( 4 , 'del0204', 1 ); -- uef t2 gatling
    WaveAdd( 4 , 'uel0202', 1 ); -- uef t2 tank
    WaveAdd( 4 , 'uel0203', 1 ); -- uef t2 amphibious tank
    WaveAdd( 4 , 'uel0205', 1 ); -- uef t2 aa   
    WaveAdd( 4 , 'uel0111', 1 ); -- uef t2 missile launcher
    WaveAdd( 4 , 'uel0307', 1 ); -- uef t2 shield
    
    WaveAdd( 4 , 'xsl0202', 1 ); -- seraphim t2 assault bot
    WaveAdd( 4 , 'xsl0203', 1 ); -- seraphim t2 hover tank
    WaveAdd( 4 , 'xsl0205', 1 ); -- seraphim t2 aa
    WaveAdd( 4 , 'xsl0111', 1 ); -- seraphim t2 mobile missile
    
    -- Class 5:
    WaveAdd( 5 , 'uaa0102', 1 ); -- aeon t1 interceptor
    WaveAdd( 5 , 'uaa0103', 1 ); -- aeon t1 bomber
    WaveAdd( 5 , 'xaa0202', 1 ); -- aeon t2 combat fighter
    WaveAdd( 5 , 'uaa0203', 1 ); -- aeon t2 gunship
    WaveAdd( 5, 'daa0206', 1 ); -- aeon t2 missile
    
    WaveAdd( 5 , 'ura0102', 1 ); -- cybran t1 interceptor
    WaveAdd( 5 , 'ura0103', 1 ); -- cybran t1 bomber
    WaveAdd( 5 , 'xra0105', 1 ); -- cybran t1 light gunship
    WaveAdd( 5 , 'dra0202', 1 ); -- cybran t2 fighter/bomber
    WaveAdd( 5 , 'ura0203', 1 ); -- cybran t2 gunship
        
    WaveAdd( 5 , 'uea0102', 1 ); -- uef t1 interceptor
    WaveAdd( 5 , 'uea0103', 1 ); -- uef t1 bomber
    WaveAdd( 5 , 'dea0202', 1 ); -- uef t2 fighter/bomber
    WaveAdd( 5 , 'uea0203', 1 ); -- uef t2 gunship
    
    WaveAdd( 5 , 'xsa0102', 1 ); -- seraphim t1 interceptor
    WaveAdd( 5 , 'xsa0103', 1 ); -- seraphim t1 bomber
    WaveAdd( 5 , 'xsa0202', 1 ); -- seraphim t2 fighter/bomber
    WaveAdd( 5 , 'xsa0203', 1 ); -- seraphim t2 gunship
    
    -- Class 6:
    WaveAdd( 6 , 'xal0305', 1 ); -- aeon t3 sniper
    WaveAdd( 6 , 'ual0303', 1 ); -- aeon t3 bot
    WaveAdd( 6 , 'ual0304', 1 ); -- aeon t3 arty
    WaveAdd( 6 , 'dal0310', 1 ); -- aeon t3 shield disruptor
    
    WaveAdd( 6 , 'url0303', 1 ); -- cybran t3 assault bot
    WaveAdd( 6 , 'xrl0305', 1 ); -- cybran t3 armored assault bot
    WaveAdd( 6 , 'url0304', 1 ); -- cybran t3 arty
    
    WaveAdd( 6 , 'uel0304', 1 ); -- uef t3 arty
    WaveAdd( 6 , 'uel0303', 1 ); -- uef t3 assault bot
    WaveAdd( 6 , 'xel0305', 1 ); -- uef t3 armored assault bot
    WaveAdd( 6 , 'xel0306', 1 ); -- uef t3 mobile missile platform
    
    WaveAdd( 6 , 'xsl0305', 1 ); -- seraphim t3 sniper bot
    WaveAdd( 6 , 'xsl0303', 1 ); -- seraphim t3 siege tank
    WaveAdd( 6 , 'xsl0304', 1 ); -- seraphim t3 heavy artillery
    WaveAdd( 6 , 'xsl0307', 1 ); -- seraphim t3 mobile shield gen
    
    -- Class 7:
    WaveAdd( 7 , 'uaa0303', 5 ); -- aeon t3 air superiority
    WaveAdd( 7 , 'uaa0304', 1 ); -- aeon t3 bomber
    WaveAdd( 7 , 'xaa0305', 2 ); -- aeon t3 aa gunship
    
    WaveAdd( 7 , 'ura0303', 5 ); -- cybran t3 air superiority
    WaveAdd( 7 , 'ura0304', 1 ); -- cybran t3 bomber
    WaveAdd( 7 , 'xra0305', 2 ); -- cybran t3 gunship
    
    WaveAdd( 7 , 'uea0303', 5 ); -- uef t3 air superiority
    WaveAdd( 7 , 'uea0304', 1 ); -- uef t3 bomber
    WaveAdd( 7 , 'uea0305', 2 ); -- uef t3 gunship
    WaveAdd( 7 , 'xea0306', 1 ); -- uef t3 heavy air transport
    
    WaveAdd( 7 , 'xsa0303', 5 ); -- seraphim t3 air superiority
    WaveAdd( 7 , 'xsa0304', 1 ); -- seraphim t3 bomber  
    
    -- Class 8:
    WaveAdd( 8 , 'ual0301', 1 ); -- aeon support commander
    WaveAdd( 8 , 'url0301', 1 ); -- cybran support commander 
    WaveAdd( 8 , 'uel0301', 1 ); -- uef support commander
    WaveAdd( 8 , 'xsl0301', 1 ); -- seraphim support commander
    
    -- Class 9:
    WaveAdd( 9, 'ual0401', 10 ); -- aeon t4 colossus
    WaveAdd( 9, 'uaa0310', 1 ); -- aeon t4 czar
        
    WaveAdd( 9, 'url0402', 15 ); -- cybran t4 monkeylord
    WaveAdd( 9, 'xrl0403', 10 ); -- cybran t4 experimental megabot
    WaveAdd( 9, 'ura0401', 3 ); -- cybran t4 soul ripper
            
    WaveAdd( 9, 'uel0401', 10 ); -- uef t4 fatboy
    
    WaveAdd( 9, 'xsl0401', 10 ); -- seraphim t4 experimental assault bot
    WaveAdd( 9, 'xsa0402', 2 ); -- seraphim t4 ahwassa
    
    -- Class 10:
    WaveAdd( 10, 'ual0301', 20 ); -- aeon support commander
    WaveAdd( 10, 'url0301', 20 ); -- cybran support commander 
    WaveAdd( 10, 'uel0301', 20 ); -- uef support commander
    WaveAdd( 10, 'xsl0301', 20 ); -- seraphim support commander

    WaveAdd( 10, 'ual0401', 10 ); -- aeon t4 colossus
    WaveAdd( 10, 'uaa0310', 1 ); -- aeon t4 czar
        
    WaveAdd( 10, 'url0402', 15 ); -- cybran t4 monkeylord
    WaveAdd( 10, 'xrl0403', 10 ); -- cybran t4 experimental megabot
    WaveAdd( 10, 'ura0401', 3 ); -- cybran t4 soul ripper
            
    WaveAdd( 10, 'uel0401', 10 ); -- uef t4 fatboy
    
    WaveAdd( 10, 'xsl0401', 10 ); -- seraphim t4 experimental assault bot
    WaveAdd( 10, 'xsa0402', 2 ); -- seraphim t4 ahwassa


end

--##########################################
--##########################################
function SetupM1()

    if( DebugEnabled ) then
        ScenarioFramework.SetPlayableArea('AREA_2', false);
    else
        ScenarioFramework.SetPlayableArea('AREA_1', false);
    end

    local pos = GetMarkerPos(DEFENSE_MARK);
    local difficulty = ScenarioInfo.Options.difficultyAdjustment;
    local health = getDifValueDESC(130000)+20000;
    local armies = ListArmies();
    ScenarioFramework.SetArmyColor(table.getn(armies) - 1, 16,16,16);
    ScenarioFramework.SetArmyColor(table.getn(armies), 255, 23, 68);
    ScenarioInfo.DefenseObject = CreateUnitHPR( "uec1901", ARMY_HQ, pos[1], pos[2], pos[3], 0,0,0);
    ScenarioInfo.DefenseObject:SetReclaimable(false);
    ScenarioInfo.DefenseObject:SetCapturable(false);
    ScenarioInfo.DefenseObject:SetMaxHealth(health);
    ScenarioInfo.DefenseObject:SetHealth(nil, health);
    
    -- This should help the players to start their economy
    if( DebugCheat ) then
        ScenarioInfo.DefenseObject:SetProductionPerSecondMass(99999);
        ScenarioInfo.DefenseObject:SetProductionPerSecondEnergy(99999);
    else
        ScenarioInfo.DefenseObject:SetProductionPerSecondMass(playercount * getDifValueDESC(10));
        ScenarioInfo.DefenseObject:SetProductionPerSecondEnergy(playercount * getDifValueDESC(200));
    end
    
    -- Let the players and the enemy know where Black Sun is
    for i, army in armies do
        local VisMarker = ScenarioFramework.CreateVisibleAreaLocation( 90, pos, 0, GetArmyBrain(army) )
    end 

    -- set score calculation to show total kills
    -- for index, brain in ArmyBrains do
    --     brain.CalculateScore = function(thisBrain)
    --         return GetKillsByBrain(thisBrain) + killCount[GetArmyNameByBrain(thisBrain)]*1000;
    --     end
    -- end

    DisplayM1Intro();

end


--##########################################
--##########################################
function DisplayM1Intro()

    -- We need to thread ourselves because we were called by OnStart which is a C-call (yield would not work otherwise)
    ForkThread( function(self)
      
        -- # If we don't do a delay here, debug code will screw up PrinText somehow...
        WaitSeconds(0.3);
        canPrintText = true;
    
        if( DebugCheat ) then
            StartM1();
            return;
        end
        
        local dialogData = {
            { displayTime = 8, text = "Welcome to " .. ScenarioInfo.name },
            { displayTime = 4, text = "[EMERGENCY BROADCAST]" },
            { displayTime = 6, text = "Priority Alert ! Incoming enemy forces detected." },
            { displayTime = 6, text = "All available personal, prepare for combat in in T-".. ScenarioInfo.Options.startupDelay .. " seconds." },
            { displayTime = 6, text = "We must protect the Black Sun from harm at all costs." },
            { displayTime = 4, text = "HQ out." },
        };
        
        
        -- #DisplayDialog( "leftcenter", dialogData, false, StartM1 );
        DisplayDialog( "right", dialogData, false, StartM1 );
    end)
    
end


--##########################################
--##########################################
function DisplayM1Intermission()

    ForkThread( function(self)
      
        if( DebugCheat ) then
            return;
        end
        
        local dialogData = {
            { displayTime = 4, text = "[EMERGENCY BROADCAST]" },
            { displayTime = 6, text = "The enemy attack is becoming stronger than we estimated." },
            { displayTime = 6, text = "We believe that they might have built some gates in order to attack us." },
            { displayTime = 6, text = "Unfortunately they seems to be scrambling our radar signal and we cannot locate them." },
            { displayTime = 6, text = "You must protect Black Sun while our researchers can improve our radar systems." },
            { displayTime = 4, text = "HQ out." },
        };
    
        -- #DisplayDialog( "leftcenter", dialogData, false, nil );  
        DisplayDialog( "right", dialogData, false, nil );   
    end)
    
end


--##########################################
--##########################################
function DisplayM2Intro()

    if( DebugCheat ) then
        StartM2();
        return;
    end
    
    local dialogData = {
        { displayTime = 4, text = "[EMERGENCY BROADCAST]" },
        { displayTime = 6, text = "We have detected massive energy spikes in our long range sensors." },
        { displayTime = 6, text = "We believe that it must be the location of the gates being used to attack us." },
        { displayTime = 4, text = "Destroy these gates and secure the Black Sun." },
        { displayTime = 4, text = "HQ out." },
    };  

    -- #DisplayDialog( "leftcenter", dialogData, false, StartM2 );  
    DisplayDialog( "right", dialogData, false, StartM2 );

end


--##########################################
--##########################################
function StartM1()
    pLOG("StartM1 !");

    ScenarioInfo.MissionNumber = 1;

  ScenarioInfo.M1 = Objectives.Protect(
      'primary',                      -- # type
      'incomplete',                   -- # complete
      "Protect Structure",            -- # title
      "Protect our HQ while we gather intel on this attack.",  -- # description
      {                               -- # target
          Units = {ScenarioInfo.DefenseObject},
      }
  );

    ScenarioInfo.M1:AddResultCallback(
    function(result)
            if( not result ) then
                gates = {};
                for i, army in ListPlayerArmies() do
                    GetArmyBrain(army):OnDefeat();
                end
            end
        end
  );

    -- Initial wait...
    pLOG("Waiting initial delay: " .. ScenarioInfo.Options.startupDelay );
    ScenarioFramework.CreateTimerTrigger( StartM1Attack, ScenarioInfo.Options.startupDelay );
    
    -- disabled
    --Sync.ObjectiveTimer = math.floor(rest);


    -- Why doesn't this work ?
    -- TODO: Try to use this kind of stuff
    -- #ScenarioFramework.Dialogue( {
    -- #    {text = '<LOC S01_M01_065_010>[{i Arnold}]: It\'s time to get into the fight! Build some Mass Extractors!' }
    -- #} );

end

--##########################################
--##########################################
function StartM1Attack()
    pLOG("StartM1Attack !");

    ScenarioInfo.EnemyGates = {};

    SetupWaveTable();
    
    -- Begin the game
    SpawnGates();

    ScenarioFramework.CreateTimerTrigger( DisplayM1Intermission, mapIntermissionTimer);
    ScenarioFramework.CreateTimerTrigger( SetupM2, mapExpandTimer);
end


--##########################################
--##########################################
function SetupM2()

    DisplayM2Intro();

end


--##########################################
--##########################################
function StartM2()

    pLOG("StartM2 !");

    -- Disabled to test if this is causing the desynch
    -- Renabled to test if this is NOT causing desynch
    ScenarioFramework.SetPlayableArea('AREA_2', false);

        
-- Disabled to test if this is causing the desynch
-- UPDATE: This is causing the desynch, but only if used in late game.
--# ScenarioInfo.M2 = Objectives.KillOrCapture(
--#    'primary',                      --# type
--#    'incomplete',                   --# complete
--#    "Destroy Enemy Gates",  --# title
--#    "Destroy the enemy gates and secure the Black Sun.",  --# description
--#    {                               --# target
--#     Units = ScenarioInfo.EnemyGates,
--#      MarkUnits = true,
--#      FlashVisible = true,
--#    }
--#  );
--#  
--#  ScenarioInfo.M2:AddResultCallback(
--#     function(result)
--#             if( result ) then
--#             PrintText("Congratulations! The Black Sun is now secure.",20,nil,20,'leftcenter');
--#             -- all gates down, display victory and end game
--#             for i, army in ListPlayerArmies() do
--#                 GetArmyBrain(army):OnVictory();
--#             end
--#             GetArmyBrain(ARMY_ENEMY):OnDefeat();
--#             end
--#     end
--#  );


end

--##########################################
--##########################################
function SpawnGates()
    -- spawn gates at the outer edges for enemy units to teleport in
    local defense = GetMarkerPos(DEFENSE_MARK);
    local angle = nil;
    local allGates = {};
    local numGatesOpen = 0;

    i = 1;
    local gateName = "Gate"..i;
    while pcall(ScenarioUtils.MarkerToPosition,gateName) do
        table.insert(allGates, gateName);
            i = i + 1
            gateName = "Gate"..i;
    end

    while numGatesOpen < (playercount * gatesPerPlayer) do
        
        local gateMarkerCount = table.getn(allGates);
        local gateName = table.remove(allGates, Utilities.GetRandomInt(1, gateMarkerCount));

        if (gates[gateName] == nil) then

            numGatesOpen = numGatesOpen + 1
            
            local pos = ScenarioUtils.MarkerToPosition(gateName);
            local distance = 13.0; --# Smaller then the last Seraphin mission, but it looks better
            local angleOffset = 3; --# Seraphin's gateways aren't perfectly aimed (it doesn't point exactly North at 0)
            local deltaX = defense[1] - pos[1]; --# distance from gate to defense
            local deltaY = defense[3] - pos[3];
            angle = math.deg(math.atan2(deltaY,deltaX)) + 90; --# angle that makes gate face the defense

            if( DebugCheat ) then           
                -- show gates
                for i, army in ListPlayerArmies() do
                    local VisMarker = ScenarioFramework.CreateVisibleAreaLocation( 100, pos, 0, GetArmyBrain(army) )
                end
            end

            local xoffset = math.cos(math.rad(angle)) * distance; --# Gate offset position from marker
            local yoffset = math.sin(math.rad(angle)) * distance;
            
            gates[gateName] = {}
            
            gates[gateName][1] = CreateUnitHPR( "xsc1901", ARMY_ENEMY, pos[1]+xoffset, pos[2]+2, pos[3]+yoffset, 0,math.rad(90 - angle + angleOffset),0);
            gates[gateName][2] = CreateUnitHPR( "xsc1901", ARMY_ENEMY, pos[1]-xoffset, pos[2]+2, pos[3]-yoffset, 0,math.rad(270 - angle + angleOffset),0);

          table.insert(ScenarioInfo.EnemyGates, gates[gateName][1]);
          table.insert(ScenarioInfo.EnemyGates, gates[gateName][2]);

            if gates[gateName][1] != nil and gates[gateName][1]:GetBlueprint().Physics.FlattenSkirt then
                gates[gateName][1]:CreateTarmac(true, true, true, false, false)
                gates[gateName][2]:CreateTarmac(true, true, true, false, false)
            end



            for j = 1,2 do

                local health = getDifValueASC(1000000);
                gates[gateName][j]:SetMaxHealth(health);
                gates[gateName][j]:SetHealth(nil, health);

                
                gates[gateName][j]:SetReclaimable(false);
                gates[gateName][j]:SetCapturable(false);
                gates[gateName][j]:SetProductionPerSecondEnergy(15000);
                gates[gateName][j]:SetRegenRate( getDifValueASC(200) );


                -- set gate onkilled function
                gates[gateName][j].OldOnKilled = gates[gateName][j].OnKilled;
                gates[gateName][j].myID = gateName;
                gates[gateName][j].mySubID = j;
                gates[gateName][j].OnKilled = function(self, instigator, type, overkillRatio)
                
                    self.OldOnKilled(self, instigator, type, overkillRatio);

                    local gatePair = 1;
                    if ( self.mySubID == 1 ) then gatePair = 2; end

                    if( gates[self.myID][gatePair]:IsDead() ) then
                        return;
                    end

                    gates[self.myID][gatePair]:Kill();

                    -- add points to player
                    local instArmy = instigator:GetArmy();
                    local armyName = GetArmyNameByBrain(GetArmyBrain(instArmy));
                    killCount[armyName] = killCount[armyName] + 1;

                    pLOG("gate killed, id="..self.myID.." instigator army: "..instArmy.."/"..armyName);
                    
                    gates[self.myID] = nil;
                    
                    local gateCount = 0;
                    for gateName in gates do
                        if( gates[gateName] != nil ) then
                            gateCount = gateCount + 1;
                        end
                    end
                    
                    if( gateCount < 1 ) then
                        -- all gates down, display victory and end game

                        PrintText("Congratulations! The Black Sun is now safe.",20,nil,20,'leftcenter');
                        for i, army in ListPlayerArmies() do
                            GetArmyBrain(army):OnVictory();
                        end
                        
                        GetArmyBrain(ARMY_ENEMY):OnDefeat();

                    else
                        PrintText("[WARNING] There are still " .. gateCount .. " gate(s) left." ,20,nil,20,'leftcenter');
                    end
                        


                end --# OnKilled
                
            end --# for j = 1,2


            -- Start this gate's thread
            ForkThread(GateThread, gateName, angle);

        end --# if
    end --# while
end


--##########################################
--##########################################
function GateThread(gateName, angle)
    
    local pos = GetMarkerPos(gateName);
    local angleRad = math.rad(180 - angle);
    local aiBrain = GetArmyBrain(ARMY_ENEMY);
    local startupTime = GetGameTimeSeconds();
    local nextWave = startupTime + 1;
    local waveUnits = {};
    local waveProAdjust = 1.0;

    
    while( gates[ gateName ] != nil ) do
        --#############################################
        --## Choose the next unit to spawn
        --#############################################
        local gameTime = math.ceil(GetGameTimeSeconds());
        local timeElapsed = gameTime - startupTime;
        -- New progression curve... screw the linear method...
        local minExp = 0.25;
        local maxExp = 0.7;
        -- [0.1 -> 1] == [0.655 -> 0.25] -=- default: 0.475
        local dif = maxExp - ( (maxExp-minExp) * ScenarioInfo.Options.difficultyAdjustment );
        -- 100 => last round at mapDesiredTime -- Reach round 100 in mapDesiredTime seconds
        local adj = 100 / math.pow(mapDesiredTime, dif);
        local currentWave = math.floor( adj * math.pow(timeElapsed, dif) ) + 1;

        local waveId = math.mod( currentWave, 10 );
        if( waveId == 0 ) then waveId = 10; end

        local waveClass = math.ceil( currentWave / 10 );
        if( waveClass > 10 ) then
            waveProAdjust = 1.0 + (( currentWave - 100 ) / 25); --# 25 -> /100 but 4 times faster... so 101 = 1.04 / 102 = 1.08
            waveId = 10;
            waveClass = 10;
        end

        -- How fast do the gates spawn units ?
        -- Note v0.8: Variable according to difficulty
        -- Note: 7/dif was easy
        local buildRate = currentWave * currentWave / ( 6 / ScenarioInfo.Options.difficultyAdjustment );
        
        -- Random Wave Class Chooser (a.k.a. RWCC) =)
        -- Initially we select the current class as our choice.
        -- But there's a chance that we'll drop to a previous class based on the rules below
        local selectedClass = waveClass;
        while( selectedClass > 1 ) do
            -- This is the probability of staying in the current class
            local probability = 0;
            
            if( selectedClass == waveClass ) then
                -- As the waveID progresses (from 1 to 10 / by waveClass)
                -- Wave ID * 10 => 9%, 18%, .. 90%
                -- Note v0.6: Decreased probability from 9 to 7
                probability = (waveId*7);
            else
                -- Class Difference * 20 => previous -> first = 25%, 50%, 75%, 100% (so we have at most the class-4)
                -- Note v0.6: Decreased probability from 25 to 20
                probability = (waveClass-selectedClass) * 20;
            end
            
            -- If we are past wave 100, let's increase the odds
            probability = probability * waveProAdjust;
            
            local randProb = Utilities.GetRandomInt(1,100);
            if( randProb > probability ) then
                selectedClass = selectedClass - 1;
            else
                break;
            end
        end

        -- Now that we know our desired class, let's choose a random unit from our balanced table (check config for more info)
        local classCount = table.getn(waveTable[selectedClass]);
        local choosenIndex = Utilities.GetRandomInt(1, classCount);
        local nextUnit = waveTable[selectedClass][choosenIndex];

            
        --#############################################
        --## Spawn and setup the unit
        --#############################################
        -- Do not always spawn in the same spot
        local randX = Utilities.GetRandomInt(0,10) - 5;
        local randY = Utilities.GetRandomInt(0,10) - 5;

        local unit = CreateUnitHPR( nextUnit, ARMY_ENEMY, pos[1]+randX, pos[2], pos[3]+randY, 0, angleRad, 0);
        
        local veterancy = (math.ceil( currentWave / 10 ) - selectedClass) * 3;

        GateSpawn(unit, nextUnit, veterancy);
            
        -- Do not try to include the Scathis in a formation
        -- It'll spit errors about a slot position
        if( nextUnit != SCATHIS_BP ) then
            table.insert(waveUnits, unit);
        end
        
        local bp = unit:GetBlueprint();
            
        local unitCost = 0;
        local unitDelay = 0.0;
        
        if (bp != nil) then
            bp.Wreckage = nil;
            
            -- Nothing but time =)
            unitCost = bp.Economy.BuildTime;
            unitDelay = unitCost / buildRate;

        else
            pLOG("could not get blueprint for unit: " .. nextUnit);
            unitDelay = 3;
        end
        
        unitDelay = unitDelay - 1.35; --# GateSpawn = 1.35

        -- do not delay more then the wave attack
        if( unitDelay > nextWave - gameTime ) then
            unitDelay = nextWave - gameTime + 0.2;
        end
        
        if( unitDelay < 1.65 ) then
            unitDelay = 1.65; --# GateSpawn + 1.65 = 3.00 ( max 20 per minute )
        end
        
        --#############################################
        --## Charging gate
        --#############################################
        WaitSeconds(unitDelay); -- Charging gate

        
        --#############################################
        --## Send out the wave if we have waited enough
        --#############################################
        if( gameTime > nextWave ) then

            local platoonFormation = formationTable[Utilities.GetRandomInt(1, table.getn(formationTable))];
            
            --## --------------
            --## LAND
            local landAttackPlatoon = aiBrain:MakePlatoon('','');
            local landPlatoonUnits = EntityCategoryFilterDown(categories.LAND, waveUnits);
            aiBrain:AssignUnitsToPlatoon(landAttackPlatoon, landPlatoonUnits, 'Attack', platoonFormation);
        ScenarioFramework.PlatoonPatrolChain(landAttackPlatoon, 'LandPatrolChain')

            --## --------------
            --## AIR
            local airAttackPlatoon = aiBrain:MakePlatoon('','');
            local airPlatoonUnits = EntityCategoryFilterDown(categories.AIR, waveUnits);
            aiBrain:AssignUnitsToPlatoon(airAttackPlatoon, airPlatoonUnits, 'Attack', platoonFormation);
        ScenarioFramework.PlatoonPatrolChain(airAttackPlatoon, 'AirPatrolChain')

            local randomWaveDelay = Utilities.GetRandomInt(minWaveDelay, maxWaveDelay);
            nextWave = gameTime + randomWaveDelay;
            
            pLOG("## " .. gateName .. " ## Wave " .. currentWave .." (count=".. table.getn(waveUnits) .. ") next wave in " .. randomWaveDelay .. " seconds (" .. nextWave .. ")" );

            waveUnits = {};
            
        end
        
    end

end


--##########################################
--##########################################
function UpgradeSubCommander(unit, bp)

    if (bp == "ual0301") then       -- aeon
        local ucnt = table.getn(upgradeTable["A"]);
        local enh = upgradeTable["A"][Utilities.GetRandomInt(1, ucnt)];
        unit:CreateEnhancement(enh);
        
    elseif (bp == "url0301") then   -- cybran
        local ucnt = table.getn(upgradeTable["R"]);
        local enh = upgradeTable["R"][Utilities.GetRandomInt(1, ucnt)];
        if (enh == 'StealthGenerator') then -- stealth needs cloaking first
            unit:CreateEnhancement('CloakingGenerator');
        end
        unit:CreateEnhancement(enh);
        
    elseif (bp == "uel0301") then   -- uef
        local ucnt = table.getn(upgradeTable["E"]);
        local enh = upgradeTable["E"][Utilities.GetRandomInt(1, ucnt)];
        unit:CreateEnhancement(enh);
        
    elseif (bp == "xsl0301") then   -- seraphim
        local ucnt = table.getn(upgradeTable["S"]);
        local enh = upgradeTable["S"][Utilities.GetRandomInt(1, ucnt)];
        unit:CreateEnhancement(enh);
        
    end

end


--##########################################
--##########################################
function WaveAdd( class, bp, repeatEntry )
    repeatEntry = repeatEntry or 1;
    for i = 1,repeatEntry do
        table.insert(waveTable[class], bp);
    end
end

--##########################################
--##########################################
function ListPlayerArmies()
    armies = ListArmies();
    table.removeByValue(armies, ARMY_ENEMY);
    table.removeByValue(armies, ARMY_HQ);
    return armies
end

--##########################################
--##########################################
-- Return a marker position (if exists)
function GetMarkerPos(markerName)
    if pcall(ScenarioUtils.MarkerToPosition,markerName) then
        return ScenarioUtils.MarkerToPosition(markerName); 
    end
    
    pLOG("GetMarkerPos(): Invalid marker name: " .. markerName)
    local mapSizeX, mapSizeZ = GetMapSize();
    return { mapSizeX/2, 512.0, mapSizeZ/2 };
end

--##########################################
--##########################################
function pLOG(...)

    LOG( "## BBF ## ", unpack(arg));

    if( DebugEnabled and canPrintText ) then
        local buffer = "## BBF ## ";
        for i = 1,arg.n do
            buffer = buffer .. " " .. tostring(arg[i]);
        end
        PrintText(tostring(buffer),12,nil,15,'leftcenter');
    end

end


--##########################################
--##########################################
function DisplayDialogEx( textAlign, dialogData, lockUI, callbackFunction )
    ForkThread( function(self)

    --# Should never happen with our new code
    while( canPrintText == false ) do
        WaitSeconds( 0.5 );
    end
    
      if lockUI then
            LockInput();
            Cinematics.EnterNISMode();
        end

      if dialogData and ( dialogData != nil ) then
    
        for i, dialogEntry in dialogData do

                PrintText(dialogEntry.text,20,nil,dialogEntry.displayTime+3, textAlign);
          if dialogEntry.displayTime and dialogEntry.displayTime > 0 then
            WaitSeconds( dialogEntry.displayTime );
          else
            WaitSeconds( 1 );
          end

        end

      end
      
      if lockUI then
            Cinematics.ExitNISMode();
        UnlockInput();
      end
    
      if callbackFunction then
        callbackFunction();
      end
    
    end) --# ForkThread
end



--##########################################
--##########################################
function DisplayDialog( textAlign, dialogData, lockUI, callbackFunction )
    ForkThread( function(self)

        local myDialog = nil;
    
      if lockUI then
            LockInput();
            Cinematics.EnterNISMode();
        end

        -- This is all screwed... why doesn't SetText work as it should ?
      if dialogData and ( dialogData != nil ) then
    
        for i, dialogEntry in dialogData do

            myDialog = CreateDialogue( dialogEntry.text, nil, textAlign );

          if dialogEntry.displayTime and dialogEntry.displayTime > 0 then
            WaitSeconds( dialogEntry.displayTime );
          else
            WaitSeconds( 1 );
          end

                if( myDialog != nil ) then
                myDialog:Destroy()
                WaitSeconds(0.01);
            end
        end
      end
    
      if lockUI then
            Cinematics.ExitNISMode();
        UnlockInput();
      end
    
      if callbackFunction then
        callbackFunction();
      end
    
    end) --# ForkThread
end 


--##########################################
--##########################################
-- Function copied from EffectUtilities.lua and tweaked
function GateSpawn( unit, unitID, veterancy )

    -- Why do we fork, and check so much if the unit is dead ?
    -- If any of this crashes, the whole Gate will crash...
    ForkThread( function()
    
        if( unit:IsDead() ) then
            return
        end

        -- difficulty adjust
        local difficultyBuff = ScenarioInfo.Options.difficultyAdjustment * 2;

        UpgradeSubCommander(unit, unitID);

        unit:SetVeterancy(veterancy);
        unit:SetMaxHealth(unit:GetHealth()*difficultyBuff);
        unit:SetHealth(nil, unit:GetHealth()*difficultyBuff);

    
        local army = unit:GetArmy()
    
        unit:HideBone(0, true)
    
        CreateAttachedEmitter ( unit, -1, army, '/effects/emitters/seraphim_rift_in_small_01_emit.bp' );
        CreateAttachedEmitter ( unit, -1, army, '/effects/emitters/seraphim_rift_in_small_02_emit.bp' );
        WaitSeconds (1.0)   --# 2
    
        if( unit:IsDead() ) then
            return
        end
    
        --# unit / bone / army / size? / time? / ? / ?
        CreateLightParticle( unit, -1, army, 15, 10, 'glow_05', 'ramp_jammer_01' )  
        WaitSeconds (0.1)   
    
        if( unit:IsDead() ) then
            return
        end
    
        unit:ShowBone(0, true)  
        WaitSeconds (0.25)  
    
        if( unit:IsDead() ) then
            return
        end
    
        CreateAttachedEmitter ( unit, -1, army, '/effects/emitters/seraphim_rift_in_large_03_emit.bp' );
        CreateAttachedEmitter ( unit, -1, army, '/effects/emitters/seraphim_rift_in_large_04_emit.bp' );
    end);
    
    WaitSeconds (1.35);
end


--##########################################
--##########################################
-- given a default value returns it adjusted to the difficulty (decreasing the value on hard)
function getDifValueDESC(value)
  return (-2 * value * ScenarioInfo.Options.difficultyAdjustment) + (value * 2);
end

--##########################################
--##########################################
-- given a default value returns it adjusted to the difficulty (increasing the value on hard)
function getDifValueASC(value)
  return value * ScenarioInfo.Options.difficultyAdjustment;
end

--##########################################
--##########################################
--given a player returns a proper username
function getUsername(army)
    return GetArmyBrain(army).Nickname;
end

--##########################################
--##########################################
--given an ai brain returns an army index
function GetArmyNameByBrain(aiBrain)
    local army = aiBrain:GetArmyIndex();
    for i, v in ListArmies() do
        if (i == army) then
            return v;
        end
    end
end

--##########################################
--##########################################
function GetKillsByBrain(brain)
    local kills = brain:GetArmyStat('Enemies_Killed',0.0).Value;
    return kills;
end


--EOF
