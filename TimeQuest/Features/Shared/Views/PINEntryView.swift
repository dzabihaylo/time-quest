import SwiftUI
import CryptoKit

struct PINEntryView: View {
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var tokens
    @State private var enteredDigits: [Int] = []
    @State private var confirmDigits: [Int] = []
    @State private var isConfirming = false
    @State private var shakeOffset: CGFloat = 0
    @State private var errorMessage: String?

    private let pinLength = 4
    private let pinHashKey = "parentPINHash"

    private var isFirstTimeSetup: Bool {
        UserDefaults.standard.string(forKey: pinHashKey) == nil
    }

    private var promptText: String {
        if isFirstTimeSetup {
            return isConfirming ? "Confirm code" : "Set a code"
        }
        return "Enter code"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                Text(promptText)
                    .font(tokens.font(.title2, weight: .medium))

                if let errorMessage {
                    Text(errorMessage)
                        .font(tokens.font(.caption))
                        .foregroundStyle(tokens.negative)
                        .transition(.opacity)
                }

                // PIN dots
                HStack(spacing: 16) {
                    ForEach(0..<pinLength, id: \.self) { index in
                        Circle()
                            .fill(index < enteredDigits.count ? Color.primary : Color.clear)
                            .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                            .frame(width: 16, height: 16)
                    }
                }
                .offset(x: shakeOffset)

                Spacer()

                // Number pad
                numberPad

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(.secondary)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private var numberPad: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(1...3, id: \.self) { col in
                        let digit = row * 3 + col
                        numberButton(digit)
                    }
                }
            }
            // Bottom row: empty, 0, delete
            HStack(spacing: 20) {
                Color.clear
                    .frame(width: 72, height: 72)

                numberButton(0)

                Button {
                    if !enteredDigits.isEmpty {
                        enteredDigits.removeLast()
                    }
                } label: {
                    Image(systemName: "delete.backward")
                        .font(tokens.font(.title2))
                        .frame(width: 72, height: 72)
                        .foregroundStyle(tokens.textPrimary)
                }
            }
        }
    }

    private func numberButton(_ digit: Int) -> some View {
        Button {
            digitTapped(digit)
        } label: {
            Text("\(digit)")
                .font(tokens.font(.title, weight: .medium))
                .frame(width: 72, height: 72)
                .background(tokens.surfaceSecondary)
                .clipShape(Circle())
                .foregroundStyle(tokens.textPrimary)
        }
    }

    private func digitTapped(_ digit: Int) {
        guard enteredDigits.count < pinLength else { return }

        enteredDigits.append(digit)
        errorMessage = nil

        if enteredDigits.count == pinLength {
            // Small delay so the user sees the last dot fill
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                handlePINComplete()
            }
        }
    }

    private func handlePINComplete() {
        if isFirstTimeSetup {
            handleSetup()
        } else {
            handleVerify()
        }
    }

    private func handleSetup() {
        if !isConfirming {
            // First entry -- save and ask to confirm
            confirmDigits = enteredDigits
            enteredDigits = []
            isConfirming = true
        } else {
            // Confirming
            if enteredDigits == confirmDigits {
                // PINs match -- hash and store
                let pinString = enteredDigits.map(String.init).joined()
                storePINHash(pinString)
                onSuccess()
            } else {
                // Mismatch -- restart
                shake()
                errorMessage = "Codes didn't match. Try again."
                enteredDigits = []
                confirmDigits = []
                isConfirming = false
            }
        }
    }

    private func handleVerify() {
        let pinString = enteredDigits.map(String.init).joined()
        let inputHash = hashPIN(pinString)
        let storedHash = UserDefaults.standard.string(forKey: pinHashKey)

        if inputHash == storedHash {
            onSuccess()
        } else {
            shake()
            errorMessage = "Incorrect code"
            enteredDigits = []
        }
    }

    private func storePINHash(_ pin: String) {
        let hash = hashPIN(pin)
        UserDefaults.standard.set(hash, forKey: pinHashKey)
    }

    private func hashPIN(_ pin: String) -> String {
        let data = Data(pin.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func shake() {
        withAnimation(.default) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.default) {
                shakeOffset = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.default) {
                shakeOffset = 0
            }
        }
    }
}
