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

            Toggle("Enable Overrides", isOn: $isEnabled)
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
    let storage: TweakStorage

    /// Mirrors `storage.isPinned` so the button title flips the moment it's tapped — the same
    /// local-state pattern the value rows use. Storage stays the source of truth.
    @State private var isPinned: Bool

    init(tweakID: String, storage: TweakStorage) {
        self.tweakID = tweakID
        self.storage = storage
        self._isPinned = State(initialValue: storage.isPinned(key: tweakID))
    }

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    storage.togglePin(key: tweakID)
                    isPinned = storage.isPinned(key: tweakID)
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
        HStack {
            Toggle(isOn: $value) {
                TweakLabel(tweak: tweak)
            }
                .onChange(of: value) { newValue in
                    storage.setValue(newValue, forKey: tweak.id, default: tweak.defaultValue as? Bool ?? false)
                }

            if storage.isModified(key: tweak.id) {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }
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
            HStack {
                Text(tweak.name)
                Spacer()
                if isEditing {
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
                } else {
                    Text(formattedValue)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .onTapGesture {
                            editText = formattedValue
                            isEditing = true
                        }
                }
                if storage.isModified(key: tweak.id) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                }
            }

            if let description = tweak.description {
                TweakDescriptionText(description)
            }

            if let range = tweak.range {
                Slider(value: $value, in: range) { _ in }
                    .onChange(of: value) { newValue in
                        storage.setValue(newValue, forKey: tweak.id, default: sliderDefault)
                    }
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
            TweakLabel(tweak: tweak)

            if storage.isModified(key: tweak.id) {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }

            Spacer()

            if isEditing {
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
                Text("\(value)")
                    .monospacedDigit()
                    .onTapGesture {
                        editText = "\(value)"
                        isEditing = true
                    }
            }

            Stepper("", value: $value)
                .labelsHidden()
                .onChange(of: value) { newValue in
                    storage.setValue(newValue, forKey: tweak.id, default: tweak.defaultValue as? Int ?? 0)
                }
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
        HStack {
            TweakLabel(tweak: tweak)
                .onTapGesture(count: 2) {
                    storage.reset(key: tweak.id)
                    value = tweak.defaultValue as? String ?? ""
                }

            Spacer()

            Menu {
                ForEach(tweak.options ?? [], id: \.self) { option in
                    Button {
                        value = option
                    } label: {
                        if option == value {
                            Label(option.isEmpty ? "(empty)" : option, systemImage: "checkmark")
                        } else {
                            Text(option.isEmpty ? "(empty)" : option)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(value.isEmpty ? "(empty)" : value)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: value) { newValue in
                storage.setValue(newValue, forKey: tweak.id, default: tweak.defaultValue as? String ?? "")
            }

            if storage.isModified(key: tweak.id) {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }
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

    init(tweak: TweakMetadata, storage: TweakStorage) {
        self.tweak = tweak
        self.storage = storage
        let defaultValue = tweak.defaultValue as? String ?? ""
        self._value = State(initialValue: storage.value(forKey: tweak.id, default: defaultValue))
    }

    var body: some View {
        HStack {
            TweakLabel(tweak: tweak)

            if storage.isModified(key: tweak.id) {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }

            Spacer()

            TextField("Value", text: $value)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 150)
                .onChange(of: value) { newValue in
                    storage.setValue(newValue, forKey: tweak.id, default: tweak.defaultValue as? String ?? "")
                }
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
