# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a fresh repository named `gentoo-portage`, which appears to be intended for Gentoo Portage-related development. The repository is currently empty with no commits or files.

## Development Setup

Since this repository is empty, the initial setup will depend on the intended purpose:

- **Portage Overlay**: If creating a Gentoo Portage overlay, the typical structure would include category directories with ebuild files
- **Portage Tooling**: If developing tools for Portage, common languages include Python (Portage is Python-based), Shell scripts, or other system languages
- **Documentation**: If creating documentation for Portage workflows or packages

## Common Gentoo/Portage Conventions

When working with Gentoo Portage projects:

- Ebuild files follow strict naming conventions: `package-version.ebuild`
- Category directories organize packages by type (e.g., `dev-python/`, `sys-apps/`, `net-misc/`)
- Manifest files are generated automatically via `repoman manifest` or `pkgdev manifest`
- Metadata.xml files describe package information and maintainers

## Future Development Commands

Once the project structure is established, common commands may include:

```bash
# For Portage overlays
repoman scan          # Check ebuild quality
pkgdev manifest       # Generate/update Manifest files
emerge --ask package  # Test package installation

# For Python-based Portage tools
python -m pytest     # Run tests (if using pytest)
python setup.py test  # Run tests (if using setuptools)
flake8 .             # Python linting
mypy .               # Python type checking
```

## Notes for Future Development

- This repository currently contains no source code or configuration files
- The development workflow and tooling will depend on the specific purpose of the project
- Consider adding appropriate configuration files (setup.py, pyproject.toml, Makefile, etc.) based on the chosen technology stack
- Gentoo projects typically follow Gentoo development standards and GLEP (Gentoo Linux Enhancement Proposals)