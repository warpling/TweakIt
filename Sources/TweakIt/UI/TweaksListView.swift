//
//  TweaksListView.swift
//  TweakIt
//
//  Searchable category/section browser for all tweaks.
//

import SwiftUI

/// Content view for browsing tweaks by category and section.
///
/// Displays a searchable, collapsible list of all categories and their sections.
/// Tapping a section navigates to `TweakSectionDetailView`.
///
/// A **Quick Access** pseudo-section sits above the categories, holding pinned tweaks followed by
/// recently edited ones. Its rows are the same live controls as in a section detail view, so the
/// handful of tweaks you're actively working on can be adjusted without opening anything.
///
/// Categories start **collapsed** and remember what you expand across launches.
@available(iOS 16.0, *)
public struct TweaksListView: View {
    let store: TweakStore
    @State private var searchText = ""
    @State private var expandedCategories: Set<String> = ExpandedCategories.load()

    /// Recents are snapshotted when the list appears rather than read live. `setValue` moves a key
    /// to the front of the recents list on the very first slider tick, and a row that reorders
    /// itself out from under the finger dragging it is far worse than a slightly stale order.
    /// Popping back from a section detail re-fires `onAppear`, so edits made there do show up.
    @State private var recentKeysSnapshot: [String] = []

    @ObservedObject private var storage: TweakStorage

    /// Maximum rows in Quick Access. Pins come first, so a long pin list can fill it on its own
    /// and crowd recents out — which is the right precedence: a pin was deliberate, a recent wasn't.
    private static let quickAccessLimit = 8

    public init(store: TweakStore) {
        self.store = store
        self.storage = store.storage
    }

    public var body: some View {
        List {
            // Quick Access — hidden while searching, where the whole list is already filtered.
            if searchText.isEmpty {
                quickAccessSection
            }

            ForEach(filteredCategories) { category in
                // A search forces every matching category open; otherwise it's the saved state.
                let isExpanded = expandedCategories.contains(category.id) || !searchText.isEmpty

                if isExpanded {
                    Section {
                        ForEach(filteredSections(for: category)) { section in
                            NavigationLink {
                                TweakSectionDetailView(section: section, storage: storage)
                            } label: {
                                SectionRowView(section: section, storage: storage)
                            }
                        }
                    } header: {
                        CategoryHeaderView(
                            category: category,
                            storage: storage,
                            isCollapsed: false
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedCategories.remove(category.id)
                                ExpandedCategories.save(expandedCategories)
                            }
                        }
                        .textCase(nil)
                    }
                } else {
                    // Header only — no Section wrapper, no extra chrome
                    CategoryHeaderView(
                        category: category,
                        storage: storage,
                        isCollapsed: true
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedCategories.insert(category.id)
                            ExpandedCategories.save(expandedCategories)
                        }
                    }
                    .textCase(nil)
                    .listRowBackground(Color(.systemGroupedBackground))
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search tweaks")
        .onAppear { recentKeysSnapshot = storage.recentKeys }
    }

    // MARK: - Quick Access

    @ViewBuilder
    private var quickAccessSection: some View {
        let entries = quickAccessEntries
        if !entries.isEmpty {
            Section {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        TweakRow(tweak: entry.tweak, storage: storage, isDisabled: entry.isDisabled)

                        HStack(spacing: 3) {
                            if entry.isPinned {
                                Image(systemName: "pin.fill")
                            }
                            Text(entry.breadcrumb)
                        }
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    }
                }
            } header: {
                HStack(spacing: 6) {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.accentColor)
                    Text("Quick Access")
                }
                .textCase(nil)
            }
        }
    }

    /// Pinned keys in pin order, then recents that aren't already pinned, capped and resolved.
    private var quickAccessEntries: [QuickAccessEntry] {
        let pinnedKeys = storage.pinnedKeys
        let pinned = Set(pinnedKeys)
        let keys = pinnedKeys + recentKeysSnapshot.filter { !pinned.contains($0) }
        guard !keys.isEmpty else { return [] }

        // Section id → "Category · Section". A section id can't be split back into its parts —
        // category and section names contain spaces and may contain dots — so walk the tree.
        var breadcrumbs = [String: String]()
        for category in store.categories {
            for section in category.sections {
                breadcrumbs[section.id] = "\(category.name) · \(section.name)"
            }
        }

        var entries = [QuickAccessEntry]()
        for key in keys {
            guard entries.count < Self.quickAccessLimit else { break }
            // Ghost keys: a pin or recent naming a tweak that was since renamed or deleted
            // resolves to nothing. Skip it rather than render a dead row.
            guard let tweak = store.tweak(forKey: key),
                  let section = store.section(containing: key) else { continue }

            // Same rule the section detail applies: a master toggle that's off disables its tweaks.
            let isDisabled = section.hasMasterToggle
                && !storage.value(forKey: section.id + ".isEnabled", default: false)

            entries.append(QuickAccessEntry(
                tweak: tweak,
                breadcrumb: breadcrumbs[section.id] ?? section.name,
                isPinned: pinned.contains(key),
                isDisabled: isDisabled
            ))
        }
        return entries
    }

    // MARK: - Filtering

    private var filteredCategories: [TweakCategoryMetadata] {
        if searchText.isEmpty {
            return store.categories
        }
        return store.categories.filter { category in
            !filteredSections(for: category).isEmpty
        }
    }

    private func filteredSections(for category: TweakCategoryMetadata) -> [TweakSectionMetadata] {
        if searchText.isEmpty {
            return category.sections
        }
        let lowercased = searchText.lowercased()
        return category.sections.filter { section in
            section.name.lowercased().contains(lowercased) ||
            section.tweaks.contains { tweak in
                tweak.name.lowercased().contains(lowercased) ||
                tweak.description?.lowercased().contains(lowercased) == true
            }
        }
    }
}

