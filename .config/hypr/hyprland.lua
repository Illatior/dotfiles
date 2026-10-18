-- Monitors and workspace rules live in conf/hyprland/ so the Quickshell
-- settings widget can restate them: each module reads its overrides from
-- conf/generated/shell_settings.lua (written by the widget, gitignored) and
-- declares the full spec, so a reload turns monitors back on as well as off.
require('conf.hyprland.monitors')
require('conf.hyprland/workspaces')

local mainMod = 'SUPER'

local terminal = "alacritty"
local fileManager = "dolphin"
-- local menu = "toggle-wofi"
local menu = "walker"

hl.on('hyprland.start', function()
  hl.exec_cmd("$HOME/.local/scripts/update-env tmux")
  -- hl.exec_cmd("waybar")
  hl.exec_cmd("qs")
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("solaar -w hide")
  hl.exec_cmd("wl-paste --watch cliphist store")
  hl.exec_cmd("hyprsunset")
  hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
  hl.exec_cmd("walker --gapplication-service")
end)

hl.on('hyprland.start', function()
  hl.exec_cmd("steam")
  hl.exec_cmd("Telegram")
  hl.exec_cmd("zen-browser")
  hl.exec_cmd("discord")
  hl.exec_cmd("spotify")
end)

hl.on('hyprland.start', function() -- remove after hyprland fixes stuck cursor on launch
  hl.exec_cmd("sleep 10 && hyprctl reload")
end)

hl.env("XCURSOR_SIZE", 24)
hl.env("HYPRCURSOR_SIZE", 24)

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })
-- hl.permission({
--   binary = "/usr/(bin|local/bin)/grim",
--   type = 'screencopy',
--   mode = 'allow',
-- })
-- hl.permission({
--   binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland",
--   type = 'screencopy',
--   mode = 'allow',
-- })
-- hl.permission({
--   binary = "/usr/(bin|local/bin)/hyprpm",
--   type = 'plugin',
--   mode = 'allow',
-- })

-- Gaps, opacities, rounding, blur and animations are NOT set here: they are
-- owned by the Quickshell settings widget, which applies them live and persists
-- them to conf/generated/shell_settings.lua. conf/shell_settings.lua applies
-- that file below. Until the shell has written it once, Hyprland's own
-- defaults apply.
hl.config({
  general = {
    border_size = 2,
    col = {
      active_border = "rgb(7daea3)",
      inactive_border = "rgba(595959aa)",
    },
    resize_on_border = false,
    allow_tearing = false,
    layout = 'dwindle',
  },

  decoration = {
    rounding_power = 2,
    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = "rgba(1a1a1aee)",
    },
    blur = {
      vibrancy = 0.1696,
    },
  },
})

hl.config({
  dwindle = {
    preserve_split = true,
  },
})

hl.config({
  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,
  },
})

hl.config({
  input = {
    kb_layout = "us,ua",
    repeat_delay = 250,
    repeat_rate = 50,
    follow_mouse = 1,
    sensitivity = 0,
    accel_profile = 'flat',
    touchpad = {
      natural_scroll = false
    },
  },
})

-- Applies the gaps/opacity/blur/animation values the Quickshell settings
-- widget persists. Required after every hl.config above so its values win; the
-- widget's own defaults (gaps 5/10, opacities 1.0/0.9, blur 8/2, animations on)
-- apply until you change them in the widget.
require('conf.shell_settings')

local function bind_exec(keys, fun)
  hl.bind(keys, hl.dsp.exec_cmd(fun))
end

---@param opts table
local function notify(opts)
  local cmd = string.format("notify-send %s %s", opts.title, opts.msg)
  hl.exec_cmd(cmd)
end

local function change_monitor(monitor)
  local active = hl.get_active_monitor()
  if not active then
    return false
  end

  if active.name == monitor then
    return false
  end

  hl.dispatch(hl.dsp.focus({ monitor = monitor }))
  return true
end

---@class ToggleSpecialOptions
---@field monitor string Monitor name to bind special workspace to

---@param space string
---@param opts? ToggleSpecialOptions
local function toggle_special(space, opts)
  opts = opts or {}

  return function()
    local changed_focus = false
    if opts.monitor then
      changed_focus = change_monitor(opts.monitor)
    end

    local ws = hl.get_active_special_workspace()
    local expected_space = 'special:' .. space

    if not ws or ws.name ~= expected_space then -- toggle workspace if it's not already open
      hl.dispatch(hl.dsp.workspace.toggle_special(space))
      return
    end
    if ws and ws.name == expected_space and not changed_focus then -- close workspace if we're using this keybind on workspace's monitor & workspace is active
      hl.dispatch(hl.dsp.workspace.toggle_special(space))
      return
    end
  end
end

local function adjust_gamma(values)
  local i = 1

  --- TODO: add error handling
  return function()
    i = i + 1
    if i > #values then
      i = 1
    end

    hl.exec_cmd(string.format("hyprctl hyprsunset gamma %d", values[i]))
  end
end

bind_exec('code:191', "hyprctl switchxkblayout current next")

