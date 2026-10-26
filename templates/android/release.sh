#!/usr/bin/env bash
# Git Bash launcher for release.bat -> release.ps1
cd "$(dirname "$0")"
exec cmd //c release.bat
