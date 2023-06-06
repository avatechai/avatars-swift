# Avatars

The avatech avatars SDK for Swift. Currently in preview status.

```swift
import SwiftUI
import Avatars

struct ContentView: View {
    
    @State private var text: Message = Message(text:"")
    @State private var avatarId = "YOUR_AVATAR_ID"
    
    @State private var textInput = ""
    
    var body: some View {
        VStack {
            AvatarView(text, avatarId)
            HStack {
                TextField("Enter text", text: $textInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    text = Message(text:textInput)
                    textInput = ""
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}
```
