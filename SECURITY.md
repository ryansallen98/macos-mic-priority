# Security Policy

## Supported versions

Security fixes are provided for the latest published version.

## Reporting a vulnerability

Please report a vulnerability privately to `ryan@rallen.dev`. Do not include passwords, tokens, private keys, recordings, or other sensitive information. A minimal description and safe reproduction steps are enough for an initial report.

## Security design

macOS Mic Priority uses public macOS frameworks, does not run with elevated privileges, does not record audio, and has no network client or server. Release artifacts include a SHA-256 checksum. Public binaries should be Developer ID signed and notarized when signing infrastructure is available.