// MARK: - Quick Access Entry

/// One resolved Quick Access row: a live tweak plus where it came from.
@available(iOS 16.0, *)
private struct QuickAccessEntry: Identifiable {
    let tweak: TweakMetadata
    /// "Category · Section", shown under the control so a floated row still says where it lives.
    let breadcrumb: String
    let isPinned: Bool
    let isDisabled: Bool

    var id: String { tweak.id }
}

// MARK: - Expanded Category Persistence

/// Which categories are expanded, persisted across launches.
///
/// 1.1.0 inverted this: it used to persist the *collapsed* set, so a fresh install started with
/// everything open. Storing the expanded set makes an empty default mean "all collapsed", and the
/// old key is deleted rather than migrated — migrating it would faithfully restore the
/// everything-expanded state this replaced.
@available(iOS 16.0, *)
private enum ExpandedCategories {
    private static let key = "TweakIt.expandedCategories"
    private static let legacyCollapsedKey = "TweakIt.collapsedCategories"

    /// Runs once per process — `load()` is called from a `@State` default, which SwiftUI
    /// re-evaluates on every rebuild of the view struct even though it keeps only the first value.
    private static let purgeLegacyKey: Void = {
        UserDefaults.standard.removeObject(forKey: legacyCollapsedKey)
    }()

    static func load() -> Set<String> {
        _ = purgeLegacyKey
        return Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func save(_ expanded: Set<String>) {
        UserDefaults.standard.set(Array(expanded), forKey: key)
    }
}

// MARK: - Category Header

@available(iOS 16.0, *)
private struct CategoryHeaderView: View {
    let category: TweakCategoryMetadata
    @ObservedObject var storage: TweakStorage
    var isCollapsed: Bool = false
    var onToggle: (() -> Void)? = nil

    var body: some View {
        Button {
            onToggle?()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .foregroundColor(.accentColor)
                Text(category.name)
                if category.sections.contains(where: { storage.isSectionModified($0.id) }) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Row

@available(iOS 16.0, *)
private struct SectionRowView: View {
    let section: TweakSectionMetadata
    @ObservedObject var storage: TweakStorage

    private var isEnabled: Bool {
        guard section.hasMasterToggle else { return true }
        return storage.value(forKey: section.id + ".isEnabled", default: false)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator for sections with a color
            if let color = section.color {
                Circle()
                    .fill(isEnabled ? color : color.opacity(0.3))
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(section.name)
                        .foregroundColor(section.hasMasterToggle && !isEnabled ? .secondary : .primary)

                    if storage.isSectionModified(section.id) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                    }
                }

                if section.hasMasterToggle && isEnabled {
                    let count = storage.modifiedCount(forSection: section.id) - 1
                    Text("\(count) override\(count == 1 ? "" : "s") enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }
}
