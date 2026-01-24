# Phase 3: Safety Warnings & Documentation - Context

**Gathered:** 2026-01-25
**Status:** Ready for planning

## Phase Boundary

Implement security checks and user guidance for the ddev-claude addon:
- Detect and warn about risky mount configurations
- Check and offer protection for .env files in Claude settings
- Create comprehensive README documentation
- Build Bats test suite for CI/CD validation

This phase focuses on safety warnings (startup checks) and documentation (README + tests), not adding new firewall features or security capabilities.

## Implementation Decisions

### Startup warnings (mount detection)
- **Risky mount definition:** Any directory mounted outside the project root (/var/www/html) triggers a warning
- **Warning behavior:** Block startup until user explicitly acknowledges the warning
- **Warning detail level:** Detailed - show full breakdown with recommendations for each risky mount
- **Detection timing:** Before firewall setup (early in startup sequence)

### .env protection (Claude settings)
- **Detection method:** Claude decides (check settings.json for denylist rules or test file access)
- **Configuration location:** Ask user whether to add deny rule to global (~/.claude/settings.json) or project-specific config
- **Protection offer:** Prompt for confirmation before adding the deny rule to Claude settings
- **Decline behavior:** Block until acknowledged if user declines .env protection

### Documentation structure (README)
- **Target audience:** Developers only (no non-technical users)
- **Structure:** User-focused flow with detailed explanations
  - Quick start guide
  - Configuration guide
  - Security explanations
- **Security depth:** Tiered approach - high-level overview + deep dive sections for different technical audiences
- **Examples:** Include configuration examples for common stacks (Laravel, npm, generic projects)
- **Limitations:** Claude decides which limitations to document (balance transparency with overwhelming detail)

### Test coverage (Bats suite)
- **Test focus:** Claude decides what's most important to test
- **File organization:** By feature (install.bats, firewall.bats, whitelist.bats)
- **Error handling:** Test error conditions and edge cases comprehensively
- **CI/CD integration:** GitHub Actions workflow

### Claude's Discretion
- How to detect .env protection in Claude settings (check config vs test access)
- What limitations to document in README
- What test scenarios to focus on in Bats suite

## Specific Ideas

- Developers are the only users - explain everything in detail, don't oversimplify
- Startup warnings should help users understand security implications, not just alert them
- Documentation should guide developers through the whole journey: quick start → configuration → security

## Deferred Ideas

None — discussion stayed within phase scope.

---

*Phase: 03-safety-warnings-and-documentation*
*Context gathered: 2026-01-25*
