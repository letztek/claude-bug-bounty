# Security Policy

## Supported Versions

| Version | Supported |
|:---|:---|
| v5.x (latest) | Yes |
| v4.x | Critical fixes only |
| < v4.0 | No |

## Reporting a Vulnerability

If you find a security issue in this toolkit itself (not a bug bounty finding on a third-party target), please **do not open a public GitHub issue**.

**Report privately via GitHub Security Advisories:**
[github.com/letztek/claude-bug-bounty/security/advisories/new](https://github.com/letztek/claude-bug-bounty/security/advisories/new)

This is a fork of [shuvonsec/claude-bug-bounty](https://github.com/shuvonsec/claude-bug-bounty). If the issue is in upstream code rather than fork-specific changes, please also report it upstream.

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Your suggested fix (optional)

You will receive a response within **72 hours**. Critical issues are patched and released within 7 days.

## Scope

This policy covers vulnerabilities in:
- `tools/` — Python and shell scanner scripts
- `memory/` — hunt memory system
- `install.sh` / `install_tools.sh` — installer scripts
- `demo/` — local demo server

**Out of scope:** Third-party programs you test using this toolkit. Those belong in their respective bug bounty programs.

## Responsible Disclosure

We follow coordinated disclosure. We will:
- Acknowledge your report within 72 hours
- Keep you updated on the fix timeline
- Credit you in the release notes (unless you prefer anonymity)
