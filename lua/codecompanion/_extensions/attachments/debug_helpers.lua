-- Helper commands for debugging attachments
local M = {}

--- Open the CodeCompanion log file in a split
function M.open_log()
	local log = require("codecompanion.utils.log")
	local logfile = log.get_logfile()
	vim.cmd("split " .. vim.fn.fnameescape(logfile))
	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "wipe"
	vim.bo.swapfile = false
	vim.cmd("normal! G") -- Jump to end
end

--- Clear the log file
function M.clear_log()
	local log = require("codecompanion.utils.log")
	local logfile = log.get_logfile()
	vim.fn.writefile({}, logfile)
	print("Cleared log file: " .. logfile)
end

--- Print log file path
function M.log_path()
	local log = require("codecompanion.utils.log")
	print(log.get_logfile())
end

--- Tail log file (requires external tail command)
function M.tail_log()
	local log = require("codecompanion.utils.log")
	local logfile = log.get_logfile()
	vim.cmd("terminal tail -f " .. vim.fn.fnameescape(logfile))
end

-- Create user commands
vim.api.nvim_create_user_command("AttachmentDebugLog", M.open_log, {
	desc = "Open CodeCompanion log file for attachment debugging",
})

vim.api.nvim_create_user_command("AttachmentClearLog", M.clear_log, {
	desc = "Clear the CodeCompanion log file",
})

vim.api.nvim_create_user_command("AttachmentLogPath", M.log_path, {
	desc = "Print the path to the CodeCompanion log file",
})

return M
