# codecompanion-attachments.nvim

Upload documents and images to your LLM conversations in CodeCompanion.nvim.

This extension adds support for attaching PDFs, Word documents, spreadsheets, and other file types to your chat interactions. It works by patching CodeCompanion adapters to handle document uploads using each provider's native API format.

## Features

- 📎 **Document Upload**: Attach PDFs, DOCX, XLSX, PPTX, RTF, CSV, and more
- 🖼️ **Image Support**: Works with existing image capabilities (PNG, JPG, GIF, WebP)
- 🔌 **Adapter Support**: Native integration for Anthropic and Gemini
- 🔗 **Multiple Sources**: Load from file picker, URLs, or Files API references
- 🎨 **File Picker Integration**: Works with Telescope, fzf-lua, mini.pick, Snacks, and default picker
- 🧩 **Pure Extension**: No modifications to CodeCompanion core required

## Supported File Types

### Documents
- PDF (`.pdf`)
- Microsoft Word (`.doc`, `.docx`)
- Microsoft Excel (`.xls`, `.xlsx`)
- Microsoft PowerPoint (`.ppt`, `.pptx`)
- Rich Text Format (`.rtf`)
- CSV (`.csv`)
- Plain Text (`.txt`, `.md`)

### Images
- PNG (`.png`)
- JPEG (`.jpg`, `.jpeg`)
- GIF (`.gif`)
- WebP (`.webp`)
- BMP (`.bmp`)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "olimorris/codecompanion.nvim",
    dependencies = {
        "yourusername/codecompanion-attachments.nvim",
    },
    config = function()
        require("codecompanion").setup({
            extensions = {
                "attachments",  -- Extension name without 'codecompanion-' prefix
            },
        })
    end,
}
```

Or with options:

```lua
{
    "olimorris/codecompanion.nvim",
    dependencies = {
        "yourusername/codecompanion-attachments.nvim",
    },
    config = function()
        require("codecompanion").setup({
            extensions = {
                attachments = {
                    enabled = true,  -- defaults to true
                    opts = {
                        -- Custom adapter transformers
                        adapters = {},
                    },
                },
            },
        })
    end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "olimorris/codecompanion.nvim",
    requires = {
        "yourusername/codecompanion-attachments.nvim",
    },
    config = function()
        require("codecompanion").setup({
            extensions = {
                "attachments",  -- Extension name without 'codecompanion-' prefix
            },
        })
    end,
}
```

## Configuration

### Basic Setup

The extension automatically registers the `/attachment` slash command and patches supported adapters. No additional configuration required for basic usage.

### Custom Attachment Directories

Configure search directories for the file picker:

```lua
require("codecompanion").setup({
    interactions = {
        chat = {
            slash_commands = {
                attachment = {
                    opts = {
                        dirs = {
                            "~/Documents",
                            "~/Downloads",
                        },
                    },
                },
            },
        },
    },
    extensions = {
        "attachments",
    },
})
```

### Custom Adapter Transformers

Add support for additional adapters by registering custom transformers:

```lua
require("codecompanion").setup({
    extensions = {
        attachments = {
            enabled = true,
            opts = {
                adapters = {
                    my_custom_adapter = function(messages, adapter)
                        -- Transform attachment messages for your adapter
                        for _, m in ipairs(messages) do
                            if m._meta and m._meta.tag == "attachment" and m.context then
                                -- Apply your transformation logic here
                                m.content = transform_for_my_adapter(m)
                            end
                        end
                        return messages
                    end,
                },
            },
        },
    },
})
```

## Usage

### In Chat

1. Open a CodeCompanion chat (`:CodeCompanion`)
2. Type `/attachment` and press enter
3. Choose your attachment source:
   - **File**: Browse and select files using your configured picker
   - **URL**: Enter a URL to download and attach
   - **Files API**: Reference a file uploaded to the provider's Files API (if supported)

### Attachment Sources

#### File Picker
```
/attachment
> File
```
Browse your filesystem using your preferred picker (Telescope, fzf, etc.)

#### URL
```
/attachment
> URL
> https://example.com/document.pdf
```
Download and attach files from URLs

#### Files API
```
/attachment
> Files API
> file_12345abcde
```
Reference files already uploaded to provider's storage (Anthropic, etc.)

## Adapter Compatibility

| Adapter | Document Upload | URL Upload | Files API | Status |
|---------|----------------|------------|-----------|---------|
| Anthropic | ✅ | ✅ | ✅ | Full support |
| Gemini | ✅ | ✅ | ❌ | Partial support |
| Gemini CLI | ✅ | ✅ | ❌ | Partial support |
| OpenAI | 📋 | 📋 | 📋 | Planned |
| Copilot | 📋 | 📋 | 📋 | Planned |

## How It Works

The extension uses a **monkey-patching** approach to add attachment support without modifying CodeCompanion core:

1. **Adapter Patching**: Wraps the `adapters.resolve()` function to intercept adapter creation
2. **Message Transformation**: Patches each adapter's `form_messages()` handler to transform attachment messages into the provider's native format
3. **Chat Integration**: Adds the `add_attachment_message()` method to the Chat class
4. **Slash Command**: Registers the `/attachment` command through CodeCompanion's extension system

### Architecture

```
User Input (/attachment)
    ↓
Slash Command Handler
    ↓
File Picker / URL Input / Files API
    ↓
Utils (encode, validate)
    ↓
Chat:add_attachment_message()
    ↓
Message with _meta.tag = "attachment"
    ↓
Adapter form_messages() [PATCHED]
    ↓
Transform to provider format
    ↓
Send to LLM
```

## Troubleshooting

### Slash command not showing up

Make sure the extension is loaded:
```lua
require("codecompanion").setup({
    extensions = {
        "attachments",
    },
})
```

### Attachments not working with my adapter

Check adapter compatibility table above. The adapter must have `attachment_upload = true` in its opts.

### File too large

Most providers have size limits:
- Anthropic: 32MB per file
- Gemini: 20MB per file

### Enable debug logging

```lua
require("codecompanion").setup({
    log_level = "DEBUG",
})
```

Then check `:CodeCompanionLog` for detailed information.

## Contributing

Contributions welcome! To add support for a new adapter:

1. Create a transformer function in `adapter_patches.lua`
2. Add the adapter to the `transformers` table
3. Update the compatibility table in this README
4. Submit a PR

## License

MIT

## Credits

Based on PR [#2632](https://github.com/olimorris/codecompanion.nvim/pull/2632) by the CodeCompanion community. Refactored as an extension to maintain separation of concerns and enable community-driven adapter support.
