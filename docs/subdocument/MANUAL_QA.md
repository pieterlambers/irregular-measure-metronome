# Manual QA

Use this checklist on real devices before TestFlight or App Store submission. Unit tests cover model and sequencing rules; these checks cover audio, lifecycle, layout, and touch behavior that need iPhone and iPad hardware.

## Devices

- iPhone with the current minimum supported iOS version, or the oldest device you intend to support.
- iPhone with the latest available iOS version.
- iPad with the latest available iPadOS version.
- Wired headphones or AirPods/Bluetooth headphones, if available.

## Install Smoke Test

- Delete any previous install before the fresh install.
- Install a fresh build.
- Launch Brass Pulse.
- Confirm the app icon appears correctly on the Home Screen.
- Confirm the app icon is recognizable at Home Screen size and does not show clipped important details.
- Confirm the Home Screen label reads `Brass Pulse`.
- Confirm the app opens without permission prompts.
- Confirm the default song loads with visible measures and a BPM value.

## Playback Audio

- Tap Play and confirm clicks are audible.
- Tap Stop and confirm clicks stop immediately.
- Change BPM with the slider while playing and confirm playback continues at the new tempo.
- Use tap tempo and confirm the displayed BPM changes after repeated taps.
- Enable count-in and confirm four count-in beats happen before the selected sequence.
- Confirm the first beat of each measure has a stronger accent.
- Confirm grouped odd meters, such as `7/8` with `2+2+3`, have the expected subaccent pattern.

## Background Audio

- Start playback, lock the device, and listen for at least 30 seconds.
- Unlock the device and confirm the UI is responsive.
- Start playback, switch to another app, and confirm clicks continue.
- Return to Brass Pulse and confirm Play/Stop still works.
- Stop playback, lock the device, and confirm no unnecessary clicks continue.

## Audio Interruptions And Routes

- Start playback, activate Siri, then dismiss Siri.
- Confirm playback pauses or resumes acceptably after the interruption.
- Start playback with headphones connected.
- Disconnect the headphones and confirm the app does not crash.
- Reconnect headphones and confirm playback can continue or be restarted.
- If possible, test an incoming phone call interruption.

## Song Library

- Rename the current song.
- Create a new song.
- Duplicate a song.
- Expand the inline song picker and switch between songs.
- Confirm the inline song picker collapses after selecting, creating, duplicating, resetting, or deleting a song.
- Delete a non-current or duplicate song if available.
- Force quit and relaunch the app.
- Confirm song names, BPM, sequence edits, loop range, start measure, and count-in setting persist.
- Reset a built-in song and confirm it returns to its original sequence.

## Measure Editing

- Edit a measure to a valid signature like `5/8`.
- Edit a measure with grouping like `7/8 2+2+3`, if the UI exposes grouping for that measure.
- Try invalid values such as `0/4`, `3/5`, or a grouping that does not sum to the numerator.
- Confirm invalid edits do not corrupt the sequence.
- Insert a measure.
- Delete a measure.
- Confirm the final remaining measure cannot be deleted.

## Looping

- Enable loop range.
- Set a loop start and loop end inside the sequence.
- Start playback and confirm only that range repeats.
- Confirm the loop count increments after wrapping.
- Change the sequence while looping and confirm playback stops or resets cleanly.
- Disable loop range and confirm the full sequence plays.

## iPhone Layout

- Test portrait orientation.
- Confirm the transport controls, BPM, beat dots, pendulum, loop controls, and sequence list are all reachable.
- Confirm text fields do not overlap controls when the keyboard is visible.
- Confirm the keyboard Done button commits edits.
- Confirm the played measure scrolls into view during playback.
- Test Dynamic Type at a larger text size and confirm critical controls remain usable.

## iPad Layout

- Test portrait and landscape orientation.
- Confirm the left playback panel and right sequence area fit without overlap.
- Confirm sequence grid/list scrolling keeps the active measure visible.
- Confirm inline pickers and text fields are reachable with touch.
- If using an external keyboard, confirm text editing still commits when focus leaves fields.

## Screenshots

- Capture current iPhone screenshots for App Store Connect.
- Capture current iPad screenshots for App Store Connect.
- Confirm screenshots show the actual app name, icon style, and current UI.
- Confirm screenshots do not show placeholder songs, broken layouts, debug state, or private test data.
- Confirm screenshot content matches the App Store description and review notes.

## Persistence And Relaunch

- Change BPM, song name, start measure number, loop range, count-in setting, and several measures.
- Background the app for at least one minute.
- Reopen and confirm state is still present.
- Force quit the app.
- Relaunch and confirm state is still present.
- Reboot the device if practical and confirm state survives.

## App Store Review Pass

- Confirm there is no login requirement.
- Confirm there are no placeholder screens or debug-only labels.
- Confirm there are no broken links in any in-app UI.
- Confirm the App Store bundle ID is `nl.pieterlambers.irregularmetronome`.
- Confirm the App Store app name is `Brass Pulse`, or intentionally different from the Home Screen label.
- Confirm the privacy behavior matches the App Store privacy label: no tracking and no collected data.
- Confirm background audio is used only for audible metronome playback.
- Confirm App Review notes explain how to start playback, edit measures, test loops, and use built-in songs.
