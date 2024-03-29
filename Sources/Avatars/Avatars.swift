import SwiftUI
import WebKit
import SwiftUI
import WebKit
import Foundation
import Combine

public struct Message: Identifiable, Equatable {
    public let id = UUID()
    var text: String
    
    public init(_ text: String) {
        self.text = text
    }
}

@available(macOS 11.0, *)
public class AvatarViewModel: ObservableObject {
    
    @Published public var avatarId: String
    @Published public var x: Float
    @Published public var y: Float
    @Published public var scale: Float
    @Published public var rotation: Float
    @Published public var isDevelopment: Bool = false
    @Published public var currentEmotion: String?
    @Published public var availableEmotion: Array<String>?
    @Published public var audioSource: String?
    
    @Published public var rawBase64Audio: String?
    public init(avatarId: String, x: Float = 0, y: Float = 0, scale: Float = 1, rotation: Float, isDevelopment: Bool = false, currentEmotion: String? = nil) {
        self.avatarId = avatarId
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
        self.isDevelopment = isDevelopment
        self.currentEmotion = currentEmotion
    }
}


@available(macOS 11.0, *)
public extension View {
    func applyAvatarViewModelModifiers(_ viewModel: AvatarViewModel, with webViewStore: WebViewStore) -> some View {
        self
            .onReceive(viewModel.$isDevelopment) { webViewStore.sendEvent("debugChange", String($0))}
            .onReceive(viewModel.$avatarId) { webViewStore.sendEvent("avatarIdChange", $0) }
            .onReceive(viewModel.$x) { webViewStore.sendEvent("xChange", String($0)) }
            .onReceive(viewModel.$y) { webViewStore.sendEvent("yChange", String($0)) }
            .onReceive(viewModel.$scale) { webViewStore.sendEvent("scaleChange", String($0)) }
            .onReceive(viewModel.$rotation) { webViewStore.sendEvent("rotationChange", String($0)) }
            .onReceive(viewModel.$currentEmotion) { webViewStore.sendEvent("emotionChange", String($0 ?? "")) }
            .onReceive(viewModel.$rawBase64Audio) { webViewStore.sendEvent("rawBase64AudioChange", String($0 ?? "")) }
            .onReceive(viewModel.$audioSource) { webViewStore.sendEvent("audioSourceChange", String($0 ?? "")) }
    }
}


@available(macOS 11.0, *)
public struct AvatarView: View {
    
    @StateObject var webViewStore = WebViewStore()
    
    @ObservedObject var viewModel: AvatarViewModel
    
    public init(_ viewModel: AvatarViewModel) {
        self.viewModel = viewModel
    }
    
    func onCallback (eventName: String, value: Any) {
        if (eventName == "clientReady") {
            self.webViewStore.sendEvent("avatarIdChange", viewModel.avatarId)
            self.webViewStore.sendEvent("xChange", String(viewModel.x))
            self.webViewStore.sendEvent("yChange", String(viewModel.y))
            self.webViewStore.sendEvent("scaleChange", String(viewModel.scale))
            self.webViewStore.sendEvent("rotationChange", String(viewModel.rotation))
            self.webViewStore.sendEvent("debugChange", String(viewModel.isDevelopment))
        }
        if (eventName == "emotionUpdate") {
                self.viewModel.availableEmotion = value as? Array<String>
        }
    }
    
    public var body: some View {
        WebView(webView: webViewStore.webView)
            .applyAvatarViewModelModifiers(viewModel, with: webViewStore)
            .onAppear {
                self.webViewStore.messageHandler = MessageHandler(callbackAction: onCallback)
                
                if (viewModel.isDevelopment) {
                    self.webViewStore.webView.load(URLRequest(url: URL(string: "http://localhost:3002/")!))
                } else {
                    self.webViewStore.webView.load(URLRequest(url: URL(string: "https://embed.api.avatech.ai/")!))
                }
            }
    }
}

public class MessageHandler: NSObject, WKScriptMessageHandler {
    
    var callbackAction: (String, Any) -> ()
    
