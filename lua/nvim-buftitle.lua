local M = {}

local nvim_augroup = function(group_name, definitions)
	vim.api.nvim_command("augroup " .. group_name)
	vim.api.nvim_command("autocmd!")
	for _, def in ipairs(definitions) do
		local command = table.concat({ "autocmd", unpack(def) }, " ")
		if vim.api.nvim_call_function("exists", { "##" .. def[1] }) ~= 0 then
			vim.api.nvim_command(command)
		end
	end
	vim.api.nvim_command("augroup END")
end

-- { window_number => scratch_buffer_number }
local win_to_sbuffer = {}

-- { window_number => info_window_number }
local win_to_iwin = {}

local function get_scratch_buf(win)
	local sbuf = win_to_sbuffer[win]

	if sbuf == nil or not vim.api.nvim_buf_is_valid(sbuf) then
		sbuf = vim.api.nvim_create_buf(false, true)
		win_to_sbuffer[win] = sbuf
	end

	return sbuf
end

local function delete_win(win)
	local sbuf = win_to_sbuffer[win]

	if sbuf ~= nil and vim.api.nvim_buf_is_valid(sbuf) then
		vim.api.nvim_buf_delete(sbuf, { force = true })
		win_to_sbuffer[win] = nil
	end

	local iwin = win_to_iwin[win]

	if iwin ~= nil and vim.api.nvim_buf_is_valid(iwin) then
		vim.api.nvim_win_close(iwin, { force = true })
		win_to_iwin[win] = nil
	end
end

local function display_window(win, width, height, row, col, line)
	local iwin = win_to_iwin[win]

	if iwin == nil or not vim.api.nvim_win_is_valid(iwin) then
		local sbufnr = get_scratch_buf(win)

		iwin = vim.api.nvim_open_win(sbufnr, false, {
			relative = "win",
			win = win,
			width = width,
			height = height,
			row = row,
			col = col,
			focusable = false,
			style = "minimal",
			noautocmd = true,
		})

		win_to_iwin[win] = iwin
	else
		vim.api.nvim_win_set_config(iwin, {
			win = win,
			relative = "win",
			width = width,
			height = height,
			row = row,
			col = col,
		})
	end

	local sbuf = get_scratch_buf(win)
	vim.api.nvim_buf_set_lines(sbuf, 0, -1, false, { line })
end

function M.update_buffer(win)
	if not vim.api.nvim_win_is_valid(win) then
		delete_win(win)
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local path = vim.api.nvim_buf_get_name(buf)
	local text = vim.api.nvim_call_function("fnamemodify", { path, ":t" })

	if text == nil or text == "" then
		delete_win(win)
		return
	end

	if text:find("NERD_tree", 1, true) == 1 then
		delete_win(win)
		return
	end

	local win_width = math.max(1, vim.api.nvim_win_get_width(win))
	local width = math.min(20, #text)
	local pos = win_width - width

	display_window(win, width, 1, 0, pos, text)
end

function M.update()
	local current_win = vim.api.nvim_get_current_win()
	M.update_buffer(current_win)

	for win, _ in pairs(win_to_iwin) do
		if win ~= current_win then
			M.update_buffer(win)
		end
	end
end

function M.update_delayed()
    vim.defer_fn(function()
      local status, err = pcall(M.update)

      if not status then
        print('Failed to get context: ' .. err)
      end
    end, 100)
end

function M.enable()
	local update = 'lua require("nvim-buftitle").update_delayed()'

	nvim_augroup("nvim_buftitle", {
		{ "BufWinEnter", "*", update },
		{ "WinScrolled", "*", update },
		{ "BufEnter", "*", update },
		{ "WinEnter", "*", update },
		{ "WinClosed", "*", update },
		{ "WinScrolled", "*", update },
		{ "User", "CursorMovedVertical", update },
		{ "CursorMoved", "*", update },
		{ "VimResized", "*", update },
		{ "User", "SessionSavePre", update },
		{ "User", "SessionSavePost", update },
	})
end

function M.disable()
	nvim_augroup("nvim_buftitle", {})
end

function M.setup()
	M.enable()
end

return M
