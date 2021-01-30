local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"

require("constants")

-- shifts the pitch cursor up/down to a new note (the passed value)
function shift_pitch_cursor(active_midi_editor, new_pitch_cursor_value) -- RET: void
    local pitch_cursor_direction
    local pitch_cursor_shift = math.abs(new_pitch_cursor_value - 60)
    
    reaper.MIDIEditor_OnCommand(active_midi_editor, 41297) -- move pitch cursor to C4 (60)
    
    -- calculate the direction and the shift amount
    if new_pitch_cursor_value > 60 then
        pitch_cursor_direction = 1
    else
        pitch_cursor_direction = -1
    end
    
    -- move the pitch cursor
    for i = pitch_cursor_shift, 1, -1 do
        if pitch_cursor_direction == 1 then
            reaper.MIDIEditor_OnCommand(active_midi_editor, 40049) -- increase pitch cursor one semitone
            -- reaper.ShowConsoleMsg("\npitch cur up")
        else
            reaper.MIDIEditor_OnCommand(active_midi_editor, 40050) -- decrease pitch cursor one semitone
            -- reaper.ShowConsoleMsg("\npitch cur down")
        end
    end
end

-- changes the time selection in the main window to cover the passed
-- amount of measures from the edit cursor to the right
function set_time_selection_to_n_measures(measures) -- RET: saved time and loop selections as array of values
    local saved_ts_lp = __save_time_and_loop_selection()
    local _40621_state = reaper.GetToggleCommandState(40621) -- toggle loop points linked to time selection
    
    if _40621_state == 0 then
        reaper.Main_OnCommand(40621, 0) -- toggle loop points linked to time selection
    end
    
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
    
    if _40621_state == 0 then
        reaper.Main_OnCommand(40621, 0) -- toggle loop points linked to time selection
    end

    return saved_ts_lp
end

-- unzooms fully and then uses the zoom in action to zoom in zoom_level of times
-- measures required because "set_time_selection_to_n_measures" will be called
function zoom_vertically(active_midi_editor, zoom_level, measures, redo_time_selection) -- RET: void
    if redo_time_selection == true then
        local saved_ts_lp = set_time_selection_to_n_measures(measures)
    end
    
    reaper.MIDIEditor_OnCommand(active_midi_editor, 40746) -- select all notes in time selection
    shift_pitch_cursor(active_midi_editor, __calc_midpoint_pitch_of_selected_notes(active_midi_editor))
    reaper.MIDIEditor_OnCommand(active_midi_editor, 40214) -- unselect all
    
    for i = __VER_ZOOM_OUT_MAX, 0, -1 do
        reaper.MIDIEditor_OnCommand(active_midi_editor, 40112) -- zoom out vertically
    end
    
    for i = zoom_level, 0, -1 do
        reaper.MIDIEditor_OnCommand(active_midi_editor, 40111) -- zoom in vertically
    end
    
    if redo_time_selection == true then
        __set_time_and_loop_selection(saved_ts_lp)
    end
end
