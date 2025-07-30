//
//  AddressAutocompleteField.swift
//  InOfficeDaysTracker
//
//  SwiftUI component for address input with autocomplete functionality
//

import SwiftUI
import MapKit
import CoreLocation

struct AddressAutocompleteField: View {
    
    // MARK: - Bindings
    @Binding var selectedAddress: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    
    // MARK: - State
    @State private var inputText: String = ""
    @State private var showingSuggestions = false
    @State private var isTextFieldFocused = false
    
    // MARK: - Services
    @StateObject private var autocompleteService = AddressAutocompleteService()
    
    // MARK: - Properties
    let placeholder: String
    let useCurrentLocationAction: (() -> Void)?
    
    // MARK: - Initialization
    init(
        selectedAddress: Binding<String>,
        selectedCoordinate: Binding<CLLocationCoordinate2D?>,
        placeholder: String = "Enter office address",
        useCurrentLocationAction: (() -> Void)? = nil
    ) {
        self._selectedAddress = selectedAddress
        self._selectedCoordinate = selectedCoordinate
        self.placeholder = placeholder
        self.useCurrentLocationAction = useCurrentLocationAction
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Address Input Field
            VStack(spacing: 0) {
                HStack {
                    TextField(placeholder, text: $inputText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isTextFieldFocused = true
                                showingSuggestions = !autocompleteService.suggestions.isEmpty
                            }
                        }
                        .onChange(of: inputText) { _, newValue in
                            handleTextChange(newValue)
                        }
                        .onSubmit {
                            handleManualEntry()
                        }
                        .accessibilityLabel("Office address input field")
                        .accessibilityHint("Enter your office address or select from suggestions")
                    
                    // Loading indicator
                    if autocompleteService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                    }
                    
                    // Clear button
                    if !inputText.isEmpty {
                        Button(action: clearInput) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .accessibilityLabel("Clear address")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isTextFieldFocused ? Color.blue : Color(.systemGray4), lineWidth: 1)
                )
                
                // Suggestions Dropdown
                if showingSuggestions && !autocompleteService.suggestions.isEmpty {
                    suggestionsView
                }
            }
            
            // "Use Current Location" Button
            if let useCurrentLocationAction = useCurrentLocationAction {
                Button(action: useCurrentLocationAction) {
                    HStack {
                        Image(systemName: "location")
                        Text("Use Current Location")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .accessibilityLabel("Use current location for office address")
            }
            
            // Error Message
            if let errorMessage = autocompleteService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            inputText = selectedAddress
        }
        .onChange(of: selectedAddress) { _, newValue in
            if inputText != newValue {
                inputText = newValue
            }
        }
        .onTapGesture {
            // Close suggestions when tapping outside
            if showingSuggestions {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingSuggestions = false
                    isTextFieldFocused = false
                }
            }
        }
    }
    
    // MARK: - Suggestions View
    private var suggestionsView: some View {
        VStack(spacing: 0) {
            ForEach(autocompleteService.suggestions, id: \.self) { suggestion in
                suggestionRow(suggestion)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Suggestion Row
    private func suggestionRow(_ suggestion: MKLocalSearchCompletion) -> some View {
        Button(action: {
            selectSuggestion(suggestion)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if !suggestion.subtitle.isEmpty {
                        Text(suggestion.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                Image(systemName: "location")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
        )
        .accessibilityLabel("Address suggestion: \(suggestion.title), \(suggestion.subtitle)")
        .accessibilityHint("Tap to select this address")
    }
    
    // MARK: - Actions
    private func handleTextChange(_ newValue: String) {
        if newValue != selectedAddress {
            autocompleteService.searchForLocations(matching: newValue)
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSuggestions = !newValue.isEmpty && isTextFieldFocused
            }
        }
    }
    
    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        Task {
            if let result = await autocompleteService.selectSuggestion(suggestion) {
                await MainActor.run {
                    inputText = result.address
                    selectedAddress = result.address
                    selectedCoordinate = result.coordinate
                    
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingSuggestions = false
                        isTextFieldFocused = false
                    }
                }
            }
        }
    }
    
    private func handleManualEntry() {
        selectedAddress = inputText
        withAnimation(.easeInOut(duration: 0.2)) {
            showingSuggestions = false
            isTextFieldFocused = false
        }
        autocompleteService.clearSuggestions()
    }
    
    private func clearInput() {
        inputText = ""
        selectedAddress = ""
        selectedCoordinate = nil
        autocompleteService.clearSuggestions()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showingSuggestions = false
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        AddressAutocompleteField(
            selectedAddress: .constant(""),
            selectedCoordinate: .constant(nil),
            placeholder: "Enter office address",
            useCurrentLocationAction: {
                print("Use current location tapped")
            }
        )
        
        Spacer()
    }
    .padding()
}
