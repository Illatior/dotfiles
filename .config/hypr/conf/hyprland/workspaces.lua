-- Workspace → monitor rules.
--
-- Defaults live here; the settings widget can override any of them from
-- conf/generated/shell_settings.lua (`workspaces` table, workspace id ->
-- output name). Rules only apply when a workspace is created, so the widget
-- also moves a workspace that already exists — see
-- SettingsService.setWorkspaceMonitor.

local defaults = {
    ['1'] = 'DP-1',
    ['2'] = 'DP-1',
    ['3'] = 'HDMI-A-2',
    ['4'] = 'HDMI-A-2',
    -- Special workspaces, kept on the display they are toggled from.
    ['magic'] = 'HDMI-A-2',
    ['music'] = 'HDMI-A-2',
}

local ok, generated = pcall(require, "conf.generated.shell_settings")
if ok and type(generated) == "table" and type(generated.workspaces) == "table" then
    for workspace, output in pairs(generated.workspaces) do
        if type(output) == "string" then
            defaults[workspace] = output
        end
    end
end

for workspace, monitor in pairs(defaults) do
    hl.workspace_rule({
        workspace = workspace,
        monitor = monitor,
    })
end