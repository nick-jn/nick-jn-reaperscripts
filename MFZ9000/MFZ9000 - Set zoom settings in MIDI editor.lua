-- For use with "MFZ9000 open MIDI item" only.
-- For use in MIDI editor only.

--[[

MIDI FOCUS AND ZOOM 9000 v0.1.1

--]]

-- gets the track number of the passed item
function get_track_no_of_item(item)
    local selected_item = reaper.MIDIEditor_GetTake(item)
    selected_item = reaper.GetMediaItemTake_Item(selected_item)
    selected_item = reaper.GetMediaItemTrack(selected_item)
    
    return math.floor((reaper.GetMediaTrackInfo_Value(selected_item, "IP_TRACKNUMBER")))
end

-- parses the user input, if it's correct, true is returned, otherwise false
function parse_input(str_input, input_amount)
    for token in string.gmatch(str_input, "[^,]+") do
        -- reaper.ShowConsoleMsg(token .. "\n")
        if input_amount == 0 then
            reaper.MB("Bad input.", "Error", 0)
            return false
        end
        
        if token:match("%d") == nil then
            reaper.MB("Not a number: " .. token, "Error", 0)
            return false
        end
        
        -- horrible, the whole loop needs a rewrite
        if input_amount == 1 and (tonumber(token) ~= 1 and tonumber(token) ~= 0) then
            reaper.MB("0 == no, 1 == yes.", "Error", 0)
            return false
        end
        
        if input_amount ~= 1 and tonumber(token) < 1 then
            reaper.MB("Number less than 1.", "Error", 0)
            return false
        end
        
        if tonumber(token) > 256 then
            reaper.MB("Number larger than 256.", "Error", 0)
            return false
        end
        
        input_amount = input_amount - 1
    end
    
    return true
end

-- CURRENTLY COPY-PASTED FROM THE ZOOM FILE
function rezoom_horizontally(measures)
    reaper.PreventUIRefresh(1)
    
    -- save old loop and time selection settings
    local old_loop_start, old_loop_end = reaper.GetSet_LoopTimeRange2(0, false, true, 0, 0, false)
    local old_ts_start, old_ts_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    
    local _40621_flag = reaper.GetToggleCommandState(40621) -- toggle loop points linked to time selection
    if _40621_flag == 0 then
        reaper.Main_OnCommand(40621, 0) -- toggle loop points linked to time selection
    end
    
    -- set_time_selection_to_n_measures(measures)
    reaper.Main_OnCommand(40222, 0) -- set start loop point
    for i = measures, 1, -1 do
        reaper.Main_OnCommand(41042, 0) -- move edit cursor forward one measure
    end

    reaper.Main_OnCommand(40223, 0) -- set end loop point
    
    -- 40276: move edit cursor to start on time selection change, so if it's
    -- on, we don't need to move the cursor back
    if reaper.GetToggleCommandState(40276) == 0 then
        for i = measures, 1, -1 do
            reaper.Main_OnCommand(41043, 0) -- move edit cursor back one measure
        end
    end
    ---------------------------------------------
    
    reaper.MIDIEditor_OnCommand(ed, 40726) -- zoom to project loop selection
    
    if _40621_flag == 0 then
        reaper.Main_OnCommand(40621, 0) -- toggle loop points linked to time selection
    end
    
    -- restore old loop and time selection
    reaper.GetSet_LoopTimeRange2(0, true, true, old_loop_start, old_loop_end, false)
    reaper.GetSet_LoopTimeRange2(0, true, false, old_ts_start, old_ts_end, false)
        
end

-- will restore focus to MIDI editor if SWS is installed
function restore_focus_SWS()
    local cmd = reaper.NamedCommandLookup("_SN_FOCUS_MIDI_EDITOR")
    if cmd ~= 0 then
        reaper.Main_OnCommand(cmd, 0)
    end
end

--------------------- MAIN ------------------------
ed = reaper.MIDIEditor_GetActive() -- ed is global
if ed == nil then
    reaper.MB("Must be run in the MIDI editor.", "Error", 0)
    return
end

if reaper.GetExtState("mfz9000", "def_measures") == "" then
    reaper.MB("Default MFZ measure value not found. Set \"change_measures_externally = true\" in the main script.", "Error", 0)
    return
end

local str_trackno = tostring(get_track_no_of_item(reaper.MIDIEditor_GetActive()))
local str_def_measures = reaper.GetExtState("mfz9000", "def_measures")
local str_track_measures_key = "track-measures_" .. get_track_no_of_item(reaper.MIDIEditor_GetActive())
local str_track_whichzoom_key = "track-whichzoom_" .. get_track_no_of_item(reaper.MIDIEditor_GetActive())


local _, track_whichzoom = reaper.GetProjExtState(0, "mfz9000", str_track_whichzoom_key)
if track_whichzoom == "" then
    track_whichzoom = 0
end

local _, str_curtrack_measures = reaper.GetProjExtState(0, "mfz9000", str_track_measures_key)
if str_curtrack_measures == "" then
    str_curtrack_measures = reaper.GetExtState("mfz9000", "def_measures")
end
-- reaper.ShowConsoleMsg("str_track_measures_key: " .. str_track_measures_key .. "\n")
-- reaper.ShowConsoleMsg("str_curtrack_measures: " .. str_curtrack_measures .. "\n")

-- gets the user input for default measure values and for the current track
local retval, retvals_cr
local input_amount = 3
retval, retvals_csv = reaper.GetUserInputs("MFZ9000 setup", input_amount,
"Default number of measures:,Tracks` no. of measures:,Prefer tracks` measure value:", -- text
str_def_measures .. "," .. str_curtrack_measures .. "," .. track_whichzoom) -- textbox values

if retval == false then
    restore_focus_SWS()
    return
end

-- change the zoom values to user-input values
if parse_input(retvals_csv, input_amount) == true then
    local i = 1
    for token in string.gmatch(retvals_csv, "[^,]+") do
        -- reaper.ShowConsoleMsg("Final value " .. tostring(i) .. ": " .. token .. "\n")
        -- change default measure value
        if i == 1 then
            reaper.SetExtState("mfz9000", "def_measures", math.floor(tonumber(token)), true)
        end
        
        -- change current track measure value
        if i == 2 then
            reaper.SetProjExtState(0, "mfz9000", str_track_measures_key, math.floor(tonumber(token)))
        end
        
        -- change the measure value preference (default or current track)
        if i == 3 then
            reaper.SetProjExtState(0, "mfz9000", str_track_whichzoom_key, math.floor(tonumber(token)))
        end
        
        i = i+1
    end
end

local measures = tonumber(reaper.GetExtState("mfz9000", "def_measures"))

-- also a rewrite
 _, track_whichzoom = reaper.GetProjExtState(0, "mfz9000", str_track_whichzoom_key)
if tonumber(track_whichzoom) == 1 then
    _, measures = reaper.GetProjExtState(0, "mfz9000", str_track_measures_key)
    measures = tonumber(measures)
end

reaper.PreventUIRefresh(1)
rezoom_horizontally(measures)
reaper.PreventUIRefresh(-1)
restore_focus_SWS()

-- reaper.ShowConsoleMsg("\nCurrent def mes value: " .. reaper.GetExtState("mfz9000", "def_measures"))
-- reaper.ShowConsoleMsg("\nCurrent track mes value: " .. reaper.GetExtState("mfz9000", "track-measures_"  .. str_trackno))
