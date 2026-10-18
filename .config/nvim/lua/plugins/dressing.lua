return{
    'stevearc/dressing.nvim',
    opts = {
        input = {
            -- center the compile prompt, other inputs stay at the cursor
            get_config = function(opts)
                if opts.kind == "compile" then
                    return { relative = "editor", prefer_width = 60 }
                end
            end,
        },
    },
}
