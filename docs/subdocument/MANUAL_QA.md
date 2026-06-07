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
- Launch Brass Pulse KFK.
- Confirm the app icon appears correctly on the Home Screen.
- Confirm the app icon is recognizable at Home Screen size and does not show clipped important details.
- Confirm the Home Screen label reads `Brass Pulse KFK`.
- Confirm the app opens without permission prompts.
- Confirm the default song loads with visible measures and a BPM value.

## Playback Audio

- Tap Play and confirm clicks are audible.
- Tap Stop and confirm clicks stop immediately.
- Change BPM with the slider while playing and confirm playback stops; press Play again and confirm it starts at the new tempo.
- Use tap tempo and confirm the displayed BPM changes after repeated taps.
- Enable count-in and confirm four count-in beats happen before the selected sequence.
- Confirm the first beat of each measure has a stronger accent.
- Confirm grouped odd meters, such as `7/8` with `2+2+3`, have the expected subaccent pattern.

## Background Audio

- Start playback, lock the device, and listen for at least 30 seconds.
- Unlock the device and confirm the UI is responsive.
- Start playback, switch to another app, and confirm clicks continue.
- Return to Brass Pulse KFK and confirm Play/Stop still works.
- Stop playback, lock the device, and confirm no unnecessary clicks continue.

## Audio Interruptions And Routes

- Start playback, activate Siri, then dismiss Siri.
- Confirm playback stops and the Play control shows the stopped state.
- Press Play again and confirm playback restarts normally.
- Start playback with headphones connected.
- Disconnect the headphones and confirm the app does not crash.
- Reconnect headphones and confirm playback can continue or be restarted.
- If possible, test an incoming phone call interruption.
- Confirm the call interruption stops playback and requires pressing Play again afterward.

## Song Library

- Rename the current song.
- Lock the current song and confirm the name, first-measure, grouping, insert, delete, and signature controls become disabled while Play/Stop, tempo, count-in, and loop-range controls remain usable.
- Unlock the current song with the lock button and confirm editing works again and the song does not automatically re-lock.
- Select each built-in song and confirm it is read-only by default.
- On a read-only song, long-press locked edit controls such as song name, first measure number, insert, delete, grouping, and measure numerator/denominator. Confirm each unlocks temporarily, the held control immediately performs its edit action where applicable, each edit restarts the timeout, and the song locks again after 3 seconds with no edits.
- Create a new song.
- Duplicate a read-only song and confirm the copy is editable.
- Expand the inline song picker and switch between songs.
- Confirm read-only songs show a lock indicator in the inline song picker.
- Confirm the inline song picker collapses after selecting, creating, duplicating, resetting, or deleting a song.
- Delete a non-current or duplicate song if available.
- Force quit and relaunch the app.
- Confirm song names, BPM, sequence edits, loop range, start measure, count-in setting, and read-only state persist.
- Reset a built-in song and confirm it returns to its original sequence and read-only state.

## Measure Editing

- Confirm every measure row shows compact numerator and denominator controls without opening a separate editor.
- Drag vertically on the numerator and denominator controls to step to a common signature like `5/8`, and confirm the measure updates immediately while the active value remains visible in the floating readout above the finger.
- On a read-only song, long-press a numerator or denominator, keep holding, then drag vertically. Confirm the song unlocks and the same held drag edits the value without needing a second touch.
- Drag elsewhere in the sequence list and confirm the list scrolls without accidentally changing the signature.
- Edit a measure with grouping like `7/8 2+2+3`, if the grouping picker exposes that preset for the measure.
- Confirm simple meters such as `2/4`, `3/4`, and `4/4` do not show single-number grouping choices that are equivalent to `None`.
- Change the numerator after setting grouping and confirm invalid grouping is cleared instead of corrupting the sequence.
- Insert a measure and confirm the inserted measure has the same compact signature controls as the other rows.
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
- Confirm the transport controls, BPM, beat dots, loop controls, and sequence list are all reachable.
- Enable the measure-focused sequence mode and confirm many more measures are visible while play/pause, BPM, tap tempo, and loop count remain reachable.
- Expand and collapse sequence settings and confirm first-measure and loop-range controls remain usable.
- Confirm text fields do not overlap controls when the keyboard is visible.
- Confirm the keyboard Done button commits text-field edits such as the first measure number.
- Confirm the played measure scrolls into view during playback.
- Test Dynamic Type at a larger text size and confirm critical controls remain usable.

## iPad Layout

- Test portrait and landscape orientation.
- Resize iPad windows across narrow, one-column split, and two-column split widths.
- Confirm the left playback panel and right sequence area fit without overlap.
- Confirm sequence scrolling keeps the active measure visible with both one and two sequence columns.
- Confirm inline pickers and text fields are reachable with touch.
- Confirm long song names, large measure numbers, and larger Dynamic Type do not overlap controls at each width.
- If using an external keyboard, confirm text fields such as song name and first measure number still commit when focus leaves fields.

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
- Confirm the App Store app name is `Brass Pulse KFK`, or intentionally different from the Home Screen label.
- Confirm the privacy behavior matches the App Store privacy label: no tracking and no collected data.
- Confirm background audio is used only for audible metronome playback.
- Confirm App Review notes explain how to start playback, edit measures, test loops, and use built-in songs.
