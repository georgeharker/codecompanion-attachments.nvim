local M = {}

---@class CodeCompanion.Extension.Attachments.Config
---@field adapters? table Custom adapter transformers
local defaults = {
    adapters = {},
}

---@type CodeCompanion.Extension.Attachments.Config
M.config = vim.deepcopy(defaults)

---Setup the extension
---@param opts? CodeCompanion.Extension.Attachments.Config
---@return nil
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
    
    -- Install adapter patches
    local adapter_patches = require("codecompanion-attachments.adapter_patches")
    adapter_patches.install()
    
    -- Register any custom adapter transformers
    for adapter_name, transformer in pairs(M.config.adapters) do
        adapter_patches.register_transformer(adapter_name, transformer)
    end
    
    -- Integrate chat methods
    local chat_integration = require("codecompanion-attachments.chat_integration")
    chat_integration.integrate()
    
    local log = require("codecompanion.utils.log")
    log:info("codecompanion-attachments extension loaded")
end

---Extension exports for CodeCompanion
M.exports = {
    slash_commands = {
        attachment = require("codecompanion-attachments.slash_command"),
    },
}

---CodeCompanion.Extension interface
---@class CodeCompanion.Extension.Attachments
local Extension = {
    setup = M.setup,
    exports = M.exports,
}

return Extension
