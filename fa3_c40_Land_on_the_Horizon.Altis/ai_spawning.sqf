/*
call compile preprocessFileLineNumbers "ai_spawning.sqf";

TODO: evaluate https://github.com/CBATeam/CBA_A3/blob/master/addons/ai/fnc_taskPatrol.sqf

*/
//------------------------------------------------------------------------------
//This "if" makes sure that it gets executed on HC if available, otherwise only on server
if ((isNil "hc" && !isServer) || (!isNil "hc" && (isServer || hasInterface))) exitWith {};
//------------------------------------------------------------------------------
private _garrison_data = [
	//radius min-max,  number of ai
	[0,   100,         2],
	[100, 350,         3]
];
private _marker_prefix = "marker_ai";

//vars for fnc_patrol:
//TODO do we want this blacklist "global"?
private _blacklist = [];
private _bl_radius = 40;

//vars for enemies:
private _enemy_side = opfor; //west, blufor; east, opfor; resistance, independent; civilian
private "_enemy_classes";
//_enemy_classes = ["B_Soldier_lite_F","B_Soldier_F"]; // NATO
//_enemy_classes = ["O_Soldier_lite_F","O_Soldier_F"]; // CSAT
//_enemy_classes = ["I_Soldier_lite_F","I_Soldier_F"]; // AAF
//_enemy_classes = ["B_G_Soldier_lite_F", "B_G_Soldier_F"]; // FIA BLUFOR
_enemy_classes = ["O_G_Soldier_lite_F", "O_G_Soldier_F"]; // FIA OPFOR
//_enemy_classes = ["B_T_Soldier_F"]; // NATO Pacific
//_enemy_classes = ["O_T_Soldier_F"]; // CSAT Pacific
//_enemy_classes = ["I_C_Soldier_Para_1_F","I_C_Soldier_Para_2_F","I_C_Soldier_Para_7_F"]; // Syndikat Paramilitary
//_enemy_classes = ["I_C_Soldier_Bandit_4_F","I_C_Soldier_Bandit_7_F","I_C_Soldier_Bandit_5_F"]; // Syndikat Bandit

