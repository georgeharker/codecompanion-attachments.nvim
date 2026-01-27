local adapter_utils = require("codecompanion.utils.adapters")
local log = require("codecompanion.utils.log")

local M = {}

---Transform attachment messages for Anthropic adapter
---@param messages table List of messages
---@param adapter table The adapter instance
---@return table Transformed messages
local function transform_anthropic_attachments(messages, adapter)
    local transformed = {}
    
    log:debug("Anthropic transformer: Processing %d messages", #messages)
    
    for i, m in ipairs(messages) do
        log:debug("Message %d: role=%s, has_meta=%s, tag=%s, has_context=%s", 
            i, m.role or "nil", 
            m._meta and "yes" or "no",
            m._meta and m._meta.tag or "nil",
            m.context and "yes" or "no")
        
        -- Handle attachment messages
        if m._meta and m._meta.tag == "attachment" and m.context then
            log:debug("Found attachment message: source=%s, mimetype=%s", 
                m.context.source or "nil", m.context.mimetype or "nil")
            
            -- Check if adapter supports attachments (either vision for images or attachment_upload for docs)
            local supports_attachments = (adapter.opts and adapter.opts.attachment_upload) 
                or (adapter.opts and adapter.opts.vision)
            
            log:debug("Adapter supports attachments: %s (attachment_upload=%s, vision=%s)",
                supports_attachments and "yes" or "no",
                adapter.opts and adapter.opts.attachment_upload or "nil",
                adapter.opts and adapter.opts.vision or "nil")
            
            if supports_attachments then
                if m.context.source == "url" then
                    log:debug("Transforming URL attachment: %s", m.context.url)
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
                    log:debug("Transforming Files API attachment: %s", m.context.file_id)
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
                        log:warn("File API not supported, skipping attachment")
                        m = nil
                    end
                else
                    log:debug("Transforming base64 attachment: type=%s, size=%d bytes", 
                        m.context.attachment_type or "unknown",
                        m.content and #m.content or 0)
                    -- Base64-encoded document or image
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
            else
                log:warn("Adapter does not support attachments, skipping")
                m = nil
            end
        end
        
        if m then
            table.insert(transformed, m)
        end
    end
    
    log:debug("Anthropic transformer: Returning %d messages", #transformed)
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
    
    -- Wrap form_messages to apply attachment transformations BEFORE original processing
    adapter.handlers.form_messages = function(self, messages)
        log:debug("Patched form_messages called for %s with %d messages", adapter_name, #messages)
        
        -- First transform attachments while we still have _meta tags
        local transformed = transformer(messages, self)
        
        log:debug("After transformation: %d messages", #transformed)
        
        -- Then run the original form_messages on the transformed messages
        local formed = original_form_messages(self, transformed)
        
        log:debug("After original form_messages: %d messages", #formed)
        
        return formed
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
        
        -- Patch if this adapter has a transformer
        if transformers[adapter_name] then
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
