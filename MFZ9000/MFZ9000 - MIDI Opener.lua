--[[

MIDI FOCUS AND ZOOM 9000 v0.1

Opens the MIDI editor with consistent, user-defined measure-based horizontal zoom values,
and vertical zoom values. The horizontal zoom values can be changed per track (persistent).

Usage: bind this script to the keyboard key or a mouse action of your choosing
       for opening the MIDI items. Check the user settings below. Use the provided
       "MFZ9000 - Set zoom settings in MIDI editor.lua" script for user-based changes
       in the MIDI editor (NOT IN THE MAIN).

--]]

------------------- USER SETTINGS -------------------

change_measures_externally = true -- use the external script to change the settings,
                                  -- otherwise set to false and manually change the value below
measures_to_show = 4

vertical_zoom_level = 11 -- the script fully zooms out, and then zooms in *this* number of times

-----------------------------------------------------

-- calculates the midpoint of the notes in the loop
function calc_midpoint_pitch()
    local notes     = 0
    local sel       = 0
    local pitch     = 0
    local min_pitch = 127
    local max_pitch = 0
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    
    if take ~= nil then
        retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take) -- only notes is needed
    else
        return 60
    end
    
    local noteidx  = 0
    for i = notes, 1, -1 do
        -- selnotes = reaper.MIDI_EnumSelNotes(take, noteidx)
        retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, noteidx) -- only pitch and selected are needed
        
        if selected == true then
            if pitch > max_pitch then
                max_pitch = pitch
            end
            
            if pitch < min_pitch then
                min_pitch = pitch
            end
        end
        
        -- reaper.ShowConsoleMsg("min_pitch: " .. tostring(min_pitch) .. "| max_pitch: " .. 
                              -- tostring(max_pitch) .. "| pitch: " .. tostring(pitch) .. "\n") 
        -- reaper.ShowConsoleMsg("\nselected: " .. tostring(selected))
        noteidx  = noteidx +1
    end
    
    local midpoint_pitch = math.floor((min_pitch + max_pitch) / 2)
    -- reaper.ShowConsoleMsg("\n\nmidpoint_pitch: " .. tostring(midpoint_pitch) .. " | noteidx: " .. tostring(noteidx))
    
    return midpoint_pitch
end

-- shifts the pitch cursor up/down to a new note (the passed value)
function shift_pitch_cursor(new_pitch_cursor_value)
    local pitch_cursor_shift
    local pitch_cursor_direction
    
    -- calculate the direction and the shift amount
    if new_pitch_cursor_value > 60 then
        pitch_cursor_shift = new_pitch_cursor_value - 60
        pitch_cursor_direction = 1
    else
        pitch_cursor_shift = 60 - new_pitch_cursor_value
        pitch_cursor_direction = -1
    end
    
    -- move the pitch cursor
    for i = pitch_cursor_shift, 1, -1 do
        if pitch_cursor_direction == 1 then
            reaper.MIDIEditor_OnCommand(ed, 40049) -- increase pitch cursor one semitone
            -- reaper.ShowConsoleMsg("\npitch cur up")
        else
            reaper.MIDIEditor_OnCommand(ed, 40050) -- decrease pitch cursor one semitone
            -- reaper.ShowConsoleMsg("\npitch cur down")
        end
    end
end

-- changes the time selection in the main window to cover the passed
-- amount of measures from the edit cursor to the right
function set_time_selection_to_n_measures(measures)
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
end

-- gets the track number of the passed item
function get_track_no_of_item(item)
    local selected_item = reaper.MIDIEditor_GetTake(item)
    selected_item = reaper.GetMediaItemTake_Item(selected_item)
    selected_item = reaper.GetMediaItemTrack(selected_item)
    
    return math.floor((reaper.GetMediaTrackInfo_Value(selected_item, "IP_TRACKNUMBER")))
end

-- unzooms fully and then uses the zoom in action to zoom in zoom_level of times
function zoom_vertically(zoom_level)
    reaper.MIDIEditor_OnCommand(ed, 41297) -- move pitch cursor to C4 (60)
    reaper.MIDIEditor_OnCommand(ed, 40746) -- select all notes in time selection
    shift_pitch_cursor(calc_midpoint_pitch(), ed)
    reaper.MIDIEditor_OnCommand(ed, 40214) -- unselect all
    
    for i = 128, 0, -1 do
        reaper.MIDIEditor_OnCommand(ed, 40112) -- zoom out vertically
    end
    
    for i = zoom_level, 0, -1 do
        reaper.MIDIEditor_OnCommand(ed, 40111) -- zoom in vertically
    end
end

-- zooms horizontally to show n measures
function zoom_horizontally()
    local _40621_flag = reaper.GetToggleCommandState(40621) -- toggle loop points linked to time selection
    
    -- we need to enable this option and then disable again later
    if _40621_flag == 0 then
        reaper.Main_OnCommand(40621, 0) -- toggle loop points linked to time selection
    end
    
    reaper.MIDIEditor_OnCommand(ed, 40726) -- zoom to project loop selection
    
    if _40621_flag == 0 then
       reaper.Main_OnCommand(40621, 0) -- toggle loop points linked to time selection
    end
end

------------------------- MAIN ------------------------
reaper.PreventUIRefresh(1)

reaper.Main_OnCommand(40153, 0) -- open midi editor
ed = reaper.MIDIEditor_GetActive() -- ed is global

-- save old loop and time selection settings
old_loop_start, old_loop_end = reaper.GetSet_LoopTimeRange2(0, false, true, 0, 0, false)
old_ts_start, old_ts_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

-- init the measure setting
if change_measures_externally == true then
    if reaper.GetExtState("mfz9000", "def_measures") == "" then
        reaper.SetExtState("mfz9000", "def_measures", measures_to_show, true)
    end
    
    -- change the measure zoom to either default or track-based
    local track_measures_key = "track-measures_" .. get_track_no_of_item(reaper.MIDIEditor_GetActive())
    local str_track_whichzoom_key = "track-whichzoom_" .. get_track_no_of_item(reaper.MIDIEditor_GetActive())
    local _, track_whichzoom = reaper.GetProjExtState(0, "mfz9000", str_track_whichzoom_key)
    
    if track_whichzoom == "" then
        measures_to_show = reaper.GetExtState("mfz9000", "def_measures")
    else
        track_whichzoom = tonumber(track_whichzoom)
        if track_whichzoom == 1 then
            _, measures_to_show = reaper.GetProjExtState(0, "mfz9000", track_measures_key)
        else
            measures_to_show = reaper.GetExtState("mfz9000", "def_measures")
        end
    end
    
    measures_to_show = tonumber(measures_to_show)
end

set_time_selection_to_n_measures(measures_to_show)
zoom_horizontally()
zoom_vertically(vertical_zoom_level)

-- restore old loop and time selection
reaper.GetSet_LoopTimeRange2(0, true, true, old_loop_start, old_loop_end, false)
reaper.GetSet_LoopTimeRange2(0, true, false, old_ts_start, old_ts_end, false)
    
reaper.PreventUIRefresh(-1)