//------------------------------------------------------------------------------
if (is3DEN) then {
	call compile preprocessFileLineNumbers "common.sqf";

	f_param_number_of_ai = 3;

	f_param_debugMode = 0;
	if (isNil "things") then {
		//things = nearestObjects [[25000,22000,0], ["I_supplyCrate_F"], 4500];
		f_param_debugMode = 0;
		f_param_fakemarkers              = 0;
		f_param_number_of_objectives     = 0;
		f_param_objectives_configuration = 2;
		call compile preprocessFileLineNumbers "objectives.sqf";
	};
	f_param_debugMode = 1;

	objectives = things;
	objectives = [];
	//only take 1/4th, because plotting all of them is overkills
	{
		if (_forEachIndex % 4 == 0) then {
			objectives pushBack _x;
		};
	} forEach things;
	//objectives = nearestObjects [[22500,20000,0], ["I_supplyCrate_F"], 4500];

	{deleteMarker _x;} forEach (["marker_","SHK_patrol"] call ws_fnc_collectMarkers);
};
//------------------------------------------------------------------------------
fnc_patrol = {
	//based on BIS_fnc_taskPatrol and patrol script from darkChozo's fa3_c56_lumberjacked
	params ["_objective_pos", "_group", ["_distance",100], ["_num_waypoints",5], ["_position",[]], ["_timeout",[0,5,10]], ["_max_dist_multiplier",2.8]];

	if (count _position == 0) then {
		_position = position leader _group;
	};

	_blacklist pushback [_position getPos [_bl_radius,315], _position getPos [_bl_radius,135]];

	private _wp_pos = [];
	for "_i" from 1 to _num_waypoints do {
		//change position of previous wp so that the next one isn't as far away, if the previous one was too far away
		if (count _wp_pos > 0) then {
			if ((_wp_pos distance2d _objective_pos) > _distance * _max_dist_multiplier) then {
				_position = (_objective_pos vectorAdd _wp_pos) vectorMultiply 0.5;
				if (is3DEN) then {
					[_wp_pos, _marker_prefix, "", "mil_dot", "ColorGrey"] call fnc_marker;
				};
			};
		};

		private _num_tries = 0;
		_wp_pos = [];
		while {(count _wp_pos) == 0 && _num_tries < 10} do {
			_num_tries = _num_tries + 1;
			private _max_dist = _distance + _num_tries * 5;
			private _wp_pos_new = [_position, _distance*0.7, _max_dist, 0, 0, 0, 0, _blacklist] call BIS_fnc_findSafePos;
			if ( (_position distance _wp_pos_new < (_max_dist + 10)) && !(surfaceIsWater _wp_pos_new) ) then {
				//distance check because findSafePos could fail
				_wp_pos = _wp_pos_new;
				_blacklist pushback [_wp_pos getPos [_bl_radius,315], _wp_pos getPos [_bl_radius,135]];
			};
		};
		//stupid waypoint calculation if the fancy thing fails.
		if (count _wp_pos == 0) then {
			//TODO: position might be in water
			_wp_pos = _position getPos [_distance, random 359];
		};
		if (count _wp_pos < 3) then {
			//because sometimes it's only [x,y] which makes a lot of vector functions fail
			_wp_pos pushBack 0;
		};

		private _wp = _group addWaypoint [_wp_pos, 0];
		_wp setWaypointBehaviour "SAFE";
		_wp setWaypointTimeout _timeout;
		_wp setWaypointCompletionRadius 20;
		_position = waypointPosition _wp;
	};
	private _wp = _group addWaypoint [position leader _group,0];
	_wp setWaypointType "CYCLE";
	_wp setWaypointTimeout _timeout;
	_wp setWaypointCompletionRadius 20;
};
//------------------------------------------------------------------------------
fnc_spawn_group = {
	//TODO: check if it's in water?

	//_position can be a marker,object,group or position
	//_min and _max_distance = radius where to spawn group, if no position found max_distance will be increaesed
	//returns _grp_pos if is3DEN
	params ["_position","_side","_unit_types","_number_of_units",["_min_distance",0],["_max_distance",20]];

	private _grp_pos = [];
	while {count _grp_pos == 0} do {
		//If we remove the vehicle type here, then groups can also spawn in buildings!
		_grp_pos = _position findEmptyPosition [_min_distance, _max_distance, "B_Quadbike_01_F"];
		_max_distance = _max_distance + 50;
	};

	private _unit_types_actual = [];
	for "_i" from 1 to _number_of_units do {
		_unit_types_actual pushBack (selectRandom _unit_types);
	};
	_grp = [_grp_pos, _side, _unit_types_actual, [], [], [0.3,0.4], [], [_number_of_units, 0], random 359] call BIS_fnc_spawnGroup;

	//returning group
	_grp
};
//------------------------------------------------------------------------------
//add garrison to objectives
private _garrison_units = [];
private _garrison_max_size = 0;
{
	private _obj = _x;
	{
		private _size_min = _x select 0;
		private _size     = _x select 1;
		private _num_ai   = _x select 2;
		if (is3DEN) then {
			[_obj, _marker_prefix, format["garrison_%1",_forEachIndex], "ELLIPSE", "ColorBlack", [_size, _size], 0.3] call fnc_marker;
		};
		//note: if 4th parameter = 0, then there will be 1 ei per building. see line 108 in fn_createGarrison.sqf
		_garrison_units append ([_obj, _size, _enemy_side, _num_ai, 0.4, _enemy_classes, _size_min] call ws_fnc_createGarrison);

		_garrison_max_size = _garrison_max_size max _size;
	} forEach _garrison_data;
} forEach objectives;

