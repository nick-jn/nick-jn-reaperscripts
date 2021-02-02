--[[

MIDI FOCUS AND ZOOM 9000 v0.3

Opens the MIDI editor with consistent, user-defined measure-based horizontal zoom values,
and vertical zoom values. The horizontal zoom values can be changed per track (persistent).

The measures shown are calculated from the right of the current edit cursor location.

Usage:
       Bind this script to a keyboard key or a mouse action of your choosing
       for opening the MIDI items. The default action is (in Mouse Modifiers settings):
       Media Item -> Double Click -> Default Action. Check the user settings below. Use
       the provided "MFZ9000 - Set zoom settings in MIDI editor.lua" script for user-based
       changes in the MIDI editor (NOT IN THE MAIN WINDOW).

--]]

------------------- USER SETTINGS -------------------

----- MAIN SETTINGS -----
change_measures_externally = true -- use the set zoom settings script to change the shown measures settings,
                                  -- otherwise set to false and manually change the value below
measures_to_show = 8

vertical_zoom_level = 16 -- 4 is all the way out, 100 is all the way in, 12-20 are reasonable values to try out

open_at_mouse_cursor = true  -- will open at mouse cursor instead of at edit cursor if true,
                             -- it will not shift the edit cursor from its original position

move_the_edit_cursor_to_mouse_cursor = true   -- if open_at_mouse_cursor is true, then it will shift
                                              -- the edit cursor to where you clicked in the arrange view

----- EXTRA SETTINGS -----

-- these settings are a bit experimental, if bugs occur - please report them

show_only_the_selected_item = true -- the viewport will focus ONLY on the selected item

center_small_items = true -- the viewport will center on items of sufficiently small length
                          -- instead of showing them from the left edge of the viewport

pad_small_items = true -- don't stretch very small items the entire length
padding_amount  = 1 -- measures in 4/4 (can be set to rational numbers too, best to use .5 increments)

center_small_items_length_limit = 5 -- how many measures (if counted in 4/4) is considered small?

-- if the viewer is opened near the end of the item, try to shift the viewport
-- to the left slightly so as not to show just a handful of measures of the item
-- EXAMPLE: your measures_to_show is 8, you click on the last measure of the item of length 12,
-- and instead of showing you only the last measure, the viewport will shift to the left a bit
item_clicked_at_end_offset    = true
item_clicked_at_end_threshold = 3 -- what is considered the end of the item (in 4/4 measures)

-----------------------------------------------------

local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"

require("_data.constants")
require("_data.helpers")
require("_data.zoom_and_focus")

local function init_user_settings()
    if item_clicked_at_end_threshold < 1 then
        item_clicked_at_end_threshold = 1
    elseif item_clicked_at_end_threshold > 12 then
        item_clicked_at_end_threshold = 12
    end

    if center_small_items_length_limit < 1 then
        center_small_items_length_limit = 1
    elseif center_small_items_length_limit > 128 then
        center_small_items_length_limit = 128
    end

    if padding_amount < 0.1 then
        padding_amount = 0.1
    elseif padding_amount > 8 then
        padding_amount = measures_to_show
    end

    reaper.SetExtState("mfz9000", __KEYSTR_USER_HOR_ZOOM_TO_MOUSE_CURSOR,            tostring(open_at_mouse_cursor), true)
    reaper.SetExtState("mfz9000", __KEYSTR_USER_HOR_ZOOM_TO_MOUSE_CURSOR_MOVE_EDCUR, tostring(move_the_edit_cursor_to_mouse_cursor), true)
    reaper.SetExtState("mfz9000", __KEYSTR_USER_ITEM_CLICKED_AT_END_OFFSET,          tostring(item_clicked_at_end_offset), true)
    reaper.SetExtState("mfz9000", __KEYSTR_USER_ITEM_CLICKED_AT_END_THRESHOLD,       tostring(item_clicked_at_end_threshold), true)
    reaper.SetExtState("mfz9000", __KEYSTR_USER_SHOW_ONLY_THE_SELECTED_ITEM,         tostring(show_only_the_selected_item), true)
    reaper.SetExtState("mfz9000", __KEYSTR_USER_CENTER_SMALL_ITEMS,                  tostring(center_small_items), true)
    reaper.SetExtState("mfz9000", __KEYSTR_USER_CENTER_SMALL_ITEMS_LENGTH,           tostring(center_small_items_length_limit), true)
    reaper.SetExtState("mfz9000", __KEYSTR_USER_PAD_SMALL_ITEMS,                     tostring(pad_small_items), true)
    reaper.SetExtState("mfz9000", __KEYSTR_USER_PAD_SMALL_ITEMS_AMOUNT,              tostring(padding_amount), true)
end

-- decides how many measures to show based on the settings
local function init_measures_to_show(active_midi_editor) -- RET: void
    local curtrack = __get_track_no_of_item_in_active_midi_editor(active_midi_editor)
    local track_whichzoom = __get_proj_extstate(__KEYSTR_WZOOM, curtrack)

    if change_measures_externally == true then
        if reaper.GetExtState("mfz9000", "def_measures") == "" then
            reaper.SetExtState("mfz9000", "def_measures", measures_to_show, true)
        else
            measures_to_show = tonumber(reaper.GetExtState("mfz9000", "def_measures"))
        end

        -- change the measure zoom to either default or track-based
        if track_whichzoom ~= "" then
            track_whichzoom = tonumber(track_whichzoom)
            if track_whichzoom == 1 then
                measures_to_show = tonumber(__get_proj_extstate(__KEYSTR_TRACKMES, curtrack))
            end
        end
    end
end

local function main()
    local selected_item_type = __get_selected_media_item_type()

    -- make sure to activate the appropriate action for all item types
    if selected_item_type == nil then
        return
    elseif selected_item_type == "RPP_PROJECT" then
        reaper.Main_OnCommand(41816, 0) -- open associated project in new tab
        return
    elseif selected_item_type ~= "MIDI" then
        reaper.Main_OnCommand(40009, 0) -- show media item/take properties
        return
    end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    reaper.Main_OnCommand(40153, 0) -- open midi editor
    local active_midi_editor = reaper.MIDIEditor_GetActive()
    local saved_cursor_pos   = reaper.GetCursorPosition()

    init_user_settings()
    __get_and_set_user_configuration()
    init_measures_to_show(active_midi_editor)

    if __USER_HOR_ZOOM_TO_MOUSE_CURSOR == true then
        reaper.Main_OnCommand(40514, 0) -- move edit cursor to mouse cursor (no snapping)
        reaper.Main_OnCommand(41041, 0) -- move edit cursor to start of current measure
    end

    local saved_ts_lp = set_time_selection_to_n_measures(active_midi_editor, measures_to_show)
    reaper.MIDIEditor_OnCommand(active_midi_editor, 40726) -- zoom to project loop selection
    zoom_vertically(active_midi_editor, vertical_zoom_level, measures_to_show, false)
    __set_time_and_loop_selection(saved_ts_lp)

    if __USER_HOR_ZOOM_TO_MOUSE_CURSOR == true and __USER_HOR_ZOOM_TO_MOUSE_CURSOR_MOVE_EDCUR == false then
        reaper.SetEditCurPos(saved_cursor_pos, false, false)
    end

    reaper.Undo_EndBlock("", 0)
    reaper.PreventUIRefresh(-1)
end

------------------------------------------------------------------------------

main()
