local adapter_utils = require("codecompanion.utils.adapters")
local log = require("codecompanion.utils.log")

local M = {}

---Transform attachment messages for Anthropic adapter
---@param messages table List of messages
---@param adapter table The adapter instance
---@return table Transformed messages
local function transform_anthropic_attachments(messages, adapter)
    local transformed = {}
    
    for _, m in ipairs(messages) do
        -- Handle attachment messages
        if m._meta and m._meta.tag == "attachment" and m.context then
            if adapter.opts and adapter.opts.attachment_upload then
                if m.context.source == "url" then
                    -- URL-based document
                    m.content = {
                        {
                            type = "document",
                            source = {
                                type = "url",
                                url = m.context.url,
                            },
                        },
                    }
                elseif m.context.source == "file" then
                    -- Files API reference - requires file_api capability
                    if adapter.opts.file_api then
                        m.content = {
                            {
                                type = "document",
                                source = {
                                    type = "file",
                                    file_id = m.context.file_id,
                                },
                            },
                        }
                    else
                        -- Remove the message if file_api is not supported
                        m = nil
                    end
                else
                    -- Base64-encoded document
                    local content_data = m.content
                    m.content = {
                        {
                            type = "document",
                            source = {
                                type = "base64",
                                media_type = m.context.mimetype or "application/pdf",
                                data = content_data,
                            },
                        },
                    }
                end
            else
                -- Remove the message if document upload support is not enabled
                m = nil
            end
        end
        
        if m then
            table.insert(transformed, m)
        end
    end
    
    return transformed
end

---Transform attachment messages for Gemini adapter
---@param messages table List of messages
---@param adapter table The adapter instance
---@return table Transformed messages
local function transform_gemini_attachments(messages, adapter)
    local transformed = {}
    
    for _, m in ipairs(messages) do
        -- Handle attachment messages
        if m._meta and m._meta.tag == "attachment" and m.context then
            if adapter.opts and adapter.opts.attachment_upload then
                -- Gemini uses inline_data format
                if m.context.source ~= "file" then
                    local content_data = m.content
                    m.content = {
                        {
                            inline_data = {
                                mime_type = m.context.mimetype or "application/pdf",
                                data = content_data,
                            },
                        },
                    }
                else
                    -- Files API references not supported in initial version
                    m = nil
                end
            else
                -- Remove the message if document upload support is not enabled
                m = nil
            end
        end
        
        if m then
            table.insert(transformed, m)
        end
    end
    
    return transformed
end

---Adapter-specific transformation functions
local transformers = {
    anthropic = transform_anthropic_attachments,
    gemini = transform_gemini_attachments,
    gemini_cli = transform_gemini_attachments,
}

---Patch an adapter's form_messages handler to support attachments
---@param adapter table The adapter to patch
---@param adapter_name string The name of the adapter
---@return table The patched adapter
local function patch_adapter(adapter, adapter_name)
    local transformer = transformers[adapter_name]
    
    if not transformer then
        return adapter
    end
    
    -- Store original form_messages handler
    local original_form_messages = adapter.handlers.form_messages
    
    -- Wrap form_messages to apply attachment transformations
    adapter.handlers.form_messages = function(self, messages)
        -- First run the original form_messages
        local formed = original_form_messages(self, messages)
        
        -- Then apply attachment transformations
        return transformer(formed, self)
    end
    
    log:trace("Patched adapter '%s' for attachment support", adapter_name)
    
    return adapter
end

---Install adapter patches into CodeCompanion
---@return nil
function M.install()
    local adapters = require("codecompanion.adapters")
    local original_resolve = adapters.resolve
    
    -- Wrap the resolve function to patch adapters
    adapters.resolve = function(adapter_name, adapter_opts)
        local adapter = original_resolve(adapter_name, adapter_opts)
        
        -- Patch if this adapter has a transformer
        if transformers[adapter_name] then
            adapter = patch_adapter(adapter, adapter_name)
        end
        
        return adapter
    end
    
    log:info("Installed codecompanion-attachments adapter patches")
end

---Register a custom transformer for an adapter
---@param adapter_name string The name of the adapter
---@param transformer function The transformation function
---@return nil
function M.register_transformer(adapter_name, transformer)
    transformers[adapter_name] = transformer
    log:info("Registered attachment transformer for adapter '%s'", adapter_name)
end

return M
