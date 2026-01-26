//
//  SearchBar.swift
//  365WeaponsAdmin
//
//  Unified search bar component with optional filter button.
//

import SwiftUI

// MARK: - SearchBar

/// A reusable search bar component with clear button and optional filter functionality.
///
/// Example usage:
/// ```swift
/// @State private var searchText = ""
/// @State private var showFilters = false
///
/// SearchBar(
///     text: $searchText,
///     placeholder: "Search products...",
///     showFilterButton: true,
///     onFilterTap: { showFilters = true }
/// )
/// ```
struct SearchBar: View {
    // MARK: - Properties

    @ObservedObject private var appearanceManager = AppearanceManager.shared

    /// Binding to the search text
    @Binding var text: String

    /// Placeholder text shown when the search field is empty
    var placeholder: String = "Search..."

    /// Whether to show the filter button
    var showFilterButton: Bool = false

    /// Callback when the filter button is tapped
    var onFilterTap: (() -> Void)? = nil

    /// Callback when search is submitted
    var onSubmit: (() -> Void)? = nil

    /// Callback when text changes
    var onTextChange: ((String) -> Void)? = nil

    /// Whether the search bar should be focused on appear
    var focusOnAppear: Bool = false

    // MARK: - Private State

    @FocusState private var isFocused: Bool

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            searchField

            if showFilterButton {
                filterButton
            }
        }
    }

    // MARK: - Private Views

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.appTextSecondary)
                .font(.body)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(Color.appTextPrimary)
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit {
                    onSubmit?()
                }
                .onChange(of: text) { _, newValue in
                    onTextChange?(newValue)
                }

            if !text.isEmpty {
                clearButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.appSurface2)
        .cornerRadius(10)
        .onAppear {
            if focusOnAppear {
                isFocused = true
            }
        }
    }

    private var clearButton: some View {
        Button(action: clearSearch) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(Color.appTextSecondary)
                .font(.body)
        }
        .buttonStyle(.plain)
    }

    private var filterButton: some View {
        Button(action: { onFilterTap?() }) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.title2)
                .foregroundColor(Color.appAccent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Private Methods

    private func clearSearch() {
        text = ""
        onTextChange?("")
    }
}

// MARK: - Search Bar Style Modifier

/// Style variants for the search bar.
enum SearchBarStyle {
    case standard
    case prominent
    case minimal
}

extension SearchBar {
    /// Apply a predefined style to the search bar.
    func searchBarStyle(_ style: SearchBarStyle) -> some View {
        switch style {
        case .standard:
            return AnyView(self)
        case .prominent:
            return AnyView(
                self
                    .padding(.vertical, 4)
                    .background(Color.appSurface)
                    .cornerRadius(12)
            )
        case .minimal:
            return AnyView(self)
        }
    }
}

// MARK: - Search Bar with Scope

/// A search bar with scope buttons for filtering search categories.
struct ScopedSearchBar<Scope: Hashable>: View where Scope: CaseIterable, Scope: CustomStringConvertible {
    @Binding var text: String
    @Binding var scope: Scope
    var placeholder: String = "Search..."
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            SearchBar(
                text: $text,
                placeholder: placeholder,
                onSubmit: onSubmit
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(Scope.allCases), id: \.self) { scopeItem in
                        ScopeButton(
                            title: scopeItem.description,
                            isSelected: scope == scopeItem,
                            action: { scope = scopeItem }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Scope Button

private struct ScopeButton: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.appAccent : Color.appSurface2)
                .foregroundColor(isSelected ? Color.appTextPrimary : Color.appTextSecondary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inline Search Bar

/// A compact inline search bar for use in navigation bars or tight spaces.
struct InlineSearchBar: View {
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    @Binding var text: String
    var placeholder: String = "Search..."
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.appTextSecondary)
                .font(.caption)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundColor(Color.appTextPrimary)
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.appTextSecondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.appSurface2)
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview("SearchBar Variants") {
    VStack(spacing: 24) {
        // Standard search bar
        SearchBar(
            text: .constant(""),
            placeholder: "Search orders..."
        )

        // Search bar with filter button
        SearchBar(
            text: .constant("Glock"),
            placeholder: "Search products...",
            showFilterButton: true,
            onFilterTap: {}
        )

        // Inline search bar
        InlineSearchBar(
            text: .constant(""),
            placeholder: "Quick search..."
        )

        Spacer()
    }
    .padding()
    .background(Color.appBackground)
}
