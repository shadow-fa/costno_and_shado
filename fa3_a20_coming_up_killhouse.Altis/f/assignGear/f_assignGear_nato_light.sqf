	// F3 - Folk ARPS Assign Gear Script - AAF - Light Loadout
// Credits: Please see the F3 online manual (http://www.ferstaberinde.com/f3/en/)
// ====================================================================================

// DEFINE UNIT TYPE LOADOUTS
// The following blocks of code define loadouts for each type of unit (the unit type
// is passed to the script in the first variable)

switch (_typeofUnit) do
{
//co,ftl,r,dm
// ====================================================================================
// Platoon CO Loadout:
	case "co":
	{
		_unit addmagazines [_smokegrenade, 1];
		_unit addItem _firstaid ;
		_unit addmagazines [_pistolmag, 1];
		_unit addweapon _pistol;
		_unit addmagazines [_pistolmag, 4];
	};
// Designated Marksman Loadout:
	case "dm":
	{
		_unit addmagazines [_zubmag, 1];
		_unit addweapon _zub;
		_unit addItem _firstaid;
		_unit addmagazines [_DMrifleMag, 3];
		_unit addmagazines [_zubmag, 4];
	};
// Rifleman Loadout:
	case "r":
	{
		_unit addItem _firstaid ;
		_unit addmagazines [_pistolmag, 1];
		_unit addweapon _pistol;
		_unit addmagazines [_pistolmag, 4];
	};

// Include the loadouts for vehicles and crates:
#include "f_assignGear_nato_v.sqf";

// ====================================================================================

// END SWITCH FOR DEFINE UNIT TYPE LOADOUTS
};
