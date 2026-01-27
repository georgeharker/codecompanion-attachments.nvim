local adapter_utils = require("codecompanion.utils.adapters")
local log = require("codecompanion.utils.log")

local M = {}

---Transform attachment message for Anthropic (simple pre-processing)
---@param m table The message to transform
---@param adapter table The adapter instance
---@return table|nil Transformed message or nil to skip
local function transform_anthropic_attachment(m, adapter)
    -- Only process attachment messages
    if not (m._meta and m._meta.tag == "attachment" and m.context) then
        return m
    end
    
    log:debug("Found attachment message: source=%s, mimetype=%s", 
        m.context.source or "base64", m.context.mimetype or "nil")
    
    -- Check if adapter supports attachments
    if not (adapter.opts and adapter.opts.attachment_upload) then
        log:warn("Adapter does not support attachments, skipping")
        return nil
    end
    
    -- Transform based on source type
    if m.context.source == "url" then
        log:debug("Transforming URL attachment: %s", m.context.url)
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
        log:debug("Transforming Files API attachment: %s", m.context.file_id)
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
            log:warn("File API not supported, skipping attachment")
            return nil
        end
    else
        -- Base64-encoded document or image
        log:debug("Transforming base64 attachment: type=%s, mime=%s, size=%d bytes", 
            m.context.attachment_type or "unknown",
            m.context.mimetype or "unknown",
            m.content and #m.content or 0)
        
        local content_data = m.content
        local content_type = m.context.attachment_type == "image" and "image" or "document"
        
        m.content = {
            {
                type = content_type,
                source = {
                    type = "base64",
                    media_type = m.context.mimetype or "application/pdf",
                    data = content_data,
                },
            },
        }
        log:debug("Transformed to %s content block", content_type)
    end
    
    return m
end

---Patch Anthropic adapter to handle attachments
---@param adapter table The adapter to patch
---@return table The patched adapter
local function patch_anthropic_adapter(adapter)
    local original_form_messages = adapter.handlers.form_messages
    
    adapter.handlers.form_messages = function(self, messages)
        log:debug("Patched Anthropic form_messages called with %d messages", #messages)
        
        -- Pre-process: Transform any attachment messages
        local processed = {}
        for _, m in ipairs(messages) do
            local transformed = transform_anthropic_attachment(m, self)
            if transformed then
                table.insert(processed, transformed)
            end
        end
        
        log:debug("After attachment transformation: %d messages", #processed)
        
        -- Call original form_messages with transformed messages
        local result = original_form_messages(self, processed)
        
        log:debug("Original form_messages returned: %s", vim.inspect(result))
        
        return result
    end
    
    log:info("Patched Anthropic adapter for attachment support")
    return adapter
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
    gemini = transform_gemini_attachments,
    gemini_cli = transform_gemini_attachments,
}

---Patch an adapter's form_messages handler to support attachments
---@param adapter table The adapter to patch
---@param adapter_name string The name of the adapter
---@return table The patched adapter
local function patch_adapter(adapter, adapter_name)
    if adapter_name == "anthropic" then
        return patch_anthropic_adapter(adapter)
    end
    
    -- For other adapters, use the simple transformer approach
    local transformer = transformers[adapter_name]
    if not transformer then
        return adapter
    end
    
    local original_form_messages = adapter.handlers.form_messages
    adapter.handlers.form_messages = function(self, messages)
        local transformed = transformer(messages, self)
        return original_form_messages(self, transformed)
    end
    
    log:info("Patched adapter '%s' for attachment support", adapter_name)
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
        
        -- Patch if this adapter has support
        if adapter_name == "anthropic" or transformers[adapter_name] then
            adapter = patch_adapter(adapter, adapter_name)
        end
        
        return adapter
    end
    
    log:info("Installed attachments adapter patches")
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
