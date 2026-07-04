hl.monitor({
  output = 'DP-1',
  mode = '2560x1440@165',
  position = '0x0',
  scale = 1,
})

hl.monitor({
  output = 'HDMI-A-2',
  mode = '1920x1080@60',
  position = '2560x0',
  scale = 1,
})

hl.workspace_rule({
  workspace = '1',
  monitor = 'DP-1',
})
hl.workspace_rule({
  workspace = '2',
  monitor = 'DP-1',
})
hl.workspace_rule({
  workspace = '3',
  monitor = 'HDMI-A-2',
})
hl.workspace_rule({
  workspace = '4',
  monitor = 'HDMI-A-2',
})

local mainMod = 'SUPER'

local terminal = "alacritty"
local fileManager = "dolphin"
local menu = "toggle-wofi"

hl.on('hyprland.start', function()
  hl.exec_cmd("$HOME/.local/scripts/update-env tmux")
  hl.exec_cmd("waybar")
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("solaar -w hide")
  hl.exec_cmd("wl-paste --watch cliphist store")
  hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
end)

-- hl.on('hyprland.start', function()
--   hl.exec_cmd('steam', { workspace = '1' })
--   hl.exec_cmd('Telegram', { workspace = 'special:magic' })
--   hl.exec_cmd('zen-browser', { workspace = '3' })
--   hl.exec_cmd('discord', { workspace = '4' })
-- end)

hl.on('hyprland.start', function()
  hl.exec_cmd('[workspace 1 silent] steam')
  hl.exec_cmd('[workspace special:magic] Telegram')
  hl.exec_cmd('[workspace 3 silent] zen-browser')
  hl.exec_cmd('[workspace 4 silent] discord')
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

hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 10,
    border_size = 2,
    col = {
      active_border = "rgb(7daea3)",
      inactive_border = "rgba(595959aa)",
    },
    resize_on_border = false,
    allow_tearing = false,
    layout = 'dwindle',
  },
  animations = {
    enabled = false,
  },

  decoration = {
    rounding = 10,
    rounding_power = 2,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = "rgba(1a1a1aee)",
    },
    blur = {
      enabled = true,
      size = 3,
      passes = 1,
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
bind_exec(mainMod .. '+ P', 'grim -g "$(slurp -d)" - | wl-copy')
bind_exec(mainMod .. '+ SHIFT + P', 'grim -g "$(slurp)" - | swappy -f -')
bind_exec(mainMod .. '+ V', "cliphist list | wofi --dmenu | cliphist decode | wl-copy")

-- bind = $mainMod, W, togglegroup
-- bind = $mainMod, Tab, changegroupactive, f
-- bind = $mainMod SHIFT, Tab, changegroupactive, b

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
  name = "prevent-steam-apps-from-being-stopped",
  match = { class = "^(steam_app_[0-9]+|gamescope)$" },
  idle_inhibit = 'always',
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
