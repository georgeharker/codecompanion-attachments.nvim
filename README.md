# codecompanion-attachments.nvim

Document and image attachment support for [CodeCompanion.nvim](https://codecompanion.olimorris.dev/).

## Features

- 📎 **Document Attachments**: Upload PDFs, text files, markdown, and more
- 🖼️ **Image Support**: Attach images to your conversations  
- 🔍 **File Picker**: Browse and select files from your project
- 🎯 **Multiple Formats**: Support for various document and image formats
- ⚡ **Smart Integration**: Seamlessly works with CodeCompanion's slash command system
- 🔧 **Adapter Support**: Works with Anthropic and Gemini adapters

## Requirements

- Neovim >= 0.8.0
- [codecompanion.nvim](https://codecompanion.olimorris.dev/)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "olimorris/codecompanion.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        "hrsh7th/nvim-cmp", -- Optional: For using slash commands
        "nvim-telescope/telescope.nvim", -- Optional: For using slash commands
        {
            "geohar/codecompanion-attachments.nvim",
            dev = true, -- Remove this if not using local development
        },
    },
    config = function()
        require("codecompanion").setup({
            adapters = {
                anthropic = function()
                    return require("codecompanion.adapters").extend("anthropic", {
                        env = { ANTHROPIC_API_KEY = "ANTHROPIC_API_KEY" },
                        opts = {
                            attachment_upload = true, -- REQUIRED for documents
                        },
                    })
                end,
            },
            extensions = {
                attachments = {
                    enabled = true,
                    opts = {
                        dirs = { "." }, -- Directories to search for files
                    },
                },
            },
        })
    end,
}
```

**IMPORTANT**: Make sure to set `dev = true` and configure lazy.nvim's dev path if installing from a local directory:

```lua
require("lazy").setup({
    dev = {
        path = "~/Development/neovim-plugins", -- Adjust to your path
    },
    -- ... your plugins
})
```

## Configuration

### Enable Attachment Upload for Your Adapter

For **Anthropic** (Claude):
```lua
adapters = {
    anthropic = function()
        return require("codecompanion.adapters").extend("anthropic", {
            opts = {
                attachment_upload = true, -- Required
            },
        })
    end,
}
```

For **Gemini**:
```lua
adapters = {
    gemini = function()
        return require("codecompanion.adapters").extend("gemini", {
            opts = {
                attachment_upload = true, -- Required
            },
        })
    end,
}
```

### Extension Options

```lua
extensions = {
    attachments = {
        enabled = true,
        opts = {
            -- Directories to search when picking files
            dirs = { "." },
            
            -- File patterns to include/exclude (optional)
            -- Uses telescope's file_ignore_patterns if not specified
        },
    },
}
```

## Usage

### Basic Usage

1. Open a CodeCompanion chat: `:CodeCompanionChat`
2. Type `/attachment` and press `<Tab>` or `<CR>`
3. Browse and select your document or image
4. The file will be attached to your next message
5. Ask questions about the attached content!

### Supported File Types

**Documents**:
- PDF (`.pdf`)
- Text files (`.txt`)
- Markdown (`.md`)
- Source code (`.lua`, `.py`, `.js`, `.ts`, etc.)
- And many more...

**Images**:
- PNG (`.png`)
- JPEG (`.jpg`, `.jpeg`)  
- GIF (`.gif`)
- WebP (`.webp`)

### Example Workflow

```
:CodeCompanionChat

> /attachment
[Select a PDF document]

> What are the key points in this document?
[Claude analyzes the document and responds]
```

## How It Works

The extension:

1. **Registers a `/attachment` slash command** that integrates with CodeCompanion's command system
2. **Patches adapter handlers** to transform attachment messages into the proper API format (Anthropic's document blocks or Gemini's inline_data)
3. **Preserves metadata** during transformation so attachments are properly identified
4. **Encodes files** as base64 and includes proper MIME type detection

### Technical Details

- Uses CodeCompanion's extension system (loaded via `lua/codecompanion/_extensions/attachments/`)
- Monkey-patches `form_messages` handler to transform attachments BEFORE processing
- Supports both base64-encoded attachments and URL-based attachments (Anthropic)
- Future support planned for Anthropic's Files API

## Troubleshooting

### Slash Command Not Appearing

1. Make sure the plugin is installed via lazy.nvim
2. Check that `extensions.attachments.enabled = true` in your config
3. Restart Neovim completely
4. Run `:Lazy sync` to ensure the plugin is loaded

### "Prompt Too Long" Error

This usually means the transformation isn't happening. Check:

1. **Adapter configuration**: Ensure `attachment_upload = true` is set
2. **Debug logs**: Enable debug logging and check `:CodeCompanionLog`:
   ```lua
   require("codecompanion").setup({
       opts = {
           log_level = "DEBUG",
       },
   })
   ```
3. **Look for these log messages**:
   - `"Patched adapter 'anthropic' for attachment support"`
   - `"Found attachment message"`
   - `"Transformed to document content block"`

### Extension Not Loading

Check the CodeCompanion log (`:CodeCompanionLog`) for errors like:
```
Error loading extension attachments: module 'codecompanion._extensions.attachments' not found
```

This means the plugin isn't installed properly. Verify:
- Plugin is in lazy.nvim's plugin directory
- No `.cloning` lock files in `~/.local/share/nvim/lazy/`
- Run `:Lazy clean` then `:Lazy sync`

## Development

### Project Structure

```
lua/codecompanion/_extensions/attachments/
├── init.lua              # Extension entry point, setup()
├── adapter_patches.lua   # Monkey patches for adapters
├── chat_integration.lua  # Chat class modifications
├── slash_command.lua     # /attachment command implementation
└── utils.lua            # Encoding, MIME detection
```

### Testing Changes

1. Make your changes in the plugin directory
2. Restart Neovim (or run `:Lazy reload codecompanion-attachments.nvim`)
3. Test with `:CodeCompanionChat` and `/attachment`
4. Check logs with `:CodeCompanionLog` (set `log_level = "DEBUG"`)

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT

## Credits

- Built as an extension for [CodeCompanion.nvim](https://codecompanion.olimorris.dev/) by [@olimorris](https://github.com/olimorris)
- Inspired by the attachment handling in the original CodeCompanion fork
