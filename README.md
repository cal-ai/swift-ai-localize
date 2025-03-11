# Swift AI Localize

A command-line utility for automatically translating Localizable.xcstrings files using the OpenAI ChatGPT API.

## Features

- Parse Localizable.xcstrings files
- Identify strings that need translation
- Translate strings to multiple languages using the ChatGPT API
- Update the Localizable.xcstrings file with the translated strings
- Support for context and comments to improve translation quality
- Auto-detection of languages from the Localizable.xcstrings file
- Environment variable support for API key and model

## Requirements

- Swift 6.0 or later
- macOS 13.0 or later
- OpenAI API key

## Installation

### Build from Source

1. Clone the repository
2. Build the project:

```bash
swift build -c release
```

3. Install the binary:

```bash
cp .build/release/swift-ai-localize /usr/local/bin/swift-ai-localize
```

## Usage

### Translate Strings

```bash
swift-ai-localize translate --file path/to/Localizable.xcstrings --api-key YOUR_OPENAI_API_KEY
```

#### Options

- `--file, -f`: Path to the Localizable.xcstrings file (required)
- `--api-key, -a`: OpenAI API key (can also be set via OPENAI_KEY environment variable)
- `--model, -m`: OpenAI model to use (default: gpt-4o, can also be set via OPENAI_MODEL or MODEL environment variable)
- `--languages, -l`: Target languages to translate to (comma-separated, if not specified, all languages in the file will be used)
- `--verbose, -v`: Show verbose output

#### Environment Variables

- `OPENAI_KEY`: Your OpenAI API key
- `OPENAI_MODEL` or `MODEL`: The OpenAI model to use (default: gpt-4o)

### List Languages

```bash
swift-ai-localize list-languages --file path/to/Localizable.xcstrings
```

## Examples

### Translate to Specific Languages

```bash
swift-ai-localize translate --file path/to/Localizable.xcstrings --api-key YOUR_OPENAI_API_KEY --languages "fr,es,de,ja"
```

### Use a Different Model

```bash
swift-ai-localize translate --file path/to/Localizable.xcstrings --api-key YOUR_OPENAI_API_KEY --model "gpt-3.5-turbo"
```

### Using Environment Variables

```bash
export OPENAI_KEY=YOUR_OPENAI_API_KEY
export MODEL=gpt-4o
swift-ai-localize translate --file path/to/Localizable.xcstrings
```

## License

MIT 