    public init (callbackAction: @escaping (String, Any) -> ()) {
        self.callbackAction = callbackAction
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String : Any] else {
            return
        }
        
        callbackAction(
            dict["eventName"] as! String,
            dict["value"] as Any? ?? ""
        )
    }
}


//https://github.com/kylehickinson/SwiftUI-WebView
@dynamicMemberLookup
public class WebViewStore: ObservableObject {
    
    @Published public var webView: WKWebView {
        didSet {
            setupObservers()
        }
    }
    
    public func sendEvent(_ eventName: String,_ value: String) {
        self.webView.evaluateJavaScript(
            """
            window.sendHandleAvatarEvent('\(eventName)', '\(value)');
            """
        )
    }
    
    @Published public var messageHandler: MessageHandler? {
        didSet {
            if (messageHandler != nil)
            {
                webView.configuration.userContentController.add(messageHandler!, name: "handleAvatarEvents")
            }
        }
    }
    
    public init() {
        let preferences = WKPreferences()
        //      preferences.javaScriptEnabled = true
        
        let configuration = WKWebViewConfiguration()
        //      configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypes.video
#if os(iOS)
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        } else {
            configuration.requiresUserActionForMediaPlayback = false
        }
#endif
        configuration.preferences = preferences
        
        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        
#if os(macOS)
        webView.setValue(false, forKey: "drawsBackground")
#endif
        
#if os(iOS)
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        
        if #available(iOS 14.0, *) {
            webView.backgroundColor = UIColor(.clear)
        } else {
            webView.backgroundColor = .clear
        }
#endif
        
        self.webView = webView
        setupObservers()
    }
    
    private func setupObservers() {
        func subscriber<Value>(for keyPath: KeyPath<WKWebView, Value>) -> NSKeyValueObservation {
            return webView.observe(keyPath, options: [.prior]) { _, change in
                if change.isPrior {
                    self.objectWillChange.send()
                }
            }
        }
        // Setup observers for all KVO compliant properties
        observers = [
            subscriber(for: \.title),
            subscriber(for: \.url),
            subscriber(for: \.isLoading),
            subscriber(for: \.estimatedProgress),
            subscriber(for: \.hasOnlySecureContent),
            subscriber(for: \.serverTrust),
            subscriber(for: \.canGoBack),
            subscriber(for: \.canGoForward)
        ]
        if #available(iOS 15.0, macOS 12.0, *) {
            observers += [
                subscriber(for: \.themeColor),
                subscriber(for: \.underPageBackgroundColor),
                subscriber(for: \.microphoneCaptureState),
                subscriber(for: \.cameraCaptureState)
            ]
        }
#if swift(>=5.7)
        if #available(iOS 16.0, macOS 13.0, *) {
            observers.append(subscriber(for: \.fullscreenState))
        }
#else
        if #available(iOS 15.0, macOS 12.0, *) {
            observers.append(subscriber(for: \.fullscreenState))
        }
#endif
    }
    
    private var observers: [NSKeyValueObservation] = []
    
    public subscript<T>(dynamicMember keyPath: KeyPath<WKWebView, T>) -> T {
        webView[keyPath: keyPath]
    }
}

#if os(iOS)
/// A container for using a WKWebView in SwiftUI
public struct WebView: View, UIViewRepresentable {
    /// The WKWebView to display
    public let webView: WKWebView
    
    public init(webView: WKWebView) {
        self.webView = webView
    }
    
    public func makeUIView(context: UIViewRepresentableContext<WebView>) -> WKWebView {
        webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<WebView>) {
    }
}
#endif

#if os(macOS)
/// A container for using a WKWebView in SwiftUI
public struct WebView: View, NSViewRepresentable {
    /// The WKWebView to display
    public let webView: WKWebView
    
    public init(webView: WKWebView) {
        self.webView = webView
    }
    
    public func makeNSView(context: NSViewRepresentableContext<WebView>) -> WKWebView {
        webView
    }
    
    public func updateNSView(_ uiView: WKWebView, context: NSViewRepresentableContext<WebView>) {
    }
}
#endif
