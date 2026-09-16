//
//  TweakSectionDetailView.swift
//  TweakIt
//
//  Detail view for editing all tweaks in a section.
//

import SwiftUI

@available(iOS 16.0, *)
public struct TweakSectionDetailView: View {
    let section: TweakSectionMetadata
    let storage: TweakStorage
    @State private var refreshID = UUID()

    public init(section: TweakSectionMetadata, storage: TweakStorage) {
        self.section = section
        self.storage = storage
    }

    public var body: some View {
        List {
            // Master toggle for sections that have one
            if section.hasMasterToggle {
                Section {
                    MasterToggleRow(section: section, storage: storage, refreshID: $refreshID)
                } header: {
                    Text("Override")
                } footer: {
                    Text("Enable to use custom values instead of defaults")
                }
            }

            // Tweaks — one List section per declared group, in declaration order.
            ForEach(renderedGroups, id: \.group.id) { entry in
                Section {
                    ForEach(entry.group.tweaks) { tweak in
                        TweakRow(tweak: tweak, storage: storage, isDisabled: isDisabled)
                            .id("\(tweak.id)-\(refreshID)")
                    }
                } header: {
                    if let header = entry.header {
                        Text(header)
                    }
                }
            }
        }
        .navigationTitle(section.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    storage.resetSection(section.id)
                    refreshID = UUID()
                }
                .disabled(!storage.isSectionModified(section.id))
            }
        }
    }

    private var isDisabled: Bool {
        section.hasMasterToggle && !storage.value(forKey: section.id + ".isEnabled", default: false)
    }

    /// The section's groups paired with the heading each should render — `nil` for none.
    ///
    /// A group with a `nil` name is an implicit run of bare tweaks and gets no heading, with
    /// one exception: the first such run in a master-toggle section keeps the old "Settings"
    /// heading, which is what visually separates the tweaks from the override switch above.
    /// Empty groups are dropped so a heading never floats above nothing.
    private var renderedGroups: [(group: TweakGroupMetadata, header: String?)] {
        var result: [(group: TweakGroupMetadata, header: String?)] = []
        var isFirst = true
        for group in section.groups where !group.tweaks.isEmpty {
            let header: String?
            if let name = group.name {
                header = name
            } else if isFirst && section.hasMasterToggle {
                header = "Settings"
            } else {
                header = nil
            }
            result.append((group, header))
            isFirst = false
        }
        return result
    }
}

// MARK: - Master Toggle Row

@available(iOS 16.0, *)
public struct MasterToggleRow: View {
    let section: TweakSectionMetadata
    let storage: TweakStorage
    @Binding var refreshID: UUID
    @State private var isEnabled: Bool

    public init(section: TweakSectionMetadata, storage: TweakStorage, refreshID: Binding<UUID>) {
        self.section = section
        self.storage = storage
        self._refreshID = refreshID
        self._isEnabled = State(initialValue: storage.value(forKey: section.id + ".isEnabled", default: false))
    }

    public var body: some View {
        HStack(spacing: 12) {
            if let color = section.color {
                Circle()
                    .fill(isEnabled ? color : color.opacity(0.3))
                    .frame(width: 12, height: 12)
            }

            Toggle(isOn: $isEnabled) {
                // Same trick as the tweak toggles: the label claims the row's whole width so a
                // tap anywhere left of the switch flips it, and the gesture stays inside the
                // label so it can never overlap the switch and fire twice.
                Text("Enable Overrides")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { isEnabled.toggle() }
            }
                .onChange(of: isEnabled) { newValue in
                    storage.setValue(newValue, forKey: section.id + ".isEnabled", default: false)
                    refreshID = UUID()
                }
                .onChange(of: refreshID) { _ in
                    let storedValue: Bool = storage.value(forKey: section.id + ".isEnabled", default: false)
                    if isEnabled != storedValue {
                        isEnabled = storedValue
                    }
                }
        }
    }
}

