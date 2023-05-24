local auto_ready_client_side = false
local max_force_ready_clicks = 6
local singleplayer = Global.game_settings.single_player

if singleplayer then
    return
end

local host = Network:is_server()
local orig_on_ready_pressed = MissionBriefingGui.on_ready_pressed
local orig_update = MissionBriefingGui.update

function MissionBriefingGui:update(t, ...)
    orig_update(self, t, ...)

    local total_loaded, total_ready = 0, 0
    local session = managers.network and managers.network:session()
    local all_peers = session and session:all_peers() or {}

    for _, peer in pairs(all_peers) do
        if peer:synched() and peer:is_outfit_loaded() and session:local_peer():is_streaming_complete() then
            total_loaded = total_loaded + 1
            if peer:waiting_for_player_ready() then
                total_ready = total_ready + 1
            end
        end
    end

    self.abs_all_peers_loaded = total_loaded == table.size(all_peers)

    if self.abs_all_peers_loaded then
        local input_focus = managers.menu_component:input_focus()
        local in_no_focus_menu = type(input_focus) == "boolean" and input_focus
        self.abs_idle_delay = self.abs_idle_delay or t + 4

        if auto_ready_client_side and not host and not managers.briefing:event_playing() and in_no_focus_menu and not self._ready and total_ready >= table.size(session:peers()) and self.abs_idle_delay <= t then
            orig_on_ready_pressed(self)
            self.abs_idle_delay = t + 4
        end
    elseif self._ready then
        orig_on_ready_pressed(self)
    end
end

function MissionBriefingGui:on_ready_pressed(...)
    if host then
        local t = Application:time()   
        self.abs_force_ready_delay = self.abs_force_ready_delay or 0

        if (t - self.abs_force_ready_delay) <= 2 then
            self.abs_force_ready_clicked = (self.abs_force_ready_clicked or 0) + 1

            if self.abs_force_ready_clicked >= max_force_ready_clicks then
                self.abs_force_ready_clicked = 0
                
                managers.system_menu:show({
                    title = managers.localization:text("dialog_warning_title"),
                    text = "Est tu sur de vouloir lancé la partie?\n(Car si les autre n'ont pas charger il pourrais avoir un blackscreen)",
                    button_list = {
                        {
                            text = managers.localization:text("dialog_yes"),
                            callback_func = function()
                                managers.chat:send_message(1, managers.network.account:username(), "a forcé la game!")
                                game_state_machine:current_state():start_game_intro()
                            end
                        },
                        {
                            text = managers.localization:text("dialog_no"),
                            cancel_button = true
                        }
                    }
                })
            end
        else
            self.abs_force_ready_clicked = 1
        end

        self.abs_force_ready_delay = t
    end

    if self.abs_all_peers_loaded then
        orig_on_ready_pressed(self, ...)
    end
end