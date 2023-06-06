import SwiftUI
import WebKit
import SwiftUI
import WebKit
import Foundation
import Combine

public struct Message: Identifiable, Equatable {
    public let id = UUID()
    var text: String
    
    public init(text: String) {
            self.text = text
        }
}
 
public struct AvatarView: View {
    
    @StateObject var webViewStore = WebViewStore()
    
    var text: Message
    var avatarId: String
        
    public init(_ text: Message,_ avatarId: String) {
        self.text = text
        self.avatarId = avatarId
    }
    
    func onCallback (eventName: String, value: String) {
        print("Got ", eventName, value)
        
        if (eventName == "clientReady") {
            sendEvent(eventName: "avatarIdChange", value: avatarId)
        }
    }
    
    public var body: some View {
        WebView(webView: webViewStore.webView)
        .onChange(of: text) { value in
            sendEvent(eventName: "textChange", value: value.text)
                    }
        .onChange(of: avatarId) { value in
            sendEvent(eventName: "avatarIdChange", value: value)
                    }
        .onAppear {
            self.webViewStore.messageHandler = MessageHandler(callbackAction: onCallback)
            self.webViewStore.webView.load(URLRequest(url: URL(string: "http://embed.api.avatech.ai/")!))
        }
    }
        
    
    public func sendEvent(eventName: String, value: String) {
//        print(eventName)
        self.webViewStore.webView.evaluateJavaScript(
            """
            window.sendHandleAvatarEvent('\(eventName)', '\(value)');
            """
        )
    }
}

public class MessageHandler: NSObject, WKScriptMessageHandler {
    
    var callbackAction: (String,String) -> ()
    
    public init (callbackAction: @escaping (String, String) -> ()) {
        self.callbackAction = callbackAction
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String : AnyObject] else {
            return
        }
        
        callbackAction(
            dict["eventName"] as! String,
            dict["value"] as! String
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
      if #available(iOS 10.0, *) {
          configuration.mediaTypesRequiringUserActionForPlayback = []
      } else {
          configuration.requiresUserActionForMediaPlayback = false
      }
      configuration.preferences = preferences
      
      let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
      webView.scrollView.isScrollEnabled = true
      webView.isOpaque = false
      if #available(iOS 14.0, *) {
          webView.backgroundColor = UIColor(.clear)
      } else {
          webView.backgroundColor = .clear
      }

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