// MARK: - Tweak Row

/// A single editable tweak, as a `List` row.
///
/// Picks its control from ``TweakMetadata/controlType``, shows the tweak's ``TweakMetadata/description``
/// underneath the name when it has one, and carries both swipe actions — reset on the trailing edge,
/// pin on the leading one.
///
/// It's public so a host can drop live tweak controls into its own panel; the panel itself uses it
/// both in a section's detail list and in Quick Access.
@available(iOS 16.0, *)
public struct TweakRow: View {
    let tweak: TweakMetadata
    let storage: TweakStorage
    var isDisabled: Bool = false

    public init(tweak: TweakMetadata, storage: TweakStorage, isDisabled: Bool = false) {
        self.tweak = tweak
        self.storage = storage
        self.isDisabled = isDisabled
    }

    public var body: some View {
        Group {
            switch tweak.controlType {
            case .toggle:
                ToggleTweakRow(tweak: tweak, storage: storage)
            case .slider:
                SliderTweakRow(tweak: tweak, storage: storage)
            case .stepper:
                StepperTweakRow(tweak: tweak, storage: storage)
            case .picker:
                PickerTweakRow(tweak: tweak, storage: storage)
            case .text:
                TextTweakRow(tweak: tweak, storage: storage)
            case .action:
                ActionTweakRow(tweak: tweak)
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        // Deliberately outside `.disabled`: a row switched off by its section's master toggle
        // must still be pinnable and, more importantly, unpinnable. Otherwise pinning a tweak
        // and then turning its section off strands the pin with no way to swipe it away.
        .pinSwipeAction(tweakID: tweak.id, storage: storage)
    }
}

// MARK: - Swipe Actions Helpers

/// Swipe-left-to-reset, on rows whose value has actually been changed.
@available(iOS 16.0, *)
private struct ResetSwipeModifier: ViewModifier {
    let tweakID: String
    let storage: TweakStorage
    let onReset: () -> Void

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if storage.isModified(key: tweakID) {
                    Button("Reset", action: onReset)
                        .tint(.orange)
                }
            }
    }
}

/// Swipe-right-to-pin, floating the row into the panel's Quick Access section.
///
/// The leading edge, deliberately: the trailing edge is already a full-swipe Reset, and sharing
/// it would make a fast full swipe ambiguous — occasionally throwing away a value someone had
/// just dialled in because they meant to pin it.
@available(iOS 16.0, *)
private struct PinSwipeModifier: ViewModifier {
    let tweakID: String

    /// ⚠️ Observed, and the pinned flag is read straight from it rather than mirrored into
    /// `@State`. A `@State` mirror is seeded once per view identity and never re-seeded, so a row
    /// pinned from anywhere else — the Quick Access list, or simply a row that existed before the
    /// pin — kept offering "Pin" for something already pinned. Cheap here: a pin is one write,
    /// not a per-tick slider drag, so there is no churn to debounce against.
    @ObservedObject var storage: TweakStorage

    private var isPinned: Bool { storage.isPinned(key: tweakID) }

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    let wasPinned = isPinned
                    storage.togglePin(key: tweakID)
                    // Unpinning means "get this out of Quick Access", and a recent edit floats a
                    // row in there just as a pin does. Without this the row stays put and the
                    // gesture looks broken. It returns when the tweak is next edited or pinned.
                    if wasPinned { storage.forgetRecent(key: tweakID) }
                } label: {
                    Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash.fill" : "pin.fill")
                }
                .tint(.yellow)
            }
    }
}

@available(iOS 16.0, *)
private extension View {
    func resetSwipeAction(tweakID: String, storage: TweakStorage, onReset: @escaping () -> Void) -> some View {
        modifier(ResetSwipeModifier(tweakID: tweakID, storage: storage, onReset: onReset))
    }

