-- Applies the settings the Quickshell settings widget persists.
--
-- The widget writes ~/.config/hypr/conf/generated/shell_settings.lua on every
-- change (it is gitignored) and applies the same values live through
-- `hyprctl eval`, so nothing is lost on a Hyprland restart. This module is the
-- half that reads that file back at load time.
--
-- `package.loaded` is cleared for this module and the generated one by
-- `SettingsService._rerun` before re-requiring it, so an edit takes effect
-- without a full `hyprctl reload` where that is safe to do.

local ok, generated = pcall(require, "conf.generated.shell_settings")

-- No generated file yet (first boot, or before the shell has ever written
-- one): keep whatever hyprland.lua sets and leave it alone.
if not ok or type(generated) ~= "table" then
    return
end

local cfg = generated.config

-- Partial tables are merged by hl.config, so only the keys present are set.
if type(cfg) == "table" then
    hl.config(cfg)
end

-- Monitors and workspaces are NOT applied here. They need `hl.monitor()` /
-- `hl.workspace_rule()`, which the settings file only carries overrides for,
-- so the owning modules (conf/hyprland/monitors.lua, workspaces.lua) restate
-- their full specs and read the overrides from the same generated file.