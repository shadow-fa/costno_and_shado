// F3 - Briefing
// Credits: Please see the F3 online manual (http://www.ferstaberinde.com/f3/en/)
// ====================================================================================

// FACTION: NATO

// ====================================================================================

_cre = player createDiaryRecord ["diary", ["Credits","
<br/>
Created by Shado. Lets be real. Costno did map ''design''
<br/><br/>
Made with F3 (http://www.ferstaberinde.com/f3/en/)
"]];

// ====================================================================================

// NOTES: ADMINISTRATION
// The code below creates the administration sub-section of notes.

_adm = player createDiaryRecord ["diary", ["Administration",format ["
<br/>
Bomb is in a backpack. T who is carrying bomb can plant it. Ts will plant and must defend bomb for %1 seconds.  Do not pick up the bomb as a CT!  
", f_param_time_to_explosion]]];

// ====================================================================================

// NOTES: MISSION
// The code below creates the mission sub-section of notes.

_mis = player createDiaryRecord ["diary", ["Mission",format ["
<br/>
<font size='18'>COMMANDER'S INTENT</font>
<br/>
Defend bombsite A and B at %1.<br/>
The bombsites may be marked with orange or white markers on the ground.<br/>
<br/><br/>
", _markername]]];

// ====================================================================================