    func pinSwipeAction(tweakID: String, storage: TweakStorage) -> some View {
        modifier(PinSwipeModifier(tweakID: tweakID, storage: storage))
    }
}

// MARK: - Description

/// A tweak's name with its optional one-line gloss underneath.
///
/// Falls back to a bare `Text` when there's no description, so rows without one keep exactly
/// the layout they had before descriptions existed — no reserved empty space.
@available(iOS 16.0, *)
private struct TweakLabel: View {
    let tweak: TweakMetadata

    var body: some View {
        if let description = tweak.description {
            VStack(alignment: .leading, spacing: 1) {
                Text(tweak.name)
                TweakDescriptionText(description)
            }
        } else {
            Text(tweak.name)
        }
    }
}

/// The gloss itself: small, monospaced, secondary. Deliberately quiet — it's there to be read
/// when a name is cryptic, not to compete with the control.
@available(iOS 16.0, *)
private struct TweakDescriptionText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
    }
}

// MARK: - Modified Indicator

/// The orange dot marking a tweak whose value differs from its default.
///
/// Decorative: the row's accessibility label already carries the value, and a dot that announced
/// itself would interrupt every VoiceOver pass over a modified row.
@available(iOS 16.0, *)
private struct ModifiedDot: View {
    let isModified: Bool

