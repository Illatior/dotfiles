-- Monitor layout.
--
-- Every monitor's full spec lives here, so a `hyprctl reload` (which re-runs
-- this module from scratch) both enables and disables monitors correctly.
-- Stating only `disabled = true` would not survive: hyprland.lua no longer
-- restates the output, so nothing would turn it back on.
--
-- The settings widget's `disabled` flags come from
-- conf/generated/shell_settings.lua (`monitors` table).

-- output -> the spec to apply, minus anything the user has overridden.
local layouts = {
    ['DP-1'] = {
        mode = '2560x1440@165',
        position = '0x0',
        scale = 1,
    },
    ['HDMI-A-2'] = {
        mode = '1920x1080@60',
        position = '2560x0',
        scale = 1,
    },
}

-- The settings widget disables monitors by listing the ones to leave off.
local disabled = {}

local ok, generated = pcall(require, "conf.generated.shell_settings")
if ok and type(generated) == "table" and type(generated.monitors) == "table" then
    for output, opts in pairs(generated.monitors) do
        if type(opts) == "table" and opts.disabled then
            disabled[output] = true
        end
    end
end

for output, layout in pairs(layouts) do
    local spec = {
        output = output,
        mode = layout.mode,
        position = layout.position,
        scale = layout.scale,
    }

    if disabled[output] then
        spec.mode = 'preferred'
        spec.position = nil
        spec.disabled = true
    end

    hl.monitor(spec)
end