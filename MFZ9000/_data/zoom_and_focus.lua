local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"

require("constants")

-- shifts the pitch cursor up/down to a new note (the passed value), returns 1 if the pitch
-- cursor is above or at C60, -1 if below
function shift_pitch_cursor(active_midi_editor, new_pitch_cursor_value) -- RET: integer
    local pitch_cursor_direction
    local target_note = new_pitch_cursor_value % 12
    -- offset by 5 to get into F# <-> F# range (F#-shifted octave), subtract 5 to offset the starting octave (C4, the 5th)
    local octave_shift = math.abs(math.floor((new_pitch_cursor_value + 5) / 12) - 5)
    local shift_func_table = {
        reaper.MIDIEditor_OnCommand, --  1 | move pitch cursor to nearest C (41094)
        reaper.MIDIEditor_OnCommand, --  2 | move pitch cursor to nearest C#
        reaper.MIDIEditor_OnCommand, --  3 | move pitch cursor to nearest D
        reaper.MIDIEditor_OnCommand, --  4 | move pitch cursor to nearest D#
        reaper.MIDIEditor_OnCommand, --  5 | move pitch cursor to nearest E
        reaper.MIDIEditor_OnCommand, --  6 | move pitch cursor to nearest F
        reaper.MIDIEditor_OnCommand, --  7 | move pitch cursor to nearest F#
        reaper.MIDIEditor_OnCommand, --  8 | move pitch cursor to nearest G
        reaper.MIDIEditor_OnCommand, --  9 | move pitch cursor to nearest G#
        reaper.MIDIEditor_OnCommand, -- 10 | move pitch cursor to nearest A
        reaper.MIDIEditor_OnCommand, -- 11 | move pitch cursor to nearest A#
        reaper.MIDIEditor_OnCommand  -- 12 | move pitch cursor to nearest B
    }

    reaper.MIDIEditor_OnCommand(active_midi_editor, 41297) -- move pitch cursor to C4 (60)

    -- calculate the direction and the shift amount
    if new_pitch_cursor_value >= 66 then -- 66 == F#4
        pitch_cursor_direction = 1
        if new_pitch_cursor_value > 126 then
            octave_shift = octave_shift - 1 -- no octave (F#-shifted) above F#9
        end
    elseif new_pitch_cursor_value <= 54 then -- 54 == F#3
        pitch_cursor_direction = -1
        if new_pitch_cursor_value <= 6 then
            octave_shift = octave_shift - 1 -- no octave (F#-shifted) below F#-1
        end
    else
        pitch_cursor_direction = 0
    end

    -- move the pitch cursor to the correct octave (F#-shifted)
    if pitch_cursor_direction == 1 then
        for i = octave_shift, 1 , -1 do
            reaper.MIDIEditor_OnCommand(active_midi_editor, 40187) -- increase pitch cursor one octave
        end
    elseif pitch_cursor_direction == -1 then
        for i = octave_shift, 1 , -1 do
            reaper.MIDIEditor_OnCommand(active_midi_editor, 40188) -- decrease pitch cursor one octave
        end
    end

    -- move the pitch cursor to the correct note within the octave (F#-shifted)
    if new_pitch_cursor_value == 127 then
        for i = new_pitch_cursor_value - 1, 120, -1 do -- 120 == C-9 note
            reaper.MIDIEditor_OnCommand(active_midi_editor, 40049) -- increase pitch cursor one semitone
        end
    elseif new_pitch_cursor_value <= 6 then
        for i = 12, new_pitch_cursor_value + 1, -1 do -- 12 == C-1 note
            reaper.MIDIEditor_OnCommand(active_midi_editor, 40050) -- decrease pitch cursor one semitone
        end
    else
        shift_func_table[target_note + 1](active_midi_editor, target_note + 41094)
    end

    -- reaper.ShowConsoleMsg("\nnew_pitch_cursor_value note: " .. new_pitch_cursor_value)
    -- reaper.ShowConsoleMsg("\ntarget note+1 (mod): " .. target_note+1 .. " | octave shift: " .. octave_shift)

    return pitch_cursor_direction
end

-- changes the time selection in the main window to cover the passed
-- amount of measures from the edit cursor to the right
function set_time_selection_to_n_measures(active_midi_editor, measures) -- RET: saved time and loop selections as array of values
    local saved_ts_lp = __save_time_and_loop_selection()
    local take = reaper.MIDIEditor_GetTake(active_midi_editor)
    local media_item = reaper.GetMediaItemTake_Item(take)
    -- time values in seconds
    local length   = reaper.GetMediaItemInfo_Value(media_item, "D_LENGTH")
    local startpos = reaper.GetMediaItemInfo_Value(media_item, "D_POSITION")
    local endpos   = startpos + length
    local edcurpos = reaper.GetCursorPosition()

    __get_and_set_user_configuration()

    qn_item_length   = __round_qn_value(reaper.TimeMap2_timeToQN(0, length))
    qn_item_startpos = __round_qn_value(reaper.TimeMap2_timeToQN(0, startpos))
    qn_item_endpos   = __round_qn_value(reaper.TimeMap2_timeToQN(0, endpos))
    qn_edcurpos      = __round_qn_value(reaper.TimeMap2_timeToQN(0, edcurpos))

    -- reaper.ShowConsoleMsg("\nROUNDED VALS\nqn_item_length: " .. qn_item_length .. "\nqn_item_startpos: ".. qn_item_startpos ..
    --                       "\nqn_item_endpos: " .. qn_item_endpos .. "\nqn_item_edcurpos: " .. qn_item_edcurpos)

    local measure_factor = 4 -- qn value of 4 equals one measure in 4/4
    local qn_sel_start   = qn_edcurpos
    local qn_sel_end     = qn_edcurpos + (measures * measure_factor)

    -- if the item is shorter than the number of measures shown
    if __USER_CENTER_SMALL_ITEMS == true and (qn_item_length / measure_factor) <= __USER_CENTER_SMALL_ITEMS_LENGTH then
        -- reaper.ShowConsoleMsg("if __USER_CENTER_SMALL_ITEMS == true and (qn_item_length / measure_factor) <= __USER_CENTER_SMALL_ITEMS_LENGTH\n")
        qn_sel_start = qn_item_startpos
        qn_sel_end   = qn_item_endpos
        -- pad the item
        if __USER_PAD_SMALL_ITEMS == true and
           (qn_item_length / measure_factor) >= 1 and (qn_item_length / measure_factor) <= 3.5 then
            qn_sel_start = qn_sel_start - 4
            qn_sel_end   = qn_sel_end   + 4
        end

        goto done
    end

    -- we click at the end of the item, we don't want to see the whole item on the screen,
    -- and we have satisfied the end threshold condition
    if __USER_ITEM_CLICKED_AT_END_OFFSET == true and __USER_SHOW_ONLY_THE_SELECTED_ITEM == false and
      (qn_item_endpos - qn_sel_start) <= (__USER_ITEM_CLICKED_AT_END_THRESHOLD * measure_factor) then
        -- reaper.ShowConsoleMsg("if __USER_ITEM_CLICKED_AT_END_OFFSET == true\n")
        if (qn_item_endpos - qn_sel_start) <= (__USER_ITEM_CLICKED_AT_END_THRESHOLD * measure_factor) then
            local qn_local_sel_start   = qn_sel_start
            local qn_local_item_endpos = qn_item_endpos
            for i = __USER_ITEM_CLICKED_AT_END_THRESHOLD, (qn_local_item_endpos - qn_local_sel_start) / measure_factor, -1 do
                qn_sel_start = qn_sel_start - 4
                qn_sel_end   = qn_sel_end   - 4
            end
        end

        goto done
    end

    -- if we overshoot with the selection end when we want to see the whole item on the screen
    if __USER_SHOW_ONLY_THE_SELECTED_ITEM == true and qn_sel_end > qn_item_endpos then
        -- reaper.ShowConsoleMsg("if __USER_SHOW_ONLY_THE_SELECTED_ITEM == true and qn_sel_end > qn_item_endpos\n")
        qn_sel_end = qn_item_endpos

        -- so that when we click at the last measures we get the correct amount of measures shown
        if (qn_item_endpos - qn_sel_start) < (measures * measure_factor) then
            qn_sel_start = qn_item_endpos - (measures * measure_factor)
        end

        -- we've overshot the selection start
        if qn_sel_start < qn_item_startpos then
            qn_sel_start = qn_item_startpos
        end

        goto done
    end

    ::done::
    new_ts_lp = {reaper.TimeMap_QNToTime(qn_sel_start), reaper.TimeMap_QNToTime(qn_sel_end),
                 reaper.TimeMap_QNToTime(qn_sel_start), reaper.TimeMap_QNToTime(qn_sel_end)}

    __set_time_and_loop_selection(new_ts_lp)

    return saved_ts_lp
end

-- unzooms fully and then uses the zoom in action to zoom in zoom_level of times
-- measures required because "set_time_selection_to_n_measures" will be called
function zoom_vertically(active_midi_editor, new_zoom_level, measures, redo_time_selection) -- RET: void
    local saved_ts_lp
    local pitch_cursor_direction
    local cur_zoom_level = __get_cfg_edit_view(active_midi_editor, __CFGEV_VZOOM)

    if redo_time_selection == true then
        saved_ts_lp = set_time_selection_to_n_measures(measures)
    end

    -- ensure new_zoom_level is within bounds
    if new_zoom_level <  __MIDI_EDITOR_VZOOM_MIN then
        new_zoom_level = __MIDI_EDITOR_VZOOM_MIN
    elseif new_zoom_level > __MIDI_EDITOR_VZOOM_MAX then
        new_zoom_level = __MIDI_EDITOR_VZOOM_MAX
    end

    -- reaper.ShowConsoleMsg("cur_zoom_level: " .. cur_zoom_level)
    reaper.MIDIEditor_OnCommand(active_midi_editor, 40746) -- select all notes in time selection
    pitch_cursor_direction = shift_pitch_cursor(active_midi_editor,
                                                __calc_midpoint_pitch_of_selected_notes(active_midi_editor))
    reaper.MIDIEditor_OnCommand(active_midi_editor, 40214) -- unselect all

    -- zoom all the way out
    for i = cur_zoom_level, __MIDI_EDITOR_VZOOM_MIN + 1, -1 do
        reaper.MIDIEditor_OnCommand(active_midi_editor, 40112)
    end

    for i = __MIDI_EDITOR_VZOOM_MIN, new_zoom_level - 1, 1 do
        reaper.MIDIEditor_OnCommand(active_midi_editor, 40111) -- zoom in vertically
    end
    -- reaper.ShowConsoleMsg("\nnew zoom level (from CFGEDITVIEW): " .. __get_cfg_edit_view(active_midi_editor, __CFGEV_VZOOM))

    -- hacky way to get around the issue of the viewport being off bounds vertically at low notes
    if pitch_cursor_direction == -1 then
        -- up first, then down, because if we're out of bounds, any scroll action
        -- will only refocus the viewport, it won't actually scroll
        reaper.MIDIEditor_OnCommand(active_midi_editor, 40138) -- scroll view up
        reaper.MIDIEditor_OnCommand(active_midi_editor, 40139) -- scroll view down
    end

    if redo_time_selection == true then
        __set_time_and_loop_selection(saved_ts_lp)
    end
end
