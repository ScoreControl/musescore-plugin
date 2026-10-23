# ScoreControl MuseScore plugin

This repository currently contains a single-file MuseScore QML plugin that
prototypes the ScoreControl project, branch, and commit interface.

## Current prototype behavior

- Demonstrates a local sign-in, project creation, and automatic `main` branch.
- Keeps branch and commit history in memory for the current plugin session.
- Supports selecting a branch HEAD, selecting a commit, creating a branch from
  the selected commit, and adding commits with messages.
- Provides a bright/dark theme toggle with explicit high-contrast text,
  control, history, and notice colors.
- Sizes the dialog to the available screen space and scales the interface
  uniformly when the dialog dimensions change.
- Writes the project, branch, local demo commit ID, and commit message to the
  open score's metadata when creating a project or a commit.
- Demonstrates the stale-base guard and branch flow locally.

The sign-in and repository are mock-only: there is no authentication service,
remote API, persistent local database, multi-user synchronization, real commit
hash, or server-side concurrency guard. The plugin does not detect score edits,
upload score content, download history, or restore an older score file. To use
an older version, obtain and open that version's score file in MuseScore; the
plugin can only display and update metadata references. Metadata is not a score
snapshot.

## Install

Copy `ScoreControlPlugin.qml` into MuseScore's user plugins directory, enable
the plugin in Plugin Manager, and run **Plugins → ScoreControl** with a score
open. MuseScore 4's plugin API is compatible with the `import MuseScore 3.0`
QML plugin interface used here.
