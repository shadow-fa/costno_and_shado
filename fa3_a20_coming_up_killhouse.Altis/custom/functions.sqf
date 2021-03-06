//------------------------------------------------------------------------------
// global variables
bombdistance = 2.2; //how far the player can be away for the action
duration_defusing = 5;
duration_planting = 5;
//------------------------------------------------------------------------------
// bomb functions

fnc_remove_actions = {
	//TODO. make it not ugly
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
			"_caller distance _target < bombdistance", //Condition for the action to progress
			{}, // Code executed when action starts
			{}, // Code executed on every progress tick
			{
				bomb setVariable ["defused", true, true];
				[] remoteExec ["fnc_remove_actions", 0, true];
			}, // Code executed on completion
			{}, // Code executed on interrupted
			[], // Arguments passed to the scripts as _this select 3
			duration_defusing, // Action duration [s]
			99, // Priority
			false, // Remove on completion
			false // Show in unconscious state
		] call BIS_fnc_holdActionAdd;
	};
};

fnc_plant_bomb_server = {
	if(!isServer)exitWith {0};
	params ["_player"];
	removeBackpack _player;
	private _bombsite = ([bombsites_at_objective,[],{_player distance _x}] call BIS_fnc_sortBy) select 0;
	
	
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
				private _time_left = f_param_time_to_explosion - _tick;
				if(_time_left > 0 && _tick % 10 == 0)then{
					["Alert",[ format ["The bomb will explode in %1 seconds!",_time_left] ]] remoteExec ["BIS_fnc_showNotification"];
				};
			};
		};
		if(_defused)then{
			//defused
			["Alert",["The bomb has been defused!"]] remoteExec ["BIS_fnc_showNotification"];
			sleep 1;
			[2] remoteExec ["f_fnc_mpEnd",2];
		}else{
			//explosion
			deleteVehicle bomb;
			bomb = createVehicle ["ModuleExplosive_DemoCharge_F", getPosATL bomb, [], 0, "CAN_COLLIDE"];
			bomb setDamage 1;
			[1] remoteExec ["f_fnc_mpEnd",2];
		};
	}
};

//------------------------------------------------------------------------------
fnc_setPlayerPos = {
	params ["_player"];

	private _player_index = players find _player;
	if( _player_index == -1 )exitWith{systemChat format ["ERROR 2. You (%1) are not a player. Or you're a JIP player?",name _player];0};
	private _spawnpoint = o_spawnpoints select _player_index;

	_player setPos (_spawnpoint select 0);
	_player setDir (_spawnpoint select 1);

	sleep 0.05; //to be on the safe side
	if( (getPos _player) distance2d (_spawnpoint select 0) < 5 )then{
		_player setVariable ["playerMoved", true, true];
	};
};
//------------------------------------------------------------------------------
fnc_setPlayerPosLoopClient = {
	waitUntil {!isNil "server_setup_done"};
	waitUntil {!isNil "players"};
	waitUntil {!isNil "o_spawnpoints"};

	//not sure this elaborate mechanism is needed.
	//But setPos only works if player actually is loaded in. (maybe time > 0.1 would be enough)
	private _sleep_time = 0.3;
	private _timeout = (2*60)/_sleep_time;
	private _i = 0;
	while { _i <= _timeout && !(player getVariable ["playerMoved", false]) } do {
		[player] call fnc_setPlayerPos;
		uiSleep _sleep_time;
		_i = _i + 1;
		if(_i == _timeout)exitWith{
			systemChat format ["ERROR 6: Can't setPos for player %1 for some reason.", name player];
			0
		};
	};
};
//------------------------------------------------------------------------------
fnc_bombSiteMarkers = {
	if(!isServer)exitWith{};
	if(f_param_show_bombsites != 1)exitWith{};

	//[bombsites_at_objective] call fnc_bombSiteMarkers
	params [
		["_bombsites",[],[[]]],
		["_bombsets_max_dist", 15, [0]]
	];

	//marking bombsites on map:
	private _bombsets = [];
	//add new entry to _bombsets if distance to other bombsites is bigger than _bombsets_max_dist
	//otherwise add it to its bombset
	{
		private _current = _x;
		{
			private _dist = selectMax (_x apply {_x distance _current});
			if(_dist < _bombsets_max_dist)exitWith{
				_x pushBack _current;
				_current = objNull;
			};
		} forEach _bombsets;
		if(!isNull _current)then{
			_bombsets pushBack [_current];
		};
	} forEach _bombsites;
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
		_marker setMarkerText (["A","B","C","D"] select _forEachIndex);
	}foreach _bombsets;
};


//------------------------------------------------------------------------------

fnc_addActions = {
	if (f_param_time_to_explosion == 0) exitWith {0};
	if (!hasInterface) exitWith {};

	can_place_bomb = false;

	waitUntil {!isNil "server_setup_done"};
	waitUntil {server_setup_done};
	waitUntil {!isNil "bombsites_at_objective"};

	//change bombsite texture from red to transparent:
	//bombsites_at_objective
	{
		_x setObjectTexture [0,""];
	} forEach bombsites_at_objective;

	//helper thread for the action
	[] spawn {
		while{true}do{
			//condition can take a long time depending on number of bombsites_at_objective
			//we don't want to check that every frame.
			//when testing with 50 bombsites_at_objective, it took 8000/10000 cycles.
			can_place_bomb = !isNull (unitBackpack player) && ({player distance _x < bombdistance} count bombsites_at_objective) > 0;
			sleep 0.25;
		};
	};

	//adding action to player, because addAction doesnt work for some objects like VR objects, or invisiable objects.
	//NOTE: condition is checked on each frame!
	//alternative icons: loadVehicle_ca.paa, gear_ca.paa, unloadVehicle_ca.paa, Obsolete\ui_action_deactivate_ca.paa
	[
		player, // Object the action is attached to
		"Plant bomb", // Title of the action
		"\a3\ui_f\data\IGUI\Cfg\Actions\loadVehicle_ca.paa", // Idle icon shown on screen
		"\a3\ui_f\data\IGUI\Cfg\Actions\loadVehicle_ca.paa", // Progress icon shown on screen
		"can_place_bomb", //Condition for the action to be shown
		"can_place_bomb", // Condition for the action to progress
		{}, // Code executed when action starts
		{}, // Code executed on every progress tick
		{
			//only on server:
			[player] remoteExec ["fnc_plant_bomb_server", 0, true];
		}, // Code executed on completion
		{}, // Code executed on interrupted
		[], // Arguments passed to the scripts as _this select 3
		duration_planting, // Action duration [s]
		99, // Priority
		false, // Remove on completion
		false // Show in unconscious state
	] call BIS_fnc_holdActionAdd;
};

//------------------------------------------------------------------------------
fnc_missionStartTimer = {
	if(!hasInterface) exitWith {};
	waitUntil {!(isNull (findDisplay 46))}; 

	titleRsc ["TimerText", "PLAIN", 0, true];
	disableSerialization;
	private _control = uiNamespace getVariable "TimerTextDisplay" displayCtrl -1;

	_control ctrlSetText "Please wait for everyone to load in.";

	waitUntil {!isNil "serverStartTime" && {serverStartTime > 0}};

	//player enableSimulation false;
	waitUntil{
		uiSleep 0.2;
		_control ctrlSetText format ["Round starting in %1 seconds", ceil (serverStartTime - serverTime)];
		serverTime > serverStartTime
	};

	_control ctrlSetText "";
	//player enableSimulation true;

};
//------------------------------------------------------------------------------
