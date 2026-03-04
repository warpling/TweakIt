//
//  TweaksListView.swift
//  DevTweaks
//
//  Searchable category/section browser for all tweaks.
//

#if DEBUG
import SwiftUI

/// Content view for browsing tweaks by category and section.
///
/// Displays a searchable, collapsible list of all categories and their sections.
/// Tapping a section navigates to `TweakSectionDetailView`.
@available(iOS 16.0, *)
public struct TweaksListView: View {
    let store: TweakStore
    @State private var searchText = ""
    @State private var collapsedCategories: Set<String> = {
        let saved = UserDefaults.standard.stringArray(forKey: "DevTweaks.collapsedCategories") ?? []
        return Set(saved)
    }()
    @ObservedObject private var storage: TweakStorage

    public init(store: TweakStore) {
        self.store = store
        self.storage = store.storage
    }

    public var body: some View {
        List {
            ForEach(filteredCategories) { category in
                Section {
                    if !collapsedCategories.contains(category.id) || !searchText.isEmpty {
                        ForEach(filteredSections(for: category)) { section in
                            NavigationLink {
                                TweakSectionDetailView(section: section, storage: storage)
                            } label: {
                                SectionRowView(section: section, storage: storage)
                            }
                        }
                    }
                } header: {
                    CategoryHeaderView(
                        category: category,
                        storage: storage,
                        isCollapsed: collapsedCategories.contains(category.id) && searchText.isEmpty
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if collapsedCategories.contains(category.id) {
                                collapsedCategories.remove(category.id)
                            } else {
                                collapsedCategories.insert(category.id)
                            }
                            UserDefaults.standard.set(Array(collapsedCategories), forKey: "DevTweaks.collapsedCategories")
                        }
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search tweaks")
    }

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
            section.tweaks.contains { $0.name.lowercased().contains(lowercased) }
        }
    }
}

// MARK: - Category Header

@available(iOS 16.0, *)
private struct CategoryHeaderView: View {
    let category: TweakCategoryMetadata
    let storage: TweakStorage
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
    let storage: TweakStorage

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
#endif
