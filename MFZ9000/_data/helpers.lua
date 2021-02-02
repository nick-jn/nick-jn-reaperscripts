local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"

require("constants")

-- calculates the midpoint of the **SELECTED** notes in the loop,
-- return 60 is no active take is found (shouldn't be the case),
-- and if there are no notes in the item
function __calc_midpoint_pitch_of_selected_notes(active_midi_editor) -- RET: integer
    local retval, notes, ccs, sysex -- CountEvents
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel -- GetNote
    local min_pitch = 127
    local max_pitch = 0
    local take = reaper.MIDIEditor_GetTake(active_midi_editor)

    if take ~= nil then
        retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take) -- only notes is needed
    else
        return 60
    end

    --reaper.ShowConsoleMsg("\nnotes in the item: " .. notes .. "\n\n")
    if notes == 0 then
        return 60
    end

    local noteidx  = 0
    for i = notes, 1, -1 do
        retval, selected, muted, startppqpos,
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
        noteidx = noteidx +1
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

-- returns the type of the selected media item as a string, nil if no items are selected
function __get_selected_media_item_type() -- RET: string
    local selected_media_item = reaper.GetSelectedMediaItem(0, 0)
    if selected_media_item == nil then
        return nil
    end

    local active_take = reaper.GetActiveTake(selected_media_item)
    if active_take == nil then
        return nil
    end

    return reaper.GetMediaSourceType(reaper.GetMediaItemTake_Source(active_take), "")
end

-- returns the CFGEDITVIEW value of the passed type
function __get_cfg_edit_view(active_midi_editor, cfg_edit_view_type) -- RET: integer
    local take = reaper.MIDIEditor_GetTake(active_midi_editor)
    local media_item = reaper.GetMediaItemTake_Item(take)
    local bool_retval, str_item_chunk = reaper.GetItemStateChunk(media_item, "", false)

    -- reaper.ShowConsoleMsg("\nchunk initial:\n" ..  str_item_chunk)

    local cfg_line = string.match(str_item_chunk, "CFGEDITVIEW (.-)\n")
    if cfg_line == nil then
        cfg_line = "not found"
        reaper.MB("chunk_horzoom couldn't find CFGEDITVIEW in the statechunk", "Error", 0);
        return nil
    end
    -- reaper.ShowConsoleMsg("\ncfg_line: " ..  cfg_line)

    local i = 1
    local midi_editor_viewport_values = {}
    for token in string.gmatch(cfg_line, "([%d%.%-%+]*)%s?") do
        midi_editor_viewport_values[i] = token
        -- reaper.ShowConsoleMsg("\nvar no." .. i .. ": " .. midi_editor_viewport_values[i])

        i = i + 1
    end

    if cfg_edit_view_type     == __CFGEV_HSTARTPOS then
        return midi_editor_viewport_values[1]
    elseif cfg_edit_view_type == __CFGEV_HZOOM then
        return midi_editor_viewport_values[2]
    elseif cfg_edit_view_type == __CFGEV_VSTARTPOS then
        return midi_editor_viewport_values[3]
    elseif cfg_edit_view_type == __CFGEV_VZOOM then
        return midi_editor_viewport_values[4]
    else
        return nil
    end
end

-- rounds the float error + a bit extra of qn_values (ceil if >0.99, floor if <0.01)
function __round_qn_value(qn_value) -- RET: integer
    local whole, frac = math.modf(qn_value)

    -- reaper.ShowConsoleMsg("__round_qn_value PRE: " .. whole .. " | " .. frac .. "\n")
    if frac > 0.99 then
        qn_value = math.ceil(qn_value)
    elseif frac < 0.01 then
        qn_value = math.floor(qn_value)
    else
        qn_value = math.ceil(qn_value)
    end
    -- reaper.ShowConsoleMsg("__round_qn_value POST: " .. num .. "\n\n")

    return qn_value
end

-- gets the user config from the extstate of Reaper, and then loads it to the
-- values in constants
function __get_and_set_user_configuration()
    local function is_str_bool(str)
        if str == "true" or str == "false" then
            return true
        else
            return false
        end
    end

    local function str_to_bool(str)
        if str == "true" then
            return true
        else
            return false
        end
    end

    local conf_array = {
    reaper.GetExtState("mfz9000", __KEYSTR_USER_HOR_ZOOM_TO_MOUSE_CURSOR),
    reaper.GetExtState("mfz9000", __KEYSTR_USER_HOR_ZOOM_TO_MOUSE_CURSOR_MOVE_EDCUR),
    reaper.GetExtState("mfz9000", __KEYSTR_USER_ITEM_CLICKED_AT_END_OFFSET),
    reaper.GetExtState("mfz9000", __KEYSTR_USER_ITEM_CLICKED_AT_END_THRESHOLD),
    reaper.GetExtState("mfz9000", __KEYSTR_USER_SHOW_ONLY_THE_SELECTED_ITEM),
    reaper.GetExtState("mfz9000", __KEYSTR_USER_CENTER_SMALL_ITEMS),
    reaper.GetExtState("mfz9000", __KEYSTR_USER_CENTER_SMALL_ITEMS_LENGTH),
    reaper.GetExtState("mfz9000", __KEYSTR_USER_PAD_SMALL_ITEMS),
    reaper.GetExtState("mfz9000", __KEYSTR_USER_PAD_SMALL_ITEMS_AMOUNT)
    }

    for i, str in pairs(conf_array) do
        -- reaper.ShowConsoleMsg(str .. "\n")
        if is_str_bool(str) == true then
            conf_array[i] = str_to_bool(str)
        else
            conf_array[i] = tonumber(str)
        end
    end

    __USER_HOR_ZOOM_TO_MOUSE_CURSOR            = conf_array[1]
    __USER_HOR_ZOOM_TO_MOUSE_CURSOR_MOVE_EDCUR = conf_array[2]
    __USER_ITEM_CLICKED_AT_END_OFFSET          = conf_array[3]
    __USER_ITEM_CLICKED_AT_END_THRESHOLD       = conf_array[4]
    __USER_SHOW_ONLY_THE_SELECTED_ITEM         = conf_array[5]
    __USER_CENTER_SMALL_ITEMS                  = conf_array[6]
    __USER_CENTER_SMALL_ITEMS_LENGTH           = conf_array[7]
    __USER_PAD_SMALL_ITEMS                     = conf_array[8]
    __USER_PAD_SMALL_ITEMS_AMOUNT              = conf_array[9]
end
