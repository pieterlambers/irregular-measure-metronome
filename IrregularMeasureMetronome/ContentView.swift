import Foundation
import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var metronome: MetronomeModel
    @State private var editingMeasureID: UUID?
    @State private var editMeasureText = ""
    @State private var firstMeasureNumberText = ""
    @State private var invalidEditMeasure = false
    @FocusState private var isMeasureSignatureFocused: Bool
    @FocusState private var isFirstMeasureNumberFocused: Bool

    private let accent = Color(red: 0.91, green: 1.0, blue: 0.28)
    private let background = Color(red: 0.05, green: 0.05, blue: 0.06)
    private let surface = Color(red: 0.13, green: 0.13, blue: 0.15)
    private let border = Color(red: 0.20, green: 0.20, blue: 0.23)
    private let muted = Color(red: 0.45, green: 0.45, blue: 0.49)

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularWidthLayout
            } else {
                compactLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            firstMeasureNumberText = "\(metronome.startMeasureNumber)"
        }
        .onChange(of: metronome.startMeasureNumber) { _, number in
            if !isFirstMeasureNumberFocused {
                firstMeasureNumberText = "\(number)"
            }
        }
        .onChange(of: isFirstMeasureNumberFocused) { _, isFocused in
            if isFocused {
                firstMeasureNumberText = "\(metronome.startMeasureNumber)"
            } else {
                commitFirstMeasureNumberText()
            }
        }
        .onChange(of: isMeasureSignatureFocused) { _, isFocused in
            if !isFocused {
                commitMeasureEdit()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isFirstMeasureNumberFocused || isMeasureSignatureFocused {
                    Spacer()

                    Button("Done") {
                        finishKeyboardEditing()
                    }
                }
            }
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 0) {
            header
            songControls
            tempo
            slider
            beatDots
            pendulum
            controls
            loopIndicator
            sequenceScroller {
                VStack(spacing: 0) {
                    sequenceHeader
                    measureNumberControls
                    loopRangeControls
                    sequenceList
                }
            }
        }
    }

    private var regularWidthLayout: some View {
        VStack(spacing: 0) {
            header

            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 0) {
                    songControls
                    tempo
                    slider
                    beatDots
                    pendulum
                    controls
                    loopIndicator
                }
                .frame(width: 320)

                VStack(spacing: 0) {
                    sequenceHeader
                    measureNumberControls
                    loopRangeControls
                    sequenceScroller {
                        sequenceGrid
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: 1180, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func sequenceScroller<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                content()
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: metronome.currentBeat) { _, _ in
                scrollPlayedMeasure(with: proxy)
            }
            .onChange(of: metronome.currentMeasureIndex) { _, _ in
                scrollPlayedMeasure(with: proxy)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func scrollPlayedMeasure(with proxy: ScrollViewProxy) {
        guard metronome.isPlayedMeasure(index: metronome.currentMeasureIndex),
              metronome.sequence.indices.contains(metronome.currentMeasureIndex)
        else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            proxy.scrollTo(metronome.sequence[metronome.currentMeasureIndex].id, anchor: .center)
        }
    }

    private var header: some View {
        HStack {
            Text("Metro")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(muted)
                .textCase(.uppercase)

            Spacer()

            Text("\(metronome.bpm) bpm")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(accent.opacity(0.10), in: Capsule())
                .overlay(Capsule().stroke(accent.opacity(0.30), lineWidth: 1))
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var songControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(metronome.songs) { song in
                        Button {
                            metronome.selectSong(song)
                            endMeasureEditing()
                        } label: {
                            if song.id == metronome.currentSongID {
                                Label(song.name, systemImage: "checkmark")
                            } else {
                                Text(song.name)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 38, height: 38)
                        .background(background, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose song")

                TextField("Song name", text: $metronome.currentSongName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(background, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
                    .accessibilityLabel("Song name")

                songIconButton("plus", label: "New song") {
                    metronome.createSong()
                    endMeasureEditing()
                }
            }

            HStack(spacing: 8) {
                songIconButton("doc.on.doc", label: "Duplicate song") {
                    metronome.duplicateCurrentSong()
                    endMeasureEditing()
                }

                songIconButton("arrow.counterclockwise", label: "Reset to built-in song") {
                    metronome.resetCurrentSongToBuiltIn()
                    endMeasureEditing()
                }
                .disabled(!metronome.canResetCurrentSongToBuiltIn)
                .opacity(metronome.canResetCurrentSongToBuiltIn ? 1 : 0.35)

                songIconButton("trash", label: "Delete song") {
                    metronome.deleteCurrentSong()
                    endMeasureEditing()
                }
                .disabled(metronome.songs.count <= 1)
                .opacity(metronome.songs.count <= 1 ? 0.35 : 1)

                Spacer()

                Text("\(metronome.songs.count) \(metronome.songs.count == 1 ? "song" : "songs")")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(muted)
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private func songIconButton(
        _ systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 38, height: 34)
        }
        .buttonStyle(.plain)
        .background(surface, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(border, lineWidth: 1))
        .accessibilityLabel(label)
    }

    private var tempo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("\(metronome.bpm)")
                    .font(.system(size: 80, weight: .light, design: .monospaced))
                    .foregroundStyle(metronome.flashBPM ? accent : .white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)

                Text("BPM")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(muted)
                    .padding(.bottom, 14)
            }

            Text(metronome.tempoName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var slider: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(
                get: { Double(metronome.bpm) },
                set: { metronome.bpm = Int($0.rounded()) }
            ), in: 20...300, step: 1)
            .tint(accent)

            HStack {
                Text("20")
                Spacer()
                Text("300")
            }
            .font(.system(size: 10, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(muted)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var beatDots: some View {
        FlowLayout(spacing: 10, lineSpacing: 10) {
            ForEach(0..<metronome.currentMeasure.numerator, id: \.self) { beat in
                Circle()
                    .fill(dotFill(for: beat))
                    .stroke(dotStroke(for: beat), lineWidth: 1.5)
                    .frame(width: dotSize(for: beat), height: dotSize(for: beat))
                    .animation(.easeOut(duration: 0.06), value: metronome.currentBeat)
            }
        }
        .frame(minHeight: 48)
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private var pendulum: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(border.opacity(0.8))
                .frame(width: 2, height: 64)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 2, height: 58)

                Circle()
                    .fill(accent)
                    .frame(width: 22, height: 22)
                    .offset(y: -1)
            }
            .rotationEffect(.degrees(Double(metronome.pendulumDirection * 32)), anchor: .top)
            .animation(.linear(duration: 0.08), value: metronome.pendulumDirection)
        }
        .frame(height: 70)
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    metronome.togglePlayback()
                } label: {
                    Image(systemName: metronome.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(background)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(accent, in: RoundedRectangle(cornerRadius: 16))

                Button {
                    metronome.tapTempo()
                } label: {
                    VStack(spacing: 2) {
                        Text(metronome.tapTempoText)
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)

                        Text("TEMPO")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(muted)
                    }
                    .frame(width: 96, height: 60)
                }
                .buttonStyle(.plain)
                .background(surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(border, lineWidth: 1))
            }

            Toggle(isOn: $metronome.isCountInFourFourEnabled) {
                HStack(spacing: 8) {
                    Image(systemName: "metronome")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)

                    Text("count-in 4/4")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(muted)
                        .textCase(.uppercase)
                }
            }
            .tint(accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(metronome.isCountInFourFourEnabled ? accent.opacity(0.55) : border, lineWidth: 1))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private var sequenceHeader: some View {
        Text("sequence")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(muted)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
    }

    private var measureNumberControls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("first measure")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(muted)
                    .textCase(.uppercase)

                TextField("1", text: $firstMeasureNumberText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(width: 56, height: 30)
                    .padding(.horizontal, 8)
                    .background(background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
                    .accessibilityLabel("First measure number")
                    .focused($isFirstMeasureNumberFocused)
                    .onChange(of: firstMeasureNumberText) { _, text in
                        updateFirstMeasureNumber(from: text)
                    }
            }

            Spacer()

            Stepper(
                "First measure number",
                value: $metronome.startMeasureNumber,
                in: 0...9999
            )
            .labelsHidden()
        }
        .tint(accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var loopRangeControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("loop range")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(muted)
                    .textCase(.uppercase)

                Spacer()

                Toggle("", isOn: $metronome.isLoopRangeEnabled)
                    .labelsHidden()
                    .tint(accent)
            }

            HStack(spacing: 10) {
                loopBoundaryStepper(
                    title: "from",
                    value: Binding(
                        get: { metronome.loopStartMeasureNumber },
                        set: { metronome.updateLoopStartMeasureNumber($0) }
                    ),
                    range: metronome.startMeasureNumber...metronome.loopEndMeasureNumber
                )

                loopBoundaryStepper(
                    title: "to",
                    value: Binding(
                        get: { metronome.loopEndMeasureNumber },
                        set: { metronome.updateLoopEndMeasureNumber($0) }
                    ),
                    range: metronome.loopStartMeasureNumber...metronome.lastMeasureNumber
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(metronome.isLoopRangeEnabled ? accent.opacity(0.55) : border, lineWidth: 1))
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private func loopBoundaryStepper(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        Stepper(value: value, in: range) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(muted)
                    .textCase(.uppercase)

                Text("\(value.wrappedValue)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
        .tint(accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
    }

    private var sequenceList: some View {
        VStack(spacing: 6) {
            insertionControl(at: 0)

            ForEach(Array(metronome.sequence.enumerated()), id: \.element.id) { index, measure in
                measureCard(for: measure, at: index)

                insertionControl(at: index + 1)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var sequenceGrid: some View {
        VStack(spacing: 6) {
            insertionControl(at: 0)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16, alignment: .top),
                    GridItem(.flexible(), spacing: 16, alignment: .top)
                ],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(Array(metronome.sequence.enumerated()), id: \.element.id) { index, measure in
                    VStack(spacing: 6) {
                        measureCard(for: measure, at: index)

                        insertionControl(at: index + 1)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private func measureCard(for measure: TimeSignature, at index: Int) -> some View {
        let isCurrentPlaybackMeasure = metronome.isPlayedMeasure(index: index)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                measureNumberLabel(forIndex: index, isCurrentPlaybackMeasure: isCurrentPlaybackMeasure)

                measureSignatureEditor(for: measure)

                groupingMenu(for: measure)

                Spacer(minLength: 0)

                Button {
                    metronome.deleteMeasure(measure)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(muted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(metronome.sequence.count <= 1)
                .opacity(metronome.sequence.count <= 1 ? 0.35 : 1)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
            }

            FlowLayout(spacing: 5, lineSpacing: 5) {
                ForEach(0..<measure.numerator, id: \.self) { beat in
                    Circle()
                        .fill(miniDotFill(measureIndex: index, measure: measure, beat: beat))
                        .stroke(miniDotStroke(measure: measure, beat: beat), lineWidth: 1)
                        .frame(width: 11, height: 11)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .id(measure.id)
        .background(
            isCurrentPlaybackMeasure ? accent.opacity(0.14) : surface,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isCurrentPlaybackMeasure ? accent : border,
                    lineWidth: isCurrentPlaybackMeasure ? 2.5 : 1.5
                )
        )
        .overlay(alignment: .leading) {
            if isCurrentPlaybackMeasure || metronome.isMeasureInActiveLoop(index: index) {
                Rectangle()
                    .fill(isCurrentPlaybackMeasure ? .white : accent)
                    .frame(width: isCurrentPlaybackMeasure ? 5 : 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .padding(.vertical, 10)
            }
        }
        .animation(.easeOut(duration: 0.08), value: isCurrentPlaybackMeasure)
    }

    private func measureNumberLabel(forIndex index: Int, isCurrentPlaybackMeasure: Bool) -> some View {
        HStack(spacing: 3) {
            if metronome.isLoopRangeEnabled && index == metronome.loopStartIndex {
                Image(systemName: "repeat")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(accent)
            }

            Text("\(metronome.measureNumber(forIndex: index))")
                .font(.system(
                    size: 11,
                    weight: isCurrentPlaybackMeasure ? .bold : .regular,
                    design: .monospaced
                ))
                .foregroundStyle(
                    isCurrentPlaybackMeasure || metronome.isMeasureInActiveLoop(index: index) ? .white : muted
                )
                .monospacedDigit()

            if metronome.isLoopRangeEnabled && index == metronome.loopEndIndex {
                Image(systemName: "repeat.1")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(accent)
            }
        }
        .frame(width: 52, alignment: .leading)
    }

    private func groupingMenu(for measure: TimeSignature) -> some View {
        Menu {
            Button("None") {
                metronome.updateGrouping(for: measure, grouping: nil)
            }

            ForEach(groupingPresets(for: measure.numerator), id: \.self) { grouping in
                Button(grouping.map(String.init).joined(separator: "+")) {
                    metronome.updateGrouping(for: measure, grouping: grouping)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(measure.groupingLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(measure.validGrouping == nil ? muted : accent)
            .frame(minWidth: 78, minHeight: 36)
            .padding(.horizontal, 8)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Grouping \(measure.groupingLabel)")
    }

    private func insertionControl(at index: Int) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(border)
                .frame(height: 1)

            Button {
                if metronome.duplicateMeasure(at: index),
                   metronome.sequence.indices.contains(index) {
                    beginEditing(metronome.sequence[index])
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(background, in: Circle())
            .overlay(Circle().stroke(border, lineWidth: 1))
            .accessibilityLabel("Insert measure here")

            Rectangle()
                .fill(border)
                .frame(height: 1)
        }
    }

    private var loopIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { index in
                Circle()
                    .fill(index <= ((metronome.loopCount - 1) % 3) + 1 ? accent : border)
                    .frame(width: 7, height: 7)
            }

            Text("loop \(metronome.loopCount)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private func measureSignatureEditor(for measure: TimeSignature) -> some View {
        Group {
            if editingMeasureID == measure.id {
                HStack(spacing: 6) {
                    TextField("7/8", text: $editMeasureText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 34)
                        .background(background, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(invalidEditMeasure ? .red : border, lineWidth: 1))
                        .focused($isMeasureSignatureFocused)

                    Button {
                        finishMeasureEditing()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(background)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .background(accent, in: Circle())
                    .accessibilityLabel("Apply time signature")
                }
                .frame(width: 94, alignment: .leading)
            } else {
                Button {
                    beginEditing(measure)
                } label: {
                    Text(measure.label)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 64, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit time signature \(measure.label)")
            }
        }
    }

    private func finishKeyboardEditing() {
        if isFirstMeasureNumberFocused {
            isFirstMeasureNumberFocused = false
        } else if isMeasureSignatureFocused {
            finishMeasureEditing()
        }
    }

    private func updateFirstMeasureNumber(from text: String) {
        let digits = text.filter(\.isNumber)
        if digits != text {
            firstMeasureNumberText = digits
            return
        }

        guard !digits.isEmpty else { return }

        let number = min(Int(digits) ?? metronome.startMeasureNumber, 9999)
        metronome.startMeasureNumber = number
        if "\(number)" != digits {
            firstMeasureNumberText = "\(number)"
        }
    }

    private func commitFirstMeasureNumberText() {
        guard !firstMeasureNumberText.isEmpty else {
            firstMeasureNumberText = "\(metronome.startMeasureNumber)"
            return
        }

        updateFirstMeasureNumber(from: firstMeasureNumberText)
        firstMeasureNumberText = "\(metronome.startMeasureNumber)"
    }

    private func finishMeasureEditing() {
        commitMeasureEdit()
        if editingMeasureID == nil {
            isMeasureSignatureFocused = false
        }
    }

    private func beginEditing(_ measure: TimeSignature) {
        editingMeasureID = measure.id
        editMeasureText = measure.label
        invalidEditMeasure = false
        isMeasureSignatureFocused = true
    }

    private func endMeasureEditing() {
        editingMeasureID = nil
        editMeasureText = ""
        invalidEditMeasure = false
        isMeasureSignatureFocused = false
    }

    private func commitMeasureEdit() {
        guard let editingMeasureID,
              let measure = metronome.sequence.first(where: { $0.id == editingMeasureID })
        else {
            return
        }

        guard let signature = parseMeasureSignature(editMeasureText) else {
            invalidEditMeasure = true
            isMeasureSignatureFocused = true
            return
        }

        invalidEditMeasure = false
        _ = metronome.updateMeasure(
            measure,
            numerator: signature.numerator,
            denominator: signature.denominator
        )
        self.editingMeasureID = nil
        isMeasureSignatureFocused = false
    }

    private func parseMeasureSignature(_ text: String) -> (numerator: Int, denominator: Int)? {
        let parts = text
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count == 2,
              let numerator = Int(parts[0]),
              let denominator = Int(parts[1]),
              (1...24).contains(numerator),
              (1...64).contains(denominator)
        else {
            return nil
        }

        return (numerator, denominator)
    }

    private func dotFill(for beat: Int) -> Color {
        guard metronome.currentBeat == beat, metronome.isPlaying else { return surface }
        return beat == 0 ? .white : accent
    }

    private func dotStroke(for beat: Int) -> Color {
        if metronome.currentBeat == beat, metronome.isPlaying {
            return beat == 0 ? .white : accent
        }
        guard metronome.currentMeasure.isSubaccented(beat: beat) else { return border }
        return accent.opacity(0.65)
    }

    private func dotSize(for beat: Int) -> CGFloat {
        guard metronome.currentBeat == beat, metronome.isPlaying else {
            return metronome.currentMeasure.isSubaccented(beat: beat) ? 38 : 34
        }
        return beat == 0 ? 44 : 40
    }

    private func miniDotFill(measureIndex index: Int, measure: TimeSignature, beat: Int) -> Color {
        guard metronome.isPlaying,
              !metronome.isCountingIn,
              index == metronome.currentMeasureIndex,
              beat == metronome.currentBeat
        else {
            if beat == 0 {
                return .white.opacity(0.35)
            }
            if measure.isSubaccented(beat: beat) {
                return accent.opacity(0.45)
            }
            return Color(red: 0.22, green: 0.22, blue: 0.25)
        }
        return beat == 0 ? .white : accent
    }

    private func miniDotStroke(measure: TimeSignature, beat: Int) -> Color {
        if beat == 0 {
            return .white.opacity(0.55)
        }
        if measure.isSubaccented(beat: beat) {
            return accent.opacity(0.75)
        }
        return border
    }

    private func groupingPresets(for numerator: Int) -> [[Int]] {
        let curated: [Int: [[Int]]] = [
            5: [[2, 3], [3, 2]],
            7: [[2, 2, 3], [2, 3, 2], [3, 2, 2]],
            8: [[3, 3, 2], [3, 2, 3], [2, 3, 3]],
            9: [[2, 2, 2, 3], [2, 2, 3, 2], [2, 3, 2, 2], [3, 2, 2, 2], [3, 3, 3]],
            10: [[3, 3, 2, 2], [3, 2, 3, 2], [2, 3, 3, 2], [2, 2, 3, 3]],
            11: [[3, 3, 3, 2], [3, 3, 2, 3], [3, 2, 3, 3], [2, 3, 3, 3]],
            12: [[3, 3, 3, 3], [2, 2, 2, 2, 2, 2], [4, 4, 4]]
        ]

        if let presets = curated[numerator] {
            return presets
        }

        var presets: [[Int]] = []
        for groupSize in [3, 4, 2] where numerator % groupSize == 0 {
            presets.append(Array(repeating: groupSize, count: numerator / groupSize))
        }
        return Array(presets.prefix(4))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = rows(in: width, subviews: subviews)
        let height = rows.reduce(CGFloat.zero) { result, row in
            result + row.height
        } + max(0, CGFloat(rows.count - 1)) * lineSpacing
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(in: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = current.items.isEmpty ? size.width : current.width + spacing + size.width

            if nextWidth > width, !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }

            current.items.append(Item(subview: subview, size: size))
            current.width = current.items.count == 1 ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.items.isEmpty {
            rows.append(current)
        }

        return rows
    }

    private struct Item {
        var subview: LayoutSubview
        var size: CGSize
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }
}

#Preview {
    ContentView()
        .environmentObject(MetronomeModel())
}
