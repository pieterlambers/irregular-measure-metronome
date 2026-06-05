import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject private var metronome: MetronomeModel
    @State private var firstMeasureNumberText = ""
    @State private var isSongPickerExpanded = false
    @State private var isCompactMeasureFocusEnabled = false
    @State private var isCompactSequenceSettingsExpanded = false
    @State private var expandedGroupingMeasureID: UUID?
    @State private var activeSignatureDrag: SignatureDrag?
    @State private var signatureDragStep = 0
    @State private var lastSignatureFeedbackTime = Date.distantPast
    #if os(iOS)
    @State private var signatureFeedbackGenerator = UISelectionFeedbackGenerator()
    #endif
    @FocusState private var isFirstMeasureNumberFocused: Bool

    private enum SignatureComponent: Equatable {
        case numerator
        case denominator
    }

    private struct SignatureDrag: Equatable {
        var measureID: UUID
        var component: SignatureComponent
    }

    private let accent = Color(red: 0.91, green: 1.0, blue: 0.28)
    private let background = Color(red: 0.05, green: 0.05, blue: 0.06)
    private let surface = Color(red: 0.13, green: 0.13, blue: 0.15)
    private let border = Color(red: 0.20, green: 0.20, blue: 0.23)
    private let muted = Color(red: 0.45, green: 0.45, blue: 0.49)
    private let commonNumerators = Array(1...12)
    private let commonDenominators = [2, 4, 8, 16]
    private let maxSplitContentWidth: CGFloat = 1180
    private let splitOuterPadding: CGFloat = 12
    private let splitSpacing: CGFloat = 24
    private let minimumTransportWidth: CGFloat = 280
    private let preferredTransportWidth: CGFloat = 320
    private let sequenceHorizontalPadding: CGFloat = 24
    private let sequenceGridSpacing: CGFloat = 16
    private let minimumMeasureCardWidth: CGFloat = 320
    private let narrowMeasureCardThreshold: CGFloat = 360
    private let signatureNumberControlWidth: CGFloat = 48
    private let signatureNumberControlHeight: CGFloat = 62
    private let signatureDragStepDistance: CGFloat = 28
    private let minimumSignatureFeedbackInterval: TimeInterval = 1.0 / 24.0

    var body: some View {
        GeometryReader { proxy in
            Group {
                if canUseSplitLayout(totalWidth: proxy.size.width) {
                    splitLayout(totalWidth: proxy.size.width)
                } else {
                    stackedLayout
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isFirstMeasureNumberFocused {
                    Spacer()

                    Button("Done") {
                        finishKeyboardEditing()
                    }
                }
            }
        }
    }

    private var stackedLayout: some View {
        VStack(spacing: 0) {
            header

            if isCompactMeasureFocusEnabled {
                compactMeasureFocusTransport
            } else {
                songControls
                compactTempo
                beatDots
                compactControls
                loopIndicator
            }

            sequenceScroller {
                VStack(spacing: 0) {
                    compactSequenceHeader

                    if isCompactSequenceSettingsExpanded {
                        measureNumberControls
                        loopRangeControls
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    adaptiveSequenceGrid(availableWidth: 0, forcedColumnCount: 1)
                }
            }
        }
    }

    private func splitLayout(totalWidth: CGFloat) -> some View {
        let contentWidth = splitContentWidth(for: totalWidth)
        let transportWidth = splitTransportWidth(for: contentWidth)
        let sequenceWidth = max(0, contentWidth - transportWidth - splitSpacing)

        return VStack(spacing: 0) {
            header

            HStack(alignment: .top, spacing: splitSpacing) {
                VStack(spacing: 0) {
                    songControls
                    tempo
                    slider
                    beatDots
                    controls
                    loopIndicator
                }
                .frame(width: transportWidth)

                VStack(spacing: 0) {
                    sequenceHeader
                    measureNumberControls
                    loopRangeControls
                    sequenceScroller {
                        adaptiveSequenceGrid(availableWidth: sequenceWidth)
                    }
                }
                .frame(width: sequenceWidth)
                .frame(maxHeight: .infinity)
            }
            .frame(width: contentWidth)
            .frame(maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func splitContentWidth(for totalWidth: CGFloat) -> CGFloat {
        max(0, min(totalWidth - (splitOuterPadding * 2), maxSplitContentWidth))
    }

    private func canUseSplitLayout(totalWidth: CGFloat) -> Bool {
        splitContentWidth(for: totalWidth) >= minimumTransportWidth + splitSpacing + minimumMeasureCardWidth + (sequenceHorizontalPadding * 2)
    }

    private func splitTransportWidth(for contentWidth: CGFloat) -> CGFloat {
        let roomAfterMinimumSequence = contentWidth - splitSpacing - minimumMeasureCardWidth - (sequenceHorizontalPadding * 2)
        return min(preferredTransportWidth, max(minimumTransportWidth, roomAfterMinimumSequence))
    }

    private func sequenceColumnCount(for availableWidth: CGFloat, forcedColumnCount: Int? = nil) -> Int {
        if let forcedColumnCount {
            return forcedColumnCount
        }

        let cardAreaWidth = max(0, availableWidth - (sequenceHorizontalPadding * 2))
        let fittingColumns = Int((cardAreaWidth + sequenceGridSpacing) / (minimumMeasureCardWidth + sequenceGridSpacing))
        return min(2, max(1, fittingColumns))
    }

    private func sequenceColumnWidth(availableWidth: CGFloat, columnCount: Int) -> CGFloat {
        let cardAreaWidth = max(0, availableWidth - (sequenceHorizontalPadding * 2))
        let totalSpacing = CGFloat(max(0, columnCount - 1)) * sequenceGridSpacing
        return max(0, (cardAreaWidth - totalSpacing) / CGFloat(max(1, columnCount)))
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
            Text("Brass Pulse")
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
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isSongPickerExpanded.toggle()
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
                    .disabled(!metronome.canEditCurrentSong)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(metronome.canEditCurrentSong ? .white : muted)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(background, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
                    .accessibilityLabel("Song name")

                songIconButton(
                    metronome.isCurrentSongReadOnly ? "lock.fill" : "lock.open",
                    label: metronome.isCurrentSongReadOnly ? "Unlock song" : "Lock song"
                ) {
                    metronome.setCurrentSongReadOnly(!metronome.isCurrentSongReadOnly)
                    isFirstMeasureNumberFocused = false
                }

                songIconButton("plus", label: "New song") {
                    metronome.createSong()
                    isSongPickerExpanded = false
                }
            }

            if isSongPickerExpanded {
                songPickerList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 8) {
                songIconButton("doc.on.doc", label: "Duplicate song") {
                    metronome.duplicateCurrentSong()
                    isSongPickerExpanded = false
                }

                songIconButton("arrow.counterclockwise", label: "Reset to built-in song") {
                    metronome.resetCurrentSongToBuiltIn()
                    isSongPickerExpanded = false
                }
                .disabled(!metronome.canResetCurrentSongToBuiltIn)
                .opacity(metronome.canResetCurrentSongToBuiltIn ? 1 : 0.35)

                songIconButton("trash", label: "Delete song") {
                    metronome.deleteCurrentSong()
                    isSongPickerExpanded = false
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

    private var songPickerList: some View {
        VStack(spacing: 0) {
            ForEach(metronome.songs) { song in
                Button {
                    metronome.selectSong(song)
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isSongPickerExpanded = false
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: song.id == metronome.currentSongID ? "checkmark" : "circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(song.id == metronome.currentSongID ? accent : muted)
                            .frame(width: 16, height: 16)

                        Text(song.name)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 0)

                        if song.readOnly {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(muted)
                                .accessibilityLabel("Read only")
                        }
                    }
                    .frame(height: 34)
                    .padding(.horizontal, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if song.id != metronome.songs.last?.id {
                    Divider()
                        .overlay(border)
                }
            }
        }
        .background(surface, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(border, lineWidth: 1))
        .accessibilityLabel("Song list")
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
            .disabled(!metronome.canEditCurrentSong)
            .opacity(metronome.canEditCurrentSong ? 1 : 0.45)

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

    private var compactTempo: some View {
        VStack(spacing: 7) {
            HStack(alignment: .center, spacing: 10) {
                Text("\(metronome.bpm)")
                    .font(.system(size: 34, weight: .light, design: .monospaced))
                    .foregroundStyle(metronome.flashBPM ? accent : .white)
                    .monospacedDigit()

                VStack(alignment: .leading, spacing: 2) {
                    Text("BPM")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(muted)

                    Text(metronome.tempoName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            Slider(value: Binding(
                get: { Double(metronome.bpm) },
                set: { metronome.bpm = Int($0.rounded()) }
            ), in: 20...300, step: 1)
            .tint(accent)
            .disabled(!metronome.canEditCurrentSong)
            .opacity(metronome.canEditCurrentSong ? 1 : 0.45)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }

    private var beatDots: some View {
        GeometryReader { proxy in
            let numerator = metronome.currentMeasure.numerator
            let scale = beatDotScale(for: numerator, availableWidth: proxy.size.width)
            let spacing = beatDotSpacing(scale: scale)

            HStack(spacing: spacing) {
                ForEach(0..<numerator, id: \.self) { beat in
                    let size = dotSize(for: beat) * scale

                    Circle()
                        .fill(dotFill(for: beat))
                        .stroke(dotStroke(for: beat), lineWidth: 1.5)
                        .frame(width: size, height: size)
                        .animation(.easeOut(duration: 0.06), value: metronome.currentBeat)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .frame(height: 48)
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
                .disabled(!metronome.canEditCurrentSong)
                .background(surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(border, lineWidth: 1))
                .opacity(metronome.canEditCurrentSong ? 1 : 0.45)
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
            .disabled(!metronome.canEditCurrentSong)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(metronome.isCountInFourFourEnabled ? accent.opacity(0.55) : border, lineWidth: 1))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private var compactControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    metronome.togglePlayback()
                } label: {
                    Image(systemName: metronome.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(background)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(accent, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    metronome.tapTempo()
                } label: {
                    VStack(spacing: 1) {
                        Text(metronome.tapTempoText)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)

                        Text("TEMPO")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .tracking(0.9)
                            .foregroundStyle(muted)
                    }
                    .frame(width: 88, height: 48)
                }
                .buttonStyle(.plain)
                .disabled(!metronome.canEditCurrentSong)
                .background(surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
                .opacity(metronome.canEditCurrentSong ? 1 : 0.45)
            }

            Toggle(isOn: $metronome.isCountInFourFourEnabled) {
                HStack(spacing: 8) {
                    Image(systemName: "metronome")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)

                    Text("count-in 4/4")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(muted)
                        .textCase(.uppercase)
                }
            }
            .tint(accent)
            .disabled(!metronome.canEditCurrentSong)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(metronome.isCountInFourFourEnabled ? accent.opacity(0.55) : border, lineWidth: 1))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }

    private var compactMeasureFocusTransport: some View {
        HStack(spacing: 8) {
            Button {
                metronome.togglePlayback()
            } label: {
                Image(systemName: metronome.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(background)
                    .frame(width: 46, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(accent, in: RoundedRectangle(cornerRadius: 10))

            Text("\(metronome.bpm) BPM")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(metronome.flashBPM ? accent : .white)
                .monospacedDigit()
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                metronome.tapTempo()
            } label: {
                Text(metronome.tapTempoText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(!metronome.canEditCurrentSong)
            .background(surface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(border, lineWidth: 1))
            .opacity(metronome.canEditCurrentSong ? 1 : 0.45)

            Text("L\(metronome.loopCount)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(muted)
                .monospacedDigit()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
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
                    .disabled(!metronome.canEditCurrentSong)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(metronome.canEditCurrentSong ? .white : muted)
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
            .disabled(!metronome.canEditCurrentSong)
        }
        .tint(accent)
        .opacity(metronome.canEditCurrentSong ? 1 : 0.55)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var compactSequenceHeader: some View {
        HStack(spacing: 8) {
            Text("sequence")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(muted)
                .textCase(.uppercase)

            Text("\(metronome.sequence.count)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(accent)
                .monospacedDigit()

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isCompactSequenceSettingsExpanded.toggle()
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isCompactSequenceSettingsExpanded ? accent : muted)
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
            .background(surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isCompactSequenceSettingsExpanded ? accent.opacity(0.55) : border, lineWidth: 1))
            .accessibilityLabel("Sequence settings")

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isCompactMeasureFocusEnabled.toggle()
                    if isCompactMeasureFocusEnabled {
                        isSongPickerExpanded = false
                        isFirstMeasureNumberFocused = false
                    }
                }
            } label: {
                Image(systemName: isCompactMeasureFocusEnabled ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isCompactMeasureFocusEnabled ? accent : muted)
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
            .background(surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isCompactMeasureFocusEnabled ? accent.opacity(0.55) : border, lineWidth: 1))
            .accessibilityLabel(isCompactMeasureFocusEnabled ? "Exit see all measures" : "See all measures")
        }
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
                    .disabled(!metronome.canEditCurrentSong)
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
        .disabled(!metronome.canEditCurrentSong)
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
        .disabled(!metronome.canEditCurrentSong)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
    }

    private func adaptiveSequenceGrid(availableWidth: CGFloat, forcedColumnCount: Int? = nil) -> some View {
        let columnCount = sequenceColumnCount(for: availableWidth, forcedColumnCount: forcedColumnCount)
        let columnWidth = sequenceColumnWidth(availableWidth: availableWidth, columnCount: columnCount)
        let isNarrowCard = forcedColumnCount == 1 || columnWidth < narrowMeasureCardThreshold
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: sequenceGridSpacing, alignment: .top),
            count: columnCount
        )

        return VStack(spacing: 6) {
            insertionControl(at: 0, isNarrowCard: isNarrowCard)

            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(Array(metronome.sequence.enumerated()), id: \.element.id) { index, measure in
                    VStack(spacing: 6) {
                        measureCard(for: measure, at: index, isNarrowCard: isNarrowCard)

                        insertionControl(at: index + 1, isNarrowCard: isNarrowCard)
                    }
                }
            }
        }
        .padding(.horizontal, sequenceHorizontalPadding)
        .padding(.bottom, 12)
    }

    private func measureCard(for measure: TimeSignature, at index: Int, isNarrowCard: Bool) -> some View {
        let isCurrentPlaybackMeasure = metronome.isPlayedMeasure(index: index)
        let cornerRadius: CGFloat = isNarrowCard ? 10 : 14

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: isNarrowCard ? 6 : 10) {
                measureNumberLabel(
                    forIndex: index,
                    isCurrentPlaybackMeasure: isCurrentPlaybackMeasure,
                    isNarrowCard: isNarrowCard
                )

                measureSignatureEditor(for: measure)

                groupingMenu(for: measure, isNarrowCard: isNarrowCard)

                Spacer(minLength: 0)

                Button {
                    expandedGroupingMeasureID = nil
                    metronome.deleteMeasure(measure)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(muted)
                        .frame(width: isNarrowCard ? 30 : 32, height: isNarrowCard ? 30 : 32)
                }
                .buttonStyle(.plain)
                .disabled(!metronome.canEditCurrentSong || metronome.sequence.count <= 1)
                .opacity(metronome.canEditCurrentSong && metronome.sequence.count > 1 ? 1 : 0.35)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
            }

            if expandedGroupingMeasureID == measure.id {
                groupingPresetSelector(for: measure)
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
        .padding(.horizontal, isNarrowCard ? 10 : 14)
        .padding(.vertical, isNarrowCard ? 9 : 12)
        .id(measure.id)
        .background(
            isCurrentPlaybackMeasure ? accent.opacity(0.14) : surface,
            in: RoundedRectangle(cornerRadius: cornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
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

    private func measureNumberLabel(
        forIndex index: Int,
        isCurrentPlaybackMeasure: Bool,
        isNarrowCard: Bool
    ) -> some View {
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
        .frame(width: isNarrowCard ? 44 : 52, alignment: .leading)
    }

    private func groupingMenu(for measure: TimeSignature, isNarrowCard: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.14)) {
                expandedGroupingMeasureID = expandedGroupingMeasureID == measure.id ? nil : measure.id
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
            .frame(minWidth: isNarrowCard ? 62 : 78, minHeight: 36)
            .padding(.horizontal, 8)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!metronome.canEditCurrentSong)
        .opacity(metronome.canEditCurrentSong ? 1 : 0.45)
        .accessibilityLabel("Grouping \(measure.groupingLabel)")
    }

    private func groupingPresetSelector(for measure: TimeSignature) -> some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            groupingOptionButton(
                label: "None",
                isSelected: measure.validGrouping == nil
            ) {
                selectGrouping(nil, for: measure)
            }

            ForEach(TimeSignature.groupingPresets(for: measure.numerator), id: \.self) { grouping in
                groupingOptionButton(
                    label: grouping.map(String.init).joined(separator: "+"),
                    isSelected: measure.validGrouping == grouping
                ) {
                    selectGrouping(grouping, for: measure)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func groupingOptionButton(
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11, weight: .semibold))

                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? accent : muted)
            .frame(minHeight: 28)
            .padding(.horizontal, 8)
            .background(isSelected ? accent.opacity(0.10) : background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? accent.opacity(0.55) : border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!metronome.canEditCurrentSong)
        .accessibilityLabel(label)
    }

    private func selectGrouping(_ grouping: [Int]?, for measure: TimeSignature) {
        metronome.updateGrouping(for: measure, grouping: grouping)
        withAnimation(.easeInOut(duration: 0.14)) {
            expandedGroupingMeasureID = nil
        }
    }

    private func insertionControl(at index: Int, isNarrowCard: Bool) -> some View {
        let buttonSize: CGFloat = isNarrowCard ? 24 : 28

        return HStack(spacing: 8) {
            Rectangle()
                .fill(border)
                .frame(height: 1)

            Button {
                _ = metronome.duplicateMeasure(at: index)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: buttonSize, height: buttonSize)
            }
            .buttonStyle(.plain)
            .disabled(!metronome.canEditCurrentSong)
            .background(background, in: Circle())
            .overlay(Circle().stroke(border, lineWidth: 1))
            .opacity(metronome.canEditCurrentSong ? 1 : 0.35)
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
        HStack(spacing: 4) {
            signatureNumberControl(
                value: currentMeasure(for: measure).numerator,
                options: numeratorOptions(for: measure),
                label: "Numerator",
                measureID: measure.id,
                component: .numerator,
                stepAction: { stepNumerator(for: measure, direction: $0) }
            )

            Text("/")
                .font(.system(size: 22, weight: .medium, design: .monospaced))
                .foregroundStyle(muted)
                .frame(width: 8)

            signatureNumberControl(
                value: currentMeasure(for: measure).denominator,
                options: denominatorOptions(for: measure),
                label: "Denominator",
                measureID: measure.id,
                component: .denominator,
                stepAction: { stepDenominator(for: measure, direction: $0) }
            )
        }
        .frame(width: 112, height: signatureNumberControlHeight, alignment: .center)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Time signature \(measure.label)")
    }

    private func signatureNumberControl(
        value: Int,
        options: [Int],
        label: String,
        measureID: UUID,
        component: SignatureComponent,
        stepAction: @escaping (Int) -> Void
    ) -> some View {
        let dragID = SignatureDrag(measureID: measureID, component: component)
        let isActive = activeSignatureDrag == dragID

        return ZStack(alignment: .top) {
            VStack(spacing: 2) {
                Text("\(adjacentValue(to: value, in: options, direction: 1))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(muted.opacity(isActive ? 0.76 : 0.42))
                    .monospacedDigit()
                    .frame(width: signatureNumberControlWidth, height: 14)

                Text("\(value)")
                    .font(.system(size: 23, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(width: signatureNumberControlWidth, height: 30)
                    .background(
                        (isActive ? accent.opacity(0.24) : Color.white.opacity(0.08)),
                        in: Capsule()
                    )
                    .overlay(Capsule().stroke(isActive ? accent.opacity(0.65) : .clear, lineWidth: 1))

                Text("\(adjacentValue(to: value, in: options, direction: -1))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(muted.opacity(isActive ? 0.76 : 0.42))
                    .monospacedDigit()
                    .frame(width: signatureNumberControlWidth, height: 14)
            }
            .frame(width: signatureNumberControlWidth, height: signatureNumberControlHeight)

            if isActive {
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(background)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 54, height: 30)
                    .background(accent, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                    .offset(y: -38)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: signatureNumberControlWidth, height: signatureNumberControlHeight)
        .animation(.easeOut(duration: 0.10), value: isActive)
        .contentShape(Rectangle())
        .gesture(signatureDragGesture(dragID: dragID, stepAction: stepAction))
        .allowsHitTesting(metronome.canEditCurrentSong)
        .opacity(metronome.canEditCurrentSong ? 1 : 0.55)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(label) \(value)")
        .accessibilityValue(options.map(String.init).joined(separator: ", "))
        .accessibilityAdjustableAction { direction in
            guard metronome.canEditCurrentSong else { return }
            switch direction {
            case .increment:
                stepAction(1)
            case .decrement:
                stepAction(-1)
            @unknown default:
                break
            }
        }
    }

    private func signatureDragGesture(
        dragID: SignatureDrag,
        stepAction: @escaping (Int) -> Void
    ) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                if activeSignatureDrag != dragID {
                    activeSignatureDrag = dragID
                    signatureDragStep = 0
                    prepareSelectionFeedback()
                }

                let rawStep = -value.translation.height / signatureDragStepDistance
                let step = Int(rawStep.rounded(.towardZero))
                let delta = step - signatureDragStep
                guard delta != 0 else { return }

                signatureDragStep = step
                stepAction(delta)
                selectionFeedback()
            }
            .onEnded { _ in
                activeSignatureDrag = nil
                signatureDragStep = 0
                prepareSelectionFeedback()
            }
    }

    private func stepNumerator(for measure: TimeSignature, direction: Int) {
        let current = currentMeasure(for: measure)
        updateMeasure(
            measure,
            numerator: steppedValue(current.numerator, in: numeratorOptions(for: measure), direction: direction),
            denominator: current.denominator
        )
    }

    private func stepDenominator(for measure: TimeSignature, direction: Int) {
        let current = currentMeasure(for: measure)
        updateMeasure(
            measure,
            numerator: current.numerator,
            denominator: steppedValue(current.denominator, in: denominatorOptions(for: measure), direction: direction)
        )
    }

    private func adjacentValue(to value: Int, in options: [Int], direction: Int) -> Int {
        steppedValue(value, in: options, direction: direction)
    }

    private func steppedValue(_ value: Int, in options: [Int], direction: Int) -> Int {
        guard let index = options.firstIndex(of: value), !options.isEmpty else {
            return value
        }
        return options[(index + direction + options.count) % options.count]
    }

    private func selectionFeedback() {
        #if os(iOS)
        let now = Date()
        guard now.timeIntervalSince(lastSignatureFeedbackTime) >= minimumSignatureFeedbackInterval else {
            return
        }

        lastSignatureFeedbackTime = now
        signatureFeedbackGenerator.selectionChanged()
        signatureFeedbackGenerator.prepare()
        #endif
    }

    private func prepareSelectionFeedback() {
        #if os(iOS)
        signatureFeedbackGenerator.prepare()
        #endif
    }

    private func currentMeasure(for measure: TimeSignature) -> TimeSignature {
        metronome.sequence.first { $0.id == measure.id } ?? measure
    }

    private func numeratorOptions(for measure: TimeSignature) -> [Int] {
        sortedOptions(commonNumerators, including: currentMeasure(for: measure).numerator)
    }

    private func denominatorOptions(for measure: TimeSignature) -> [Int] {
        sortedOptions(commonDenominators, including: currentMeasure(for: measure).denominator)
    }

    private func sortedOptions(_ options: [Int], including currentValue: Int) -> [Int] {
        Array(Set(options + [currentValue])).sorted()
    }

    private func updateMeasure(_ measure: TimeSignature, numerator: Int, denominator: Int) {
        _ = metronome.updateMeasure(measure, numerator: numerator, denominator: denominator)
    }

    private func finishKeyboardEditing() {
        if isFirstMeasureNumberFocused {
            isFirstMeasureNumberFocused = false
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

    private func beatDotScale(for numerator: Int, availableWidth: CGFloat) -> CGFloat {
        guard numerator > 0, availableWidth > 0 else { return 1 }

        let reservedDotWidth = CGFloat(numerator) * 44
        let reservedSpacingWidth = CGFloat(max(0, numerator - 1)) * 10
        let requiredWidth = reservedDotWidth + reservedSpacingWidth

        return min(1, availableWidth / requiredWidth)
    }

    private func beatDotSpacing(scale: CGFloat) -> CGFloat {
        max(3, 10 * scale)
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
