//
//  TweakSectionDetailView.swift
//  DevTweaks
//
//  Detail view for editing all tweaks in a section.
//

#if DEBUG
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

            // Tweaks
            Section {
                ForEach(section.tweaks) { tweak in
                    TweakRow(tweak: tweak, storage: storage, isDisabled: isDisabled)
                        .id("\(tweak.id)-\(refreshID)")
                }
            } header: {
                if section.hasMasterToggle {
                    Text("Settings")
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
}

// MARK: - Master Toggle Row

@available(iOS 16.0, *)
private struct MasterToggleRow: View {
    let section: TweakSectionMetadata
    let storage: TweakStorage
    @Binding var refreshID: UUID
    @State private var isEnabled: Bool

    init(section: TweakSectionMetadata, storage: TweakStorage, refreshID: Binding<UUID>) {
        self.section = section
        self.storage = storage
        self._refreshID = refreshID
        self._isEnabled = State(initialValue: storage.value(forKey: section.id + ".isEnabled", default: false))
    }

    var body: some View {
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
        }
    }
}

// MARK: - Tweak Row

@available(iOS 16.0, *)
struct TweakRow: View {
    let tweak: TweakMetadata
    let storage: TweakStorage
    var isDisabled: Bool = false

    var body: some View {
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
    }
}

// MARK: - Swipe-to-Reset Helper

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

@available(iOS 16.0, *)
private extension View {
    func resetSwipeAction(tweakID: String, storage: TweakStorage, onReset: @escaping () -> Void) -> some View {
        modifier(ResetSwipeModifier(tweakID: tweakID, storage: storage, onReset: onReset))
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
            Toggle(tweak.name, isOn: $value)
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
            Text(tweak.name)

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
            Text(tweak.name)
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
            Text(tweak.name)

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
            Text(tweak.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(ListHighlightButtonStyle())
    }
}
#endif