//debug marker and removing units
if (is3DEN) then {
	{
		//[_x, _marker_prefix, "garrison", "ELLIPSE", "ColorBlue", [5, 5]] call fnc_marker;
		[_x, _marker_prefix, "garrison", "mil_dot", "ColorBlue", [1, 1]] call fnc_marker;

		private _grp = group _x;
		deleteVehicle _x;
		deleteGroup _grp; //only works if no more units in group.
	} forEach _garrison_units;

	//reset building variables:
	if (f_param_debugMode == 1) then {
		{
			private _buildings = [_x, _garrison_max_size, true, false] call ws_fnc_collectBuildings;
			{
				//_bpa = _x getVariable "ws_bPos";
				_x setVariable ["ws_bPosLeft", nil];
				_x setVariable ["ws_bUnits",   nil];
				//_x setVariable ["ws_bPos",     nil];
			} forEach _buildings;
		} forEach objectives;
	};
};
//------------------------------------------------------------------------------
//if(true)exitWith{systemChat "DEBUG: EXITING: TODO";};
//------------------------------------------------------------------------------
//PATROLS per objective:
private _patrol_configs = [
	//1-2. initial spawn distance min/max.
	//3-4. number of units min-max
	//5.   patrol: max distance between waypoints. (or distance of circle for shk_patrol)
	//6.   patrol: number of waypoints. or 0 if you want to use shk_patrol
	[ 5,  70,   2, 2,   120, 3 ],
	[20, 200,   3, 5,   400, 0 ],
	[20, 200,   3, 5,   180, 5 ]
];
private _patrols_per_objective = f_param_number_of_ai;
private _patrol_units = [];
{
	private _objective_pos = position _x;
	private _groups_for_this_objective = [];
	private _color = dbg_colors select ( _forEachIndex % (count dbg_colors)); //color per objective
	for "_j" from 1 to _patrols_per_objective do {

		//logic for selecting from _patrol_configs
		private _patrol_config = switch (true) do {
			case (_j == 1): { _patrol_configs select 0 };
			case (_j == 2): { _patrol_configs select 1 };
			case (true):    { _patrol_configs select 2 };
		};
		private _dist_min = _patrol_config select 0;
		private _dist_max = _patrol_config select 1;
		private _grp_size = (_patrol_config select 2) + round random ((_patrol_config select 3) - (_patrol_config select 2));
		private _wp_dist  = _patrol_config select 4;
		private _wp_num   = _patrol_config select 5;
		if(is3DEN)then{_grp_size = 1;};

		if (f_param_debugMode == 1 && !is3DEN) then {
			systemChat format ["Objective %1: Placing group %2/%3 (%4 units)", _forEachIndex, _j, _patrols_per_objective, _grp_size];
		};

		//create group
		private _grp = [_objective_pos, _enemy_side, _enemy_classes, _grp_size, _dist_min, _dist_max] call fnc_spawn_group;
		[_grp, "SAFE", "YELLOW"] call ws_fnc_setAIMode;

		//add waypoints to group
		if (_wp_num == 0) then {
			[_grp, _wp_dist, _objective_pos, _color] execVM "shk_patrol.sqf";
		} else {
			[_objective_pos, _grp, _wp_dist, _wp_num] call fnc_patrol;
		};

		_patrol_units append (units _grp);
		_groups_for_this_objective pushBack _grp;

		//debug marker and removing units
		if (is3DEN) then {
			private _wps = waypoints _grp;
			private _wp_pos_prev = nil;

			[leader _grp, _marker_prefix, format ["patrol_%1_%2", _forEachIndex, _j], "ELLIPSE", _color, [20, 20]] call fnc_marker;

			{
				//if(_forEachIndex + 1 != count _wps)then{
				//	[waypointposition _x, _marker_prefix, "patrol", "mil_box", "ColorBlack", [0.5,0.5], 1, 0, str _forEachIndex] call fnc_marker;
				//};
				if (!isNil "_wp_pos_prev") then {
					[_marker_prefix, waypointposition _x, _wp_pos_prev,_color,8] call fnc_draw_line;
				};
				_wp_pos_prev = waypointposition _x;
			} forEach _wps;

			//delete units
			{
				deleteVehicle _x;
			} forEach (units _grp);
			deleteGroup _grp;
		};

	};
	_x setVariable ["groups", _groups_for_this_objective, true];
} forEach objectives;
//------------------------------------------------------------------------------
if(!is3DEN)then{
	[_patrol_units,   "f\setAISkill\f_setAISkill.sqf"] remoteExec ["execVM", 2];
	[_garrison_units, "f\setAISkill\f_setAISkill.sqf"] remoteExec ["execVM", 2];

	//[_patrol_units,   "f\assignGear\f_assignGear_AI.sqf"] remoteExec ["execVM", 2];
	//[_garrison_units, "f\assignGear\f_assignGear_AI.sqf"] remoteExec ["execVM", 2];
};
//------------------------------------------------------------------------------
if(f_param_debugMode == 1 || is3DEN)then{
	systemChat "Initializing AI done.";
};
//------------------------------------------------------------------------------
1
