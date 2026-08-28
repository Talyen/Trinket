import SwiftUI

public extension View {
    func trinketFailureAlert(_ title: String, message: Binding<String?>) -> some View {
        alert(
            title,
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        message.wrappedValue = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
