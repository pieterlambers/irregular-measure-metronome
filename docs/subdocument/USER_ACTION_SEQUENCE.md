# User Action Sequence Diagram

## Participants

- [User](participants/user.md)
- [ContentView](participants/contentview.md)
- [MetronomeModel](participants/metronomemodel.md)
- [ClickEngine](participants/clickengine.md)
- [UserDefaults](participants/userdefaults.md)
- [Task.sleep](participants/tasksleep.md)
- [ClickEngine scheduler queue](AUDIO_SCHEDULING.md)

```mermaid
sequenceDiagram
    actor User
    participant View as ContentView
    participant Model as MetronomeModel
    participant Engine as ClickEngine
    participant Defaults as UserDefaults
    participant Timer as Task.sleep
    participant Queue as ClickEngine scheduler queue

    rect rgb(35, 35, 40)
        Note over User,Defaults: Select Song
        User->>View: Tap song selector button
        View->>View: expand inline song picker
        User->>View: Tap song row
        View->>Model: selectSong(song)
        Model->>Defaults: save current song into encoded song library
        Model->>Model: stop()
        Model->>Engine: stop buffered scheduling
        Model->>Model: apply selected song name, BPM, sequence, start measure, and loop range
        Model->>Defaults: save encoded song library with currentSongID
        Model-->>View: publish selected song state
        View->>View: collapse inline song picker
    end

    rect rgb(35, 35, 40)
        Note over User,Defaults: Rename Song
        User->>View: Edit song name field
        View->>Model: currentSongName = typed value
        Model->>Model: limit name to 60 characters
        Model->>Defaults: save encoded song library
        Model-->>View: publish renamed current song
    end

    rect rgb(35, 35, 40)
        Note over User,Defaults: Create, Duplicate, Reset, or Delete Song
        alt Create song
            User->>View: Tap new song button
            View->>Model: createSong()
            Model->>Defaults: save current song into encoded song library
            Model->>Model: stop()
            Model->>Model: append default named song
            Model->>Model: apply new song
            Model->>Defaults: save encoded song library
        else Duplicate song
            User->>View: Tap duplicate song button
            View->>Model: duplicateCurrentSong()
            Model->>Defaults: save current song into encoded song library
            Model->>Model: stop()
            Model->>Model: copy current song with new ID, copied measure IDs, and Copy name
            Model->>Model: apply duplicated song
            Model->>Defaults: save encoded song library
        else Reset built-in song
            User->>View: Tap reset song button
            alt Current song is not built-in
                View->>View: reset button is disabled
            else Current song is built-in
                View->>Model: resetCurrentSongToBuiltIn()
                Model->>Model: replace current song with hardcoded built-in version
                Model->>Model: apply reset song
                Model->>Defaults: save encoded song library
            end
        else Delete song
            User->>View: Tap delete song button
            alt Only one song remains
                View->>View: delete button is disabled
            else More than one song remains
                View->>Model: deleteCurrentSong()
                Model->>Model: stop()
                Model->>Model: remove current song and apply next available song
                Model->>Defaults: save encoded song library
            end
        end
        Model-->>View: publish updated song list and current song
    end

    rect rgb(35, 35, 40)
        Note over User,Timer: Play
        User->>View: Tap play button
        View->>Model: togglePlayback()
        Model->>Model: start()
        Model->>Model: reset currentBeat, currentMeasureIndex, loopCount, isCountingIn
        Model->>Model: increment playbackGeneration
        Model->>Engine: start(bpm, sequence, position, active loop range, loop count, optional 4/4 count-in, onBeat)
        Engine->>Engine: lazily create audio engine/player if needed, activate audio session, and prepare click buffers
        Engine->>Queue: stop previous scheduler and create generation
        opt 4/4 count-in enabled
            Queue->>Engine: schedule four quarter-note count-in beats from active loop start
            Engine-->>Model: onBeat(loopStartIndex, count-in beat, loopCount, isCountIn)
            Model->>Model: publish isCountingIn and count-in beat
        end
        Queue->>Queue: fill buffered queue up to maxQueuedBeats
        Queue->>Engine: schedule click buffer and silence buffer per beat
        Queue->>Engine: start player after initial buffers are queued
        Queue->>Queue: refill every 100 ms while generation is current
        Engine-->>Model: onBeat(measureIndex, beat, loopCount)
        Model->>Model: ignore stale callback if generation changed
        Model->>Model: publish currentMeasureIndex/currentBeat/loopCount
        Model->>Model: flash()
        Model->>Timer: sleep(80 ms)
        Timer-->>Model: clear flashBPM
        Model-->>View: publish playback state
        View->>View: highlight played measure and auto-scroll sequence pane to keep it visible
    end

    rect rgb(35, 35, 40)
        Note over User,Timer: Pause
        User->>View: Tap pause button
        View->>Model: togglePlayback()
        Model->>Model: stop()
        Model->>Model: increment playbackGeneration
        Model->>Engine: stop()
        Engine->>Queue: cancel scheduler and stop player
        Model->>Timer: cancel flashTask
        Model->>Model: reset currentBeat and pendulumDirection
        Model-->>View: publish stopped state
    end

    rect rgb(35, 35, 40)
        Note over User,Timer: Change BPM
        User->>View: Drag BPM slider
        View->>Model: bpm = rounded slider value
        Model->>Model: clamp bpm to 20...300
        Model->>Defaults: save encoded song library
        alt Playback is running
            Model->>Model: restartPlaybackFromCurrentPosition()
            Model->>Model: increment playbackGeneration
            Model->>Engine: start(bpm, sequence, current position, active loop range, onBeat)
            Engine->>Queue: replace buffered scheduler generation
            Queue->>Queue: schedule future beats with updated interval
        else Playback is stopped
            Model-->>View: publish bpm and tempoName
        end
    end

    rect rgb(35, 35, 40)
        Note over User,Timer: Tap Tempo
        User->>View: Tap TEMPO button
        View->>Model: tapTempo()
        Model->>Model: append tap timestamp
        Model->>Timer: cancel previous tap reset
        Model->>Timer: sleep(2500 ms)
        alt Fewer than 2 taps
            Model-->>View: keep tapTempoText as TAP
        else 2 or more taps
            Model->>Model: average tap intervals
            Model->>Model: bpm = clamped calculated tempo
            Model->>Defaults: save encoded song library
            Model->>Model: tapTempoText = bpm
            alt Playback is running
                Model->>Model: restartPlaybackFromCurrentPosition()
                Model->>Engine: restart buffered scheduling at tapped tempo
            end
            Model-->>View: publish bpm and tapTempoText
        end
        Timer-->>Model: clear tapTimes and reset tapTempoText
        Model-->>View: publish reset tapTempoText
    end

    rect rgb(35, 35, 40)
        Note over User,Defaults: Change First Measure Number
        User->>View: Enter first measure number or adjust stepper
        View->>View: allow empty in-progress text and strip non-digits
        User->>View: Tap keyboard Done or move focus away
        View->>Model: startMeasureNumber = new value
        Model->>Model: clamp startMeasureNumber to 0...9999
        Model->>Defaults: save encoded song library
        Model-->>View: publish consecutive displayed measure numbers
    end

    rect rgb(35, 35, 40)
        Note over User,Defaults: Change Loop Range
        User->>View: Toggle loop range or adjust from/to steppers
        View->>Model: isLoopRangeEnabled / updateLoopStartMeasureNumber() / updateLoopEndMeasureNumber()
        Model->>Model: map displayed measure numbers to clamped sequence indices
        Model->>Defaults: save encoded song library
        alt Playback is running
            Model->>Model: restartPlaybackAtLoopStartIfNeeded()
            Model->>Engine: start(bpm, sequence, loop start, active loop range, onBeat)
        else Playback is stopped
            Model-->>View: publish loop range and row highlighting
        end
    end

    rect rgb(35, 35, 40)
        Note over User,Defaults: Duplicate Local Measure and Edit Inline
        User->>View: Tap insert button at a sequence boundary
        View->>Model: duplicateMeasure(at)
        Model->>Model: copy first measure when inserting before row 1
        Model->>Model: otherwise copy previous measure and grouping
        Model->>Defaults: save encoded song library
        Model->>Model: derive consecutive measure numbers from startMeasureNumber
        alt Playback is running
            Model->>Model: stop()
            Model->>Engine: stop buffered scheduling
            Model->>Timer: cancel flashTask
        end
        Model-->>View: publish updated sequence
        View->>View: open inline editor for inserted measure
        User->>View: Enter time signature text such as 7/8
        User->>View: Tap row checkmark, keyboard Done, or move focus away
        View->>View: parse numerator/denominator and validate ranges 1...24 / 1...64
        alt Inputs are invalid
            View->>View: mark inline time signature field invalid
        else Inputs are valid
            View->>Model: updateMeasure(measure, numerator, denominator)
            Model->>Model: update TimeSignature and clean invalid grouping
            Model->>Defaults: save encoded song library
            alt Playback is running
                Model->>Model: stop()
                Model->>Engine: stop buffered scheduling
                Model->>Timer: cancel flashTask
            end
            Model-->>View: publish updated sequence
        end
    end

    rect rgb(35, 35, 40)
        Note over User,Defaults: Change Measure Grouping
        User->>View: Open grouping picker on a sequence row
        User->>View: Choose None or a grouping preset
        View->>Model: updateGrouping(for, grouping)
        Model->>Model: validate grouping sums to numerator
        Model->>Defaults: save encoded song library
        alt Playback is running
            Model->>Model: stop()
            Model->>Engine: stop buffered scheduling
            Model->>Timer: cancel flashTask
        end
        Model-->>View: publish updated sequence and grouping label
    end

    rect rgb(35, 35, 40)
        Note over User,Defaults: Delete Measure
        User->>View: Tap delete button on a sequence row
        alt Only one measure remains
            View->>View: delete button is disabled
        else More than one measure remains
            View->>Model: deleteMeasure(measure)
            Model->>Model: remove matching TimeSignature
            Model->>Defaults: save encoded song library
            Model->>Model: derive consecutive measure numbers from startMeasureNumber
            alt Playback is running
                Model->>Model: stop()
                Model->>Engine: stop buffered scheduling
                Model->>Timer: cancel flashTask
            end
            Model-->>View: publish updated sequence
        end
    end
```
