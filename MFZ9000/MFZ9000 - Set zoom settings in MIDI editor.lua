-- For use with "MFZ9000 open MIDI item" only.
-- For use in MIDI editor only.

--[[

MIDI FOCUS AND ZOOM 9000 v0.3.1

--]]

local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"

require("_data.constants")
require("_data.helpers")
require("_data.zoom_and_focus")

-- parses the user input
local function parse_input(str_input, input_amount) -- RET: string array of correct inputs, nil on parsing error
    local i = 1
    local arr_input = {}

    for token in string.gmatch(str_input, "[^,]+") do
        -- reaper.ShowConsoleMsg(token .. "\n")
        if i > input_amount then
            reaper.MB("Bad input.", "Error", 0)
            return nil
        end

        if token:match("%d") == nil then
            reaper.MB("Not a number: " .. token, "Error", 0)
            return nil
        end

        if math.floor(tonumber(token)) ~= tonumber(token) then
            reaper.MB("Integers only.", "Error", 0)
            return nil
        end

        if (i == 1 or i == 2) and tonumber(token) < 1 then
            reaper.MB("Number less than 1.", "Error", 0)
            return nil
        end

        if i == 3 and (tonumber(token) ~= 1 and tonumber(token) ~= 0) then
            reaper.MB("0 == no, 1 == yes.", "Error", 0)
            return nil
        end

        if tonumber(token) > 256 then
            reaper.MB("Number larger than 256.", "Error", 0)
            return nil
        end

        token = math.floor(tonumber(token)) -- for safety
        arr_input[i] = token
        i = i + 1
    end

    -- for i, token in pairs(arr_input) do
        -- reaper.ShowConsoleMsg(token .. "\n")
    -- end

    return arr_input
end

-- zooms again
local function rezoom_horizontally(active_midi_editor, measures) -- RET: void
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    local saved_ts_lp = set_time_selection_to_n_measures(active_midi_editor, measures)
    reaper.MIDIEditor_OnCommand(active_midi_editor, 40726) -- zoom to project loop selection
    -- zoom_vertically(active_midi_editor, 11, measures, false)
    __set_time_and_loop_selection(saved_ts_lp)

    reaper.Undo_EndBlock("", 0)
    reaper.PreventUIRefresh(-1)
end

-- will restore focus to MIDI editor if SWS is installed
local function restore_focus_SWS() -- RET: void
    local cmd = reaper.NamedCommandLookup("_SN_FOCUS_MIDI_EDITOR")
    if cmd ~= 0 then
        reaper.Main_OnCommand(cmd, 0)
    end
end

-- gets the user input for default measure values and for the current track
local function get_user_input(curtrack) -- RET: string of inputs, nil on no input
    local input_amount = 3
    local retval, retvals_csv
    -- current values
    local def_mes      = reaper.GetExtState("mfz9000", "def_measures")
    local cur_trackmes = __get_proj_extstate(__KEYSTR_TRACKMES, curtrack)
    local cur_wzoom    = __get_proj_extstate(__KEYSTR_WZOOM, curtrack)

    if cur_wzoom == "" then
        cur_wzoom = "0"
    end

    if cur_trackmes == "" then
        cur_trackmes = def_mes
    end

    retval, retvals_csv = reaper.GetUserInputs("MFZ9000 setup", input_amount,
    "Default number of measures:,Tracks` no. of measures:,Prefer tracks` measure value:", -- text
    def_mes .. "," .. cur_trackmes .. "," .. cur_wzoom) -- textbox values

    if retval == false then
        return nil
    else
        return retvals_csv
    end
end

--------------------- MAIN ------------------------
local active_midi_editor = reaper.MIDIEditor_GetActive()
if active_midi_editor == nil then
    reaper.MB("Must be run in the MIDI editor.", "Error", 0)
    return
end

if reaper.GetExtState("mfz9000", "def_measures") == "" then
    reaper.MB("Default MFZ9000 measure value not found. Set \"change_measures_externally = true\" in the main script.", "Error", 0)
    return
end

local curtrack = __get_track_no_of_item_in_active_midi_editor(active_midi_editor)
local input    = get_user_input(curtrack)

if input == nil then
    restore_focus_SWS()
    return
end

-- change the zoom values to user-input values
input = parse_input(input, 3) -- 3 == input_amount
if input == nil then
    restore_focus_SWS()
    return
end

-- commit the values to memory
reaper.SetExtState("mfz9000", "def_measures",    input[1], true)
__set_proj_extstate(__KEYSTR_TRACKMES, curtrack, input[2])
__set_proj_extstate(__KEYSTR_WZOOM, curtrack,    input[3])

-- rezoom
if tonumber(__get_proj_extstate(__KEYSTR_WZOOM, curtrack)) == 1 then
    rezoom_horizontally(active_midi_editor, __get_proj_extstate(__KEYSTR_TRACKMES, curtrack))
else
    rezoom_horizontally(active_midi_editor, tonumber(reaper.GetExtState("mfz9000", "def_measures")))
end

restore_focus_SWS()
