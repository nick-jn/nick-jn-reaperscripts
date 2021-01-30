local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"

require("constants")

-- calculates the midpoint of the **SELECTED** notes in the loop
function __calc_midpoint_pitch_of_selected_notes(active_midi_editor) -- RET: integer
    local notes     = 0
    local sel       = 0
    local pitch     = 0
    local min_pitch = 127
    local max_pitch = 0
    local take = reaper.MIDIEditor_GetTake(active_midi_editor)
    
    if take ~= nil then
        retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take) -- only notes is needed
    else
        return 60
    end
    
    local noteidx  = 0
    for i = notes, 1, -1 do
        -- selnotes = reaper.MIDI_EnumSelNotes(take, noteidx)
        local retval, selected, muted, startppqpos,
              endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, noteidx) -- only pitch and selected are needed
        
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

-- gets the track number of the passed item in the **ACTIVE MIDI EDITOR**
function __get_track_no_of_item_in_active_midi_editor(active_midi_editor) -- RET: integer
    local selected_item = reaper.MIDIEditor_GetTake(active_midi_editor)
    
    selected_item = reaper.GetMediaItemTake_Item(selected_item)
    selected_item = reaper.GetMediaItemTrack(selected_item)
    
    return math.floor((reaper.GetMediaTrackInfo_Value(selected_item, "IP_TRACKNUMBER")))
end

-- gets the required the ext state from the project
function __get_proj_extstate(str_key, var1) -- RET: string
    if     str_key == __KEYSTR_TRACKMES then
        str_key = str_key .. tostring(var1)
    elseif str_key == __KEYSTR_WZOOM then
        str_key = str_key .. tostring(var1)
    else
        return nil
    end
    
    local _, ret = reaper.GetProjExtState(0, "mfz9000", str_key)
    
    return ret
end

-- sets the required the ext state from the project
function __set_proj_extstate(str_key, var1, state_value) -- RET: void
    if     str_key == __KEYSTR_TRACKMES then
        str_key = str_key .. tostring(var1)
    elseif str_key == __KEYSTR_WZOOM then
        str_key = str_key .. tostring(var1)
    end
    
    reaper.SetProjExtState(0, "mfz9000", str_key, state_value)
end

-- ts == time selection, lp == loop, 1 == start, 2 == end
function __save_time_and_loop_selection() -- RET: ordered array of time selection and loop start and end values
    local ts1, ts2 = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    local lp1, lp2 = reaper.GetSet_LoopTimeRange2(0, false, true, 0, 0, false)
    
    return {ts1, ts2, lp1, lp2}
end

-- ts == time selection, lp == loop, 1 == start, 2 == end
function __set_time_and_loop_selection(array_of_values) -- RET: void
    local ts1 = array_of_values[1]
    local ts2 = array_of_values[2]
    local lp1 = array_of_values[3]
    local lp2 = array_of_values[4]

    reaper.GetSet_LoopTimeRange2(0, true, false, ts1, ts2, false)
    reaper.GetSet_LoopTimeRange2(0, true, true, lp1, lp2, false)
end