for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. '+ Q', hl.dsp.window.close())
bind_exec(mainMod .. '+ RETURN', terminal)
bind_exec(mainMod .. '+ SPACE', menu)
bind_exec(mainMod .. '+ SHIFT + Q',
  "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
bind_exec(mainMod .. '+ E', fileManager)
hl.bind(mainMod .. '+ T', hl.dsp.window.float({ action = 'toggle' }))
hl.bind(mainMod .. '+ SHIFT + M', hl.dsp.window.fullscreen({ active = 'toggle' }))
-- hl.bind(mainMod .. '+ P', hl.dsp.window.pseudo())

bind_exec(mainMod .. '+ P', '~/.local/scripts/screenshot window')
bind_exec(mainMod .. '+ SHIFT + P', '~/.local/scripts/screenshot area')

-- Clipboard history lives in the shell's island widget rather than a wofi
-- dmenu, so pick/paste is one keystroke instead of a list plus a copy.
hl.bind(mainMod .. '+ V', hl.dsp.exec_cmd("qs ipc call island toggle clipboard"))

-- bind = $mainMod, W, togglegroup
-- bind = $mainMod, Tab, changegroupactive, f
-- bind = $mainMod SHIFT, Tab, changegroupactive, b

hl.bind(mainMod .. '+ N', adjust_gamma({ 100, 200 }))

-- Magnifier: SUPER+= steps the zoom in around the cursor, SUPER+- steps it
-- back out, Escape drops it entirely. Hyprland only renders cursor zoom on the
-- monitor under the pointer, so the other screen stays untouched. Escape is
-- only bound while zoomed so apps keep it the rest of the time.
local zoom_steps = { 1, 2, 4, 8 }
local zoom_index = 1
local zoom_escape

local function set_zoom(index)
  zoom_index = math.max(1, math.min(index, #zoom_steps))
  hl.config({ cursor = { zoom_factor = zoom_steps[zoom_index] } })
  zoom_escape:set_enabled(zoom_index > 1)
end

hl.bind(mainMod .. '+ equal', function() set_zoom(zoom_index + 1) end)
hl.bind(mainMod .. '+ minus', function() set_zoom(zoom_index - 1) end)
zoom_escape = hl.bind('Escape', function() set_zoom(1) end)
zoom_escape:set_enabled(false)

hl.bind(mainMod .. '+ LEFT', hl.dsp.focus({ direction = 'left' }))
hl.bind(mainMod .. '+ H', hl.dsp.focus({ direction = 'left' }))
hl.bind(mainMod .. '+ RIGHT', hl.dsp.focus({ direction = 'right' }))
hl.bind(mainMod .. '+ l', hl.dsp.focus({ direction = 'right' }))
hl.bind(mainMod .. '+ UP', hl.dsp.focus({ direction = 'up' }))
hl.bind(mainMod .. '+ k', hl.dsp.focus({ direction = 'up' }))
hl.bind(mainMod .. '+ DOWN', hl.dsp.focus({ direction = 'down' }))
hl.bind(mainMod .. '+ j', hl.dsp.focus({ direction = 'down' }))

-- hl.bind(mainMod .. '+ S', hl.dsp.workspace.toggle_special('magic'))
hl.bind(mainMod .. '+ S', toggle_special('magic', { monitor = 'HDMI-A-2' }))
hl.bind(mainMod .. '+ M', toggle_special('music', { monitor = 'HDMI-A-2' }))
-- hl.bind(mainMod .. '+ SHIFT + S', hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. '+ SHIFT + mouse:272', hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. '+ SHIFT + mouse:273', hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
  { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
bind_exec("XF86AudioNext", "playerctl next")
bind_exec("XF86AudioPrev", "playerctl previous")
bind_exec("XF86AudioPause", "playerctl play-pause")
bind_exec("XF86AudioPlay", "playerctl play-pause")


hl.bind(mainMod .. '+ SHIFT + T', hl.dsp.window.tag({ tag = "half_transparent" }))

--- custom tags
hl.window_rule({
  match   = { tag = "half_transparent" },
  opacity = "0.5 override",
})
---




hl.window_rule({
  name = "ws-steam",
  match = { class = '^steam$' },
  workspace = '1',
})
hl.window_rule({
  name = "ws-telegram",
  match = { class = '^org\\.telegram\\.desktop$' },
  workspace = 'special:magic',
})
hl.window_rule({
  name = "ws-zen",
  match = { class = '^zen$' },
  workspace = '3',
})
hl.window_rule({
  name = "ws-discord",
  match = { class = '^discord$' },
  workspace = '4',
})
hl.window_rule({
  name = "ws-music",
  match = { class = '^Spotify$' },
  workspace = 'special:music',
})

hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = '.*' },
  suppress_event = 'maximize'
})

hl.window_rule({
  name = "fix-xwayland-drags",
  match = {
    class = '^$',
    title = '^$',
    xwayland = true,
    float = true,
    fullscreen = false,
    pin = false,
  },
  no_focus = true,
})

hl.window_rule({
  name = "move-hyprland-run",
  match = { class = "hyprland-run" },
  move = "20 monitor_h-120",
  float = true,
})

hl.window_rule {
  name = "unfocused-steam-games-fix",
  match = { class = "^(steam_app_[0-9]+|gamescope)$" },
  idle_inhibit = 'always',
  render_unfocused = true,
}

hl.window_rule {
  name = "open-steam-apps-on-1",
  match = { class = "^(steam_app_[0-9]+|gamescope|steam_proton)$" },
  workspace = '1',
}

hl.window_rule {
  name = "zoom-annotate-toolbar-floating",
  match = { title = "^annotate_toolbar$" },
  float = true,
}
hl.window_rule {
  name = "zoom-initial-title-floating",
  match = { title = "^Zoom Workplace$" },
  float = true,
}

-- hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP", { exec_once = true })

-- hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP", { exec_once = true })
