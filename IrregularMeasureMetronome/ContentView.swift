import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var metronome: MetronomeModel
    @State private var numeratorText = "4"
    @State private var denominatorText = "4"
    @State private var invalidNumerator = false
    @State private var invalidDenominator = false

    private let accent = Color(red: 0.91, green: 1.0, blue: 0.28)
    private let background = Color(red: 0.05, green: 0.05, blue: 0.06)
    private let surface = Color(red: 0.13, green: 0.13, blue: 0.15)
    private let border = Color(red: 0.20, green: 0.20, blue: 0.23)
    private let muted = Color(red: 0.45, green: 0.45, blue: 0.49)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                tempo
                slider
                beatDots
                pendulum
                controls
                sequenceHeader
                sequenceList
                addMeasure
                loopIndicator
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(background.ignoresSafeArea())
        .preferredColorScheme(.dark)
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

    private var sequenceList: some View {
        VStack(spacing: 8) {
            ForEach(Array(metronome.sequence.enumerated()), id: \.element.id) { index, measure in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(muted)
                        .frame(width: 18, alignment: .leading)

                    Text(measure.label)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 64, alignment: .leading)

                    FlowLayout(spacing: 5, lineSpacing: 5) {
                        ForEach(0..<measure.numerator, id: \.self) { beat in
                            Circle()
                                .fill(miniDotFill(index: index, beat: beat))
                                .stroke(border, lineWidth: 1)
                                .frame(width: 11, height: 11)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(index == metronome.currentMeasureIndex && metronome.isPlaying ? accent : border, lineWidth: 1.5)
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var addMeasure: some View {
        HStack(spacing: 8) {
            measureField(text: $numeratorText, invalid: invalidNumerator)
            Text("/")
                .font(.system(size: 22, design: .monospaced))
                .foregroundStyle(muted)
            measureField(text: $denominatorText, invalid: invalidDenominator)

            Spacer(minLength: 8)

            Button {
                addMeasureFromFields()
            } label: {
                Label("add", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
            .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.35), lineWidth: 1))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
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

    private func measureField(text: Binding<String>, invalid: Bool) -> some View {
        TextField("", text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 18, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 76, height: 44)
            .background(surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(invalid ? .red : border, lineWidth: 1))
    }

    private func addMeasureFromFields() {
        let numerator = Int(numeratorText) ?? 0
        let denominator = Int(denominatorText) ?? 0
        invalidNumerator = !(1...32).contains(numerator)
        invalidDenominator = !(1...64).contains(denominator)

        guard !invalidNumerator, !invalidDenominator else { return }
        _ = metronome.addMeasure(numerator: numerator, denominator: denominator)
    }

    private func dotFill(for beat: Int) -> Color {
        guard metronome.currentBeat == beat, metronome.isPlaying else { return surface }
        return beat == 0 ? .white : accent
    }

    private func dotStroke(for beat: Int) -> Color {
        guard metronome.currentBeat == beat, metronome.isPlaying else { return border }
        return beat == 0 ? .white : accent
    }

    private func dotSize(for beat: Int) -> CGFloat {
        guard metronome.currentBeat == beat, metronome.isPlaying else { return 34 }
        return beat == 0 ? 44 : 40
    }

    private func miniDotFill(index: Int, beat: Int) -> Color {
        guard metronome.isPlaying,
              index == metronome.currentMeasureIndex,
              beat == metronome.currentBeat
        else {
            return Color(red: 0.22, green: 0.22, blue: 0.25)
        }
        return beat == 0 ? .white : accent
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
