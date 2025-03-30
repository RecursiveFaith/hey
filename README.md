# hey.sh - Terminal AI Assistant Framework

A lightweight Bash framework for building AI-powered terminal tools and agents. Integrates with your shell for seamless AI assistance in your development workflow.

## Prerequisites

- Bash 4.0+
- Dependencies: `curl jq xsel tree`
- API key from [OpenRouter](https://openrouter.ai) or [Groq](https://groq.com)

## Quick Setup

```bash
# 1. Clone the repository
git clone https://github.com/oz/hey.sh
cd hey.sh

# 2. Add to your ~/.bashrc
export API_OPENROUTER='sk-or-v1-...'    # Required: from openrouter.ai
export API_GROQ=''                      # Optional: from groq.com

export HEY_BASE="$HOME/github/oz/hey"
export HEY_MODEL='anthropic/claude-3-sonnet'
export HEY_HOSTNAME='openrouter'

alias hey="$HEY_BASE/chat"

# 3. Apply changes
source ~/.bashrc
```

## Usage

### Basic Commands

```bash
# Direct questions
hey "explain this error"

# Interactive chat
hey "let's debug" --loop

# With system prompt
hey "analyze code" "You are a senior developer"

# Using specific model
hey --model "anthropic/claude-3-sonnet" "explain"
```

### Command Line Options

```bash
hey [prompt] [flags]

Flags:
  --hostname     # API provider (openrouter|groq)
  --model        # Model ID to use
  --prompt       # Your question/prompt
  --system       # System prompt for context
  --debug        # Enable debug output
  --more        # Use pager for long responses
  --loop        # Enable interactive chat mode

Model Shortcuts:
  --sota        # State of the art model (default)
  --flash       # Fast response model
  --search      # Search-optimized model
  --rp          # Role-playing model
  --liquid      # Fluid conversation model
  --code        # Code-optimized model
```

### Pipeline Integration

```bash
# Code review
git diff | hey "review these changes"

# Log analysis
tail -n 100 error.log | hey "find critical issues"

# Documentation
cat src/*.js | hey "generate JSDoc" > docs.md

# Multi-step processing
cat data.log | \
  hey "extract errors" | \
  hey "categorize by severity" | \
  hey "suggest fixes" > report.md
```

### Shorthand Syntax

```bash
# These are equivalent:
hey "analyze this" "You are an expert"
hey --prompt "analyze this" --system "You are an expert"

# These do the same thing:
hey "hello" --model anthropic/claude-3-sonnet --hostname openrouter
hey --sota "hello"
```

## Configuration

### Environment Variables

```bash
HEY_BASE       # Framework installation directory
HEY_MODEL      # Default AI model to use
HEY_HOSTNAME   # Default API provider (openrouter|groq)
```

### Supported Models

OpenRouter:
- `anthropic/claude-3-sonnet` (default)
- `google/gemini-pro`
- `meta/llama-3`
- `mistral/mixtral-8x7b`

Groq:
- `claude-3-opus`
- `mixtral-8x7b`
- `llama-70b`

### Model Aliases

```bash
--sota    → Current best model
--flash   → Fast response model
--search  → Search-optimized model
--rp      → Role-playing model
--liquid  → Conversation model
--code    → Programming model
```

## Project Structure

```bash
hey.sh/
├── chat           # Main script
├── default        # Default settings
├── models.conf    # Model configurations
└── colors        # Terminal color definitions
```

## Examples

### Code Assistance

```bash
# Review changes
git diff | hey "review changes"

# Generate commit message
git diff | hey "summarize as commit message" | xsel -ib

# Code improvement suggestions
cat src/*.js | hey "suggest improvements"
```

### Documentation

```bash
# Generate docs
cat src/*.js | hey "generate JSDoc comments"

# Create README sections
ls -R | hey "document directory structure"
```

### System Administration

```bash
# Analyze logs
journalctl -n 100 | hey "find errors"

# Security audit
auth.log | hey "detect suspicious patterns"

# Config review
cat nginx.conf | hey "review configuration"
```

## Contributing

1. Fork repository
2. Create feature branch
3. Submit pull request

## License

MIT

---

**Security Note:** Keep API keys secure and never commit them to version control.
