//NOTE: this script assumes that there's only 1 backpack

if(f_param_time_to_explosion == 0)exitWith {0};
//------------------------------------------------------------------------------
bombdistance = 2.8; //how far player can be for action
duration_defusing = 5;
duration_planting = 5;

fnc_remove_actions = {
	for '_i' from 0 to 50 do {
		[player, _i] call BIS_fnc_holdActionRemove;
		[bomb,   _i] call BIS_fnc_holdActionRemove;
	};
};

fnc_plant_bomb_players = {
	if(!hasInterface)exitWith{0};

	params ["_side_bomb"];
	//	remove all actions from all players
	[] call fnc_remove_actions;
	//	create actions for defusers
	if(side player != _side_bomb)then{
		[
			bomb, // Object the action is attached to
			"Defuse bomb", // Title of the action
			"\a3\ui_f\data\IGUI\Cfg\Actions\Obsolete\ui_action_deactivate_ca.paa", // Idle icon shown on screen
			"\a3\ui_f\data\IGUI\Cfg\Actions\Obsolete\ui_action_deactivate_ca.paa", // Progress icon shown on screen
			"_this   distance _target < bombdistance", //Condition for the action to be shown
			"_caller distance _target < bombdistance", // Condition for the action to progress
			{}, // Code executed when action starts
			{}, // Code executed on every progress tick
			{
				bomb setVariable ["defused", true, true];
				[] remoteExec ["fnc_remove_actions", 0, true];
			}, // Code executed on completion
			{}, // Code executed on interrupted
			[], // Arguments passed to the scripts as _this select 3
			duration_defusing, // Action duration [s]
			0, // Priority
			false, // Remove on completion
			false // Show in unconscious state
		] call BIS_fnc_holdActionAdd;
	};
};

fnc_plant_bomb_server = {
	if(!isServer)exitWith {0};
	params ["_player"];
	removeBackpack _player;
	private _bombsite = bombsites_at_objective select {_player distance _x < bombdistance} select 0;
	bomb = createVehicle ["SatchelCharge_F", (getPosATL _bombsite) vectorAdd [0 + random 1 - random 1,0 + random 1 - random 1,0], [], 0, "CAN_COLLIDE"];
	publicVariable "bomb";
	//on all clients: create action to defuse
	[side _player] remoteExec ["fnc_plant_bomb_players", 0, true];

	//bomb ticking, exploding thingy, and ending
	[] spawn {
		private _defused = false;
		for "_tick" from 0 to f_param_time_to_explosion do {
			sleep 1;
			_defused = bomb getVariable ["defused", false];
			if(_defused)then{
				_tick = f_param_time_to_explosion + 1;
			}else{
				_time_left = f_param_time_to_explosion - _tick;
				if(_time_left > 0 && _tick % 10 == 0)then{
					["Alert",[ format ["The bomb will explode in %1 seconds!",_time_left] ]] remoteExec ["BIS_fnc_showNotification"];
				};
			};
		};
		if(_defused)then{
			//defused
			["Alert",["The bomb has been defused!"]] remoteExec ["BIS_fnc_showNotification"];
			sleep 1;
			[1] remoteExec ["f_fnc_mpEnd",2];
		}else{
			//explosion
			deleteVehicle bomb;
			bomb = createVehicle ["ModuleExplosive_DemoCharge_F", getPosATL bomb, [], 0, "CAN_COLLIDE"];
			bomb setDamage 1;
			[2] remoteExec ["f_fnc_mpEnd",2];
		};
	}
};
//------------------------------------------------------------------------------
//if(!isServer)exitWith {0}; //non servers stop after function definitions!

if(isNil "server_setup_done")exitWith{systemChat "ERROR 100"; 0};
if(!server_setup_done)       exitWith{systemChat "ERROR 101"; 0};
//waitUntil {sleep 0.1; !isNil "server_setup_done"}; //wait for other script
//waitUntil {sleep 0.1; server_setup_done};

if(isServer)then{

	params [["_bombsites",[],[[]]]];
	bombsites_at_objective = _bombsites;
	publicVariable "bombsites_at_objective";

	//marking bombsites on map:
	if(f_param_show_bombsites == 1)then{
		private _bombsets = [];
		private _bombsets_max_dist = 15;
		//add new entry to _bombsets if distance to other bombsites is bigger than _bombsets_max_dist
		//otherwise add it to its bombset
		{
			private _current = _x;
			{
				private _set = _x;
				_set = _set apply {_x distance _current};
				_set sort false;
				if(_set select 0 < _bombsets_max_dist)exitWith{
					_x pushBack _current;
					_current = objNull;
				};
			} forEach _bombsets;
			if(!isNull _current)then{
				_bombsets pushBack [_current];
			};
		} forEach bombsites_at_objective;
		//get average position
		_bombsets = _bombsets apply{
			private _pos = [0,0,0];
			{
				_pos = _pos vectorAdd position _x;
			}count(_x);
			_pos vectorMultiply 1/(count _x)
		};
		//create marker
		{
			private _marker = createMarker[str _x, _x];
			_marker setMarkerType "mil_objective";
			_marker setMarkerSize [0.7, 0.7];
		}foreach _bombsets;
	};

};
if(hasInterface)then{
	//adding action to player, because addAction doesnt work for some objects like VR objects, or invisiable objects.
	//NOTE: condition is checked on each frame!
	//alternative icons: loadVehicle_ca.paa, gear_ca.paa, unloadVehicle_ca.paa, Obsolete\ui_action_deactivate_ca.paa
	[
		player, // Object the action is attached to
		"Plant bomb", // Title of the action
		"\a3\ui_f\data\IGUI\Cfg\Actions\loadVehicle_ca.paa", // Idle icon shown on screen
		"\a3\ui_f\data\IGUI\Cfg\Actions\loadVehicle_ca.paa", // Progress icon shown on screen
		"!isNull (unitBackpack player) && ({player distance _x < bombdistance} count bombsites_at_objective) > 0", //Condition for the action to be shown
		"!isNull (unitBackpack player) && ({player distance _x < bombdistance} count bombsites_at_objective) > 0", // Condition for the action to progress
		{}, // Code executed when action starts
		{}, // Code executed on every progress tick
		{
			//only on server:
			[player] remoteExec ["fnc_plant_bomb_server", 0, true];
		}, // Code executed on completion
		{}, // Code executed on interrupted
		[], // Arguments passed to the scripts as _this select 3
		duration_planting, // Action duration [s]
		0, // Priority
		false, // Remove on completion
		false // Show in unconscious state
	] call BIS_fnc_holdActionAdd;
};
0