    var body: some View {
        if isModified {
            Circle()
                .fill(.orange)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Toggle Row

@available(iOS 16.0, *)
private struct ToggleTweakRow: View {
    let tweak: TweakMetadata
    let storage: TweakStorage
    @State private var value: Bool

    init(tweak: TweakMetadata, storage: TweakStorage) {
        self.tweak = tweak
        self.storage = storage
        let defaultValue = tweak.defaultValue as? Bool ?? false
        self._value = State(initialValue: storage.value(forKey: tweak.id, default: defaultValue))
    }

    var body: some View {
        Toggle(isOn: $value) {
            HStack {
                TweakLabel(tweak: tweak)
                ModifiedDot(isModified: storage.isModified(key: tweak.id))
                Spacer(minLength: 0)
            }
            // The label fills everything left of the switch, so the whole row flips the toggle.
            // The gesture lives *inside* the label rather than on the row: a tap gesture wrapping
            // the row would sit over the UISwitch too, and both would fire — flipping twice and
            // landing back where it started.
            .contentShape(Rectangle())
            .onTapGesture { value.toggle() }
        }
        .onChange(of: value) { newValue in
            storage.setValue(newValue, forKey: tweak.id, default: tweak.defaultValue as? Bool ?? false)
        }
        .resetSwipeAction(tweakID: tweak.id, storage: storage) {
            storage.reset(key: tweak.id)
            value = tweak.defaultValue as? Bool ?? false
        }
    }
}

// MARK: - Slider Row

@available(iOS 16.0, *)
private struct SliderTweakRow: View {
    let tweak: TweakMetadata
    let storage: TweakStorage
    @State private var value: Double
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isFocused: Bool

    init(tweak: TweakMetadata, storage: TweakStorage) {
        self.tweak = tweak
        self.storage = storage
        let defaultValue: Double
        if let d = tweak.defaultValue as? Double {
            defaultValue = d
        } else if let d = tweak.defaultValue as? CGFloat {
            defaultValue = Double(d)
        } else if let d = tweak.defaultValue as? Int {
            defaultValue = Double(d)
        } else {
            defaultValue = 0
        }
        self._value = State(initialValue: storage.value(forKey: tweak.id, default: defaultValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isEditing {
                HStack {
                    Text(tweak.name)
                    Spacer()
                    TextField("", text: $editText, onCommit: commitEdit)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .monospacedDigit()
                        .focused($isFocused)
                        .onAppear { isFocused = true }
                        .onChange(of: isFocused) { focused in
                            if !focused { commitEdit() }
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") { commitEdit() }
                            }
                        }
                    ModifiedDot(isModified: storage.isModified(key: tweak.id))
                }
            } else {
                // The whole name-and-value line opens the numeric editor, not just the number.
                // A four-character value like "0.250" is a ~35pt target; the line is the full row.
                Button {
                    editText = formattedValue
                    isEditing = true
                } label: {
                    HStack {
                        Text(tweak.name)
                        Spacer()
                        Text(formattedValue)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                        ModifiedDot(isModified: storage.isModified(key: tweak.id))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tweak.name)
                .accessibilityValue(formattedValue)
                .accessibilityHint("Type an exact value")
            }

            if let description = tweak.description {
                TweakDescriptionText(description)
            }

            if let range = tweak.range {
                Slider(value: $value, in: range) { _ in }
                    .onChange(of: value) { newValue in
                        storage.setValue(newValue, forKey: tweak.id, default: sliderDefault)
                    }
                    .accessibilityLabel(tweak.name)
            }
        }
        .resetSwipeAction(tweakID: tweak.id, storage: storage) {
            storage.reset(key: tweak.id)
            value = sliderDefault
        }
    }

    private var sliderDefault: Double {
        if let d = tweak.defaultValue as? Double { return d }
        if let d = tweak.defaultValue as? CGFloat { return Double(d) }
        if let d = tweak.defaultValue as? Int { return Double(d) }
        return 0
    }

    private func commitEdit() {
        isEditing = false
        guard let parsed = Double(editText) else { return }
        if let range = tweak.range {
            value = min(max(parsed, range.lowerBound), range.upperBound)
        } else {
            value = parsed
        }
        storage.setValue(value, forKey: tweak.id, default: sliderDefault)
    }

    private var formattedValue: String {
        if tweak.defaultValue is Int {
            return "\(Int(value))"
        }
        if let range = tweak.range {
            let span = range.upperBound - range.lowerBound
            if span <= 1 {
                return String(format: "%.3f", value)
            } else if span <= 10 {
                return String(format: "%.2f", value)
            }
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Stepper Row

@available(iOS 16.0, *)
private struct StepperTweakRow: View {
    let tweak: TweakMetadata
    let storage: TweakStorage
    @State private var value: Int
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isFocused: Bool

    init(tweak: TweakMetadata, storage: TweakStorage) {
        self.tweak = tweak
        self.storage = storage
        let defaultValue = tweak.defaultValue as? Int ?? 0
        self._value = State(initialValue: storage.value(forKey: tweak.id, default: defaultValue))
    }

    var body: some View {
        HStack {
            if isEditing {
                TweakLabel(tweak: tweak)
                ModifiedDot(isModified: storage.isModified(key: tweak.id))
                Spacer()
                TextField("", text: $editText, onCommit: commitEdit)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .monospacedDigit()
                    .focused($isFocused)
                    .onAppear { isFocused = true }
                    .onChange(of: isFocused) { focused in
                        if !focused { commitEdit() }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { commitEdit() }
                        }
                    }
            } else {
                // Everything left of the +/- control opens the numeric editor. `.plain` keeps the
                // label looking like a label; `.borderless` would tint the tweak's name blue.
                Button {
                    editText = "\(value)"
                    isEditing = true
                } label: {
                    HStack {
                        TweakLabel(tweak: tweak)
                        ModifiedDot(isModified: storage.isModified(key: tweak.id))
                        Spacer()
                        Text("\(value)")
                            .monospacedDigit()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tweak.name)
                .accessibilityValue("\(value)")
                .accessibilityHint("Type an exact value")
            }

            Stepper("", value: $value)
                .labelsHidden()
                .onChange(of: value) { newValue in
                    storage.setValue(newValue, forKey: tweak.id, default: tweak.defaultValue as? Int ?? 0)
                }
                .accessibilityLabel(tweak.name)
        }
        .resetSwipeAction(tweakID: tweak.id, storage: storage) {
            storage.reset(key: tweak.id)
            value = tweak.defaultValue as? Int ?? 0
        }
    }

    private func commitEdit() {
        isEditing = false
        guard let parsed = Int(editText) else { return }
        value = parsed
        storage.setValue(value, forKey: tweak.id, default: tweak.defaultValue as? Int ?? 0)
    }
}

// MARK: - Picker Row

/// A tweak with a fixed set of string options, as a stock menu `Picker`.
///
/// Deliberately a real `Picker` rather than a hand-rolled `Menu` of `Button`s. Two things come
/// free with it and neither is reliably reproducible by hand:
///
/// - **The whole row opens the menu.** A `Menu` is only tappable across its own label, which here
///   was a short value string and a chevron — a target a few dozen points wide at the far right
///   of the row.
/// - **The menu items are real `UIMenu` actions**, so each one is tappable across the full width
///   of the popover and the selected option gets the system checkmark. A `Menu` whose items are
///   custom views (the old code branched between `Label` and `Text` to draw its own checkmark)
///   drops out of that bridge and gets SwiftUI-drawn items, where only the glyphs themselves are
///   hit-testable — hence taps landing in the gaps and doing nothing.
@available(iOS 16.0, *)
private struct PickerTweakRow: View {
    let tweak: TweakMetadata
    let storage: TweakStorage
    @State private var value: String

    init(tweak: TweakMetadata, storage: TweakStorage) {
        self.tweak = tweak
        self.storage = storage
        let defaultValue = tweak.defaultValue as? String ?? ""
        self._value = State(initialValue: storage.value(forKey: tweak.id, default: defaultValue))
    }

    var body: some View {
        Picker(selection: $value) {
            ForEach(tweak.options ?? [], id: \.self) { option in
                Text(option.isEmpty ? "(empty)" : option)
                    .tag(option)
            }
        } label: {
            HStack {
                TweakLabel(tweak: tweak)
                ModifiedDot(isModified: storage.isModified(key: tweak.id))
            }
        }
        .pickerStyle(.menu)
        .onChange(of: value) { newValue in
            storage.setValue(newValue, forKey: tweak.id, default: tweak.defaultValue as? String ?? "")
        }
        .resetSwipeAction(tweakID: tweak.id, storage: storage) {
            storage.reset(key: tweak.id)
            value = tweak.defaultValue as? String ?? ""
        }
    }
}

// MARK: - Text Row

@available(iOS 16.0, *)
private struct TextTweakRow: View {
    let tweak: TweakMetadata
    let storage: TweakStorage
    @State private var value: String
    @FocusState private var isFocused: Bool

    init(tweak: TweakMetadata, storage: TweakStorage) {
        self.tweak = tweak
        self.storage = storage
        let defaultValue = tweak.defaultValue as? String ?? ""
        self._value = State(initialValue: storage.value(forKey: tweak.id, default: defaultValue))
    }

    var body: some View {
        HStack {
            HStack {
                TweakLabel(tweak: tweak)
                ModifiedDot(isModified: storage.isModified(key: tweak.id))
                Spacer(minLength: 0)
            }
            // Tapping the name focuses the field, so the dead space between them isn't dead.
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }

            TextField("Value", text: $value)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 150)
                .focused($isFocused)
                .onChange(of: value) { newValue in
                    storage.setValue(newValue, forKey: tweak.id, default: tweak.defaultValue as? String ?? "")
                }
                .accessibilityLabel(tweak.name)
        }
        .resetSwipeAction(tweakID: tweak.id, storage: storage) {
            storage.reset(key: tweak.id)
            value = tweak.defaultValue as? String ?? ""
        }
    }
}

// MARK: - Action Row

@available(iOS 16.0, *)
private struct ActionTweakRow: View {
    let tweak: TweakMetadata

    var body: some View {
        Button {
            tweak.action?()
        } label: {
            TweakLabel(tweak: tweak)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(ListHighlightButtonStyle())
    }
}
