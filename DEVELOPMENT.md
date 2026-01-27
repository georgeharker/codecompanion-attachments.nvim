# DEVELOPMENT.md

## Development Setup

### Repository Structure

```
codecompanion-attachments/
├── lua/
│   └── codecompanion-attachments/
│       ├── init.lua              # Extension entry point (49 lines)
│       ├── utils.lua             # File handling utilities (390 lines)
│       ├── slash_command.lua     # /attachment command (323 lines)
│       ├── adapter_patches.lua   # Adapter monkey-patching (177 lines)
│       └── chat_integration.lua  # Chat buffer integration (53 lines)
├── plugin/
│   └── codecompanion-attachments.lua  # Plugin entry point (10 lines)
├── README.md                     # User documentation
├── DEVELOPMENT.md               # This file
├── test_load.lua                # Basic load test
└── test_config.lua              # Manual testing config
```

**Total:** ~1000 lines of Lua code

### Testing

#### Load Test

Verify the extension structure loads correctly:

```bash
cd ~/Development/neovim-plugins/codecompanion-attachments
nvim --headless -c "luafile test_load.lua" -c "quit"
```

Expected output:
```
✅ Extension loaded successfully
✅ setup() function exists
✅ exports table exists
✅ attachment slash command exported
✅ utils module loads
✅ get_supported_extensions() exists
✅ Found 14 supported extensions
🎉 All checks passed!
```

#### Manual Testing

Load Neovim with the extension:

```bash
nvim -u test_config.lua
```

Then:
1. Open a chat: `:CodeCompanion`
2. Type `/attachment` and press Enter
3. Test file picker, URL, and Files API sources

### Architecture

#### Extension Loading Flow

```
CodeCompanion loads _extensions
    ↓
Calls Extension.setup()
    ↓
├─ adapter_patches.install()
│  └─ Wraps adapters.resolve()
│     └─ Patches form_messages() for supported adapters
│
├─ chat_integration.integrate()
│  └─ Adds add_attachment_message() to Chat class
│
└─ Registers slash commands via exports
```

#### Message Flow

```
User: /attachment
    ↓
slash_command.lua:execute()
    ↓
User selects source (File/URL/Files API)
    ↓
utils.from_path() or utils.from_url()
    ↓
├─ Validate file
├─ Detect MIME type
└─ Encode to base64 (if needed)
    ↓
chat_integration.add_attachment_message()
    ↓
Add message with _meta.tag = "attachment"
    ↓
Chat:submit()
    ↓
Adapter.form_messages() [PATCHED]
    ↓
adapter_patches.transform_*_attachments()
    ↓
Transform to provider-specific format
    ↓
Send to LLM
```

#### Monkey-Patching Strategy

The extension uses **runtime monkey-patching** instead of forking:

1. **Adapter Resolution**: Wraps `adapters.resolve()` to intercept adapter creation
2. **Message Formation**: Wraps `adapter.handlers.form_messages()` to transform attachments
3. **Chat Methods**: Adds methods to `Chat` class via direct assignment

This approach:
- ✅ No core modifications needed
- ✅ Works with existing CodeCompanion installations
- ✅ Easy to maintain as CodeCompanion evolves
- ⚠️ Relies on stable internal APIs

### Adding Support for New Adapters

#### Step 1: Create a Transformer

In `adapter_patches.lua`, add a transformation function:

```lua
local function transform_myadapter_attachments(messages, adapter)
    local transformed = {}
    
    for _, m in ipairs(messages) do
        if m._meta and m._meta.tag == "attachment" and m.context then
            if adapter.opts and adapter.opts.attachment_upload then
                -- Transform m.content to your adapter's format
                m.content = {
                    -- Your adapter's format here
                }
            else
                m = nil  -- Remove if not supported
            end
        end
        
        if m then
            table.insert(transformed, m)
        end
    end
    
    return transformed
end
```

#### Step 2: Register the Transformer

Add to the `transformers` table:

```lua
local transformers = {
    anthropic = transform_anthropic_attachments,
    gemini = transform_gemini_attachments,
    myadapter = transform_myadapter_attachments,  -- Add here
}
```

#### Step 3: Enable in Adapter Config

The adapter must have `attachment_upload = true`:

```lua
require("codecompanion").setup({
    adapters = {
        myadapter = function()
            return require("codecompanion.adapters").extend("myadapter", {
                opts = {
                    attachment_upload = true,
                },
            })
        end,
    },
})
```

#### Step 4: Test and Document

1. Test with various file types
2. Update README.md compatibility table
3. Add example configuration

### Message Context Structure

Attachment messages use this structure:

```lua
{
    role = "user",
    content = base64_data_or_empty_string,
    _meta = {
        tag = "attachment",
    },
    context = {
        id = "<attachment>path/to/file.pdf</attachment>",
        mimetype = "application/pdf",
        path = "/full/path/to/file.pdf",
        source = "base64" | "url" | "file",
        url = "https://..." (if source == "url"),
        file_id = "file_123" (if source == "file"),
    },
}
```

### Adapter-Specific Formats

#### Anthropic

```lua
{
    role = "user",
    content = {
        {
            type = "document",
            source = {
                type = "base64" | "url" | "file",
                media_type = "application/pdf",
                data = base64_data,  -- if type == "base64"
                url = "https://...",  -- if type == "url"
                file_id = "file_123", -- if type == "file"
            },
        },
    },
}
```

#### Gemini

```lua
{
    role = "user",
    content = {
        {
            inline_data = {
                mime_type = "application/pdf",
                data = base64_data,
            },
        },
    },
}
```

### Code Conventions

Following CodeCompanion's standards:

- **Indentation**: 4 spaces
- **Whitespace**: Strip trailing whitespace
- **Naming**: snake_case for functions, PascalCase for classes
- **Comments**: LuaCATS type annotations for public APIs
- **Logging**: Use `require("codecompanion.utils.log")`

### Debugging

Enable debug logging:

```lua
require("codecompanion").setup({
    log_level = "DEBUG",
    _extensions = {
        "codecompanion-attachments",
    },
})
```

View logs:
```vim
:CodeCompanionLog
```

Look for lines containing:
- `"Patched adapter '...' for attachment support"`
- `"Installed codecompanion-attachments adapter patches"`
- `"codecompanion-attachments extension loaded"`

### Known Limitations

1. **API Stability**: Relies on CodeCompanion's internal adapter structure
2. **Single Patching**: If multiple extensions patch the same adapter, conflicts may occur
3. **Files API**: Currently only Anthropic supports Files API references
4. **Size Limits**: Provider-dependent (Anthropic: 32MB, Gemini: 20MB)

### Future Enhancements

- [ ] Add support for OpenAI adapters
- [ ] Add support for Copilot adapters
- [ ] Implement text extraction fallback for unsupported adapters
- [ ] Add attachment preview in chat buffer
- [ ] Support for batch attachment upload
- [ ] Integration tests with mocked adapters
- [ ] CI/CD pipeline

### Contributing

1. Fork the repository
2. Create a feature branch
3. Test thoroughly with `test_load.lua` and manual testing
4. Update documentation (README.md, DEVELOPMENT.md)
5. Submit a PR with clear description

### Resources

- [CodeCompanion.nvim](https://github.com/olimorris/codecompanion.nvim)
- [Original PR #2632](https://github.com/olimorris/codecompanion.nvim/pull/2632)
- [Anthropic Messages API](https://docs.anthropic.com/en/api/messages)
- [Gemini API](https://ai.google.dev/api/rest)
