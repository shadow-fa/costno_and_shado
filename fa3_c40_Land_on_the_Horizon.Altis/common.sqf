
dbg_colors = [
	"ColorBlack",  "ColorGrey",    "ColorRed",    "ColorBrown",  "ColorOrange",
	"ColorYellow", "ColorKhaki",   "ColorGreen",  "ColorBlue",   "ColorPink",
	"ColorCIV",    "ColorUNKNOWN", "ColorWEST",   "ColorEAST",   "ColorGUER",
	"Color1_FD_F", "Color2_FD_F",  "Color3_FD_F", "Color4_FD_F", "Color5_FD_F"
];
//fnc_get_color = {
//	select (_this % (count dbg_colors));
//};

fnc_min_max = {
	private _tmp = +_this;
	_tmp sort true;
	[_tmp select 0, _tmp select (count _tmp - 1)]
};

fnc_marker = {
	params ["_pos_or_object", ["_prefix1",""], ["_prefix2",""], ["_shape_type","ELLIPSE"], ["_color","ColorBlack"], ["_size",[1,1]], ["_alpha",1.0], ["_dir",0], ["_text",""]];

	private _mkr = format ["%1_%2_%3", _prefix1, _prefix2, _pos_or_object];
	deleteMarker _mkr;
	_mkr = createMarker [_mkr, _pos_or_object];

	if (_shape_type in ["ICON", "RECTANGLE", "ELLIPSE", "POLYLINE"]) then {
		_mkr setMarkerShape _shape_type;
	} else {
		_mkr setMarkerType _shape_type;
	};
	_mkr setMarkerSize _size;
	_mkr setMarkerColor _color;
	_mkr setMarkerAlpha _alpha;
	_mkr setMarkerDir _dir;
	_mkr setMarkerText _text;

	_mkr
};

fnc_draw_line = {
	params ["_prefix", "_pos1", "_pos2",["_color", "ColorGrey"],["_thickness",10],["_show_distances",false]];
	if (typename _pos1 == "OBJECT") then { _pos1 = position _pos1; };
	if (typename _pos2 == "OBJECT") then { _pos2 = position _pos2; };

	if (count _pos1 < 3) then { _pos1 pushBack 0; };
	if (count _pos2 < 3) then { _pos2 pushBack 0; };

	private _distance = _pos1 distance _pos2;
	private _marker_pos = [(_pos1 select 0) / 2 + (_pos2 select 0) / 2, (_pos1 select 1) / 2 + (_pos2 select 1) / 2, 0];

	private _mkr = format ["%1_%2_%3_distance_%4", _prefix, _pos1, _pos2, _distance];
	deleteMarker _mkr;
	_mkr = createMarker [_mkr, _marker_pos];
	_mkr setMarkerShape "RECTANGLE";
	_mkr setMarkerSize [_distance / 2, _thickness];
	_mkr setMarkerColor _color;

	private _delta = _pos1 vectorDiff _pos2;
	private _degree = (_delta select 1) atan2 (_delta select 0);
	_mkr setMarkerDir (360 - _degree);

	if(_show_distances)then{
		//marker for distances between objectives
		_mkr = format["%1__str", _mkr];
		_mkr = createMarker [_mkr, _marker_pos];
		_mkr setMarkerType "mil_box";
		_mkr setMarkerColor _color;
		_mkr setMarkerSize [0.1, 0.1];
		_mkr setMarkerText format ["%1", _distance];
	};
};

if(is3DEN)then{
	//compile ws_fnc functions:
	ws_game_a3 = false;
	call compile preprocessFileLineNumbers "ws_fnc\ws_fnc_init.sqf";
	ws_game_a3 = true;
	/*
	replaces this:
	ws_fnc_collectObjectsNum = compile preprocessFileLineNumbers "ws_fnc\Tools\fn_collectObjectsNum.sqf";
	ws_fnc_collectMarkers = compile preprocessFileLineNumbers "ws_fnc\Tools\fn_collectMarkers.sqf";
	...
	*/
};
