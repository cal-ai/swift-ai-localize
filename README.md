# Swift AI Localize

A command-line tool for managing and translating iOS/macOS localization files (`.xcstrings`) using OpenAI's GPT models.

## Features

- Analyze localization files to see translation status
- Automatically translate missing strings to multiple languages
- Uses OpenAI's GPT models for high-quality translations
- Parallel processing for efficient translation of multiple languages

## Installation

### Download Binary

Download the latest release from the [Releases](https://github.com/yourusername/swift-ai-localize/releases) page.

### Build from Source

```bash
git clone https://github.com/yourusername/swift-ai-localize.git
cd swift-ai-localize
swift build -c release
```

The binary will be available at `.build/release/swift-ai-localize`.

## Usage

### Get Information About a Localization File

```bash
swift-ai-localize info path/to/your/Localizable.xcstrings
```

This will show:
- Source language
- Available target languages
- Total number of strings
- Translation status for each language

### Translate Missing Strings

```bash
swift-ai-localize translate path/to/your/Localizable.xcstrings --languages=fr,de,es
```

Options:
- `--languages` or `-l`: Comma-separated list of target languages (optional, defaults to all available languages)
- `--api-key` or `-a`: OpenAI API key (can also be set via `OPENAI_API_KEY` environment variable)
- `--model` or `-m`: OpenAI model to use (default: "gpt-4o")
- `--batch-size` or `-b`: Number of strings to translate in parallel (default: 5)
- `--verbose` or `-v`: Enable verbose output

Example with all options:

```bash
swift-ai-localize translate path/to/your/Localizable.xcstrings \
  --languages=fr,de,es \
  --api-key=your-openai-api-key \
  --model=gpt-4o \
  --batch-size=10 \
  --verbose
```

## Environment Variables

- `OPENAI_API_KEY`: Your OpenAI API key

## License

MIT 