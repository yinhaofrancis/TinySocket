//
//  TinyWebView.swift
//  BackPack
//
//  Created by hao yin on 2021/2/3.
//

import UIKit
import WebKit

public class TinyFunction:NSObject,WKScriptMessageHandler,WKScriptMessageHandlerWithReply{
    
    @available(iOS 14.0, *)
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        self.handleCallBackReply?(userContentController,message,replyHandler)
    }
    
    public init(name:String,call:@escaping HandleCallBackReply) {
        self.name = name
        self.handleCallBackReply = call
    }
    
    public init(name:String,call:@escaping HandleCallBack) {
        self.name = name
        self.handleCallBack = call
    }
    
    public typealias HandleCallBackReply = (WKUserContentController,WKScriptMessage,Reply?)->Void
    
    public typealias HandleCallBack = (WKUserContentController,WKScriptMessage)->Void
    
    public typealias Reply = (Any?, String?) -> Void

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        self.handleCallBack?(userContentController,message)
    }
    
    public var handleCallBackReply:HandleCallBackReply?
    
    public var handleCallBack:HandleCallBack?
    
    public var name:String
    
}


public class TinyWebView:UIView{
    public var wkWebView:WKWebView
    public var maskV:UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.alpha = 0;
        return v
    }()
    public var blur:UIVisualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    public var indicate:UIActivityIndicatorView = UIActivityIndicatorView(style: .whiteLarge)
    public var functions:[String:TinyFunction] = [:]
    
    public init(configuration: WKWebViewConfiguration) {
        self.wkWebView = WKWebView(frame: UIScreen.main.bounds, configuration: configuration)
        super.init(frame: UIScreen.main.bounds)
        self.addSubview(self.wkWebView)
        self.coverView(view: self.wkWebView)
        
        self.blur.contentView.addSubview(self.indicate)
        self.centerView(view: self.indicate,container: self.blur.contentView)
        self.addSubview(maskV)
        self.blur.frame = self.bounds
        self.blur.autoresizingMask = [.flexibleHeight,.flexibleHeight]
        self.addSubview(self.blur)
        self.loadingAction()
        
    }
    
    required init?(coder: NSCoder) {
        self.wkWebView = WKWebView(frame: UIScreen.main.bounds, configuration: WKWebViewConfiguration())
        super.init(coder: coder)
        self.addSubview(self.wkWebView)
        self.coverView(view: self.wkWebView)
        
        self.blur.contentView.addSubview(self.indicate)
        self.centerView(view: self.indicate,container: self.blur.contentView)
        self.addSubview(maskV)
        self.blur.frame = self.bounds
        self.blur.autoresizingMask = [.flexibleHeight,.flexibleHeight]
        self.addSubview(self.blur)
        self.loadingAction()
    }
    public func addMessageFunction(function:TinyFunction){
        if let fs = self.functions[function.name] {
            self.wkWebView.configuration.userContentController.removeScriptMessageHandler(forName: fs.name)
        }
        self.functions[function.name] = function
        if #available(iOS 14.0, *) {
            if (function.handleCallBackReply != nil){
                self.wkWebView.configuration.userContentController.addScriptMessageHandler(function, contentWorld: WKContentWorld.defaultClient, name: function.name)
            }else{
                self.wkWebView.configuration.userContentController.add(function, contentWorld: .defaultClient, name: function.name)
            }
        } else {
            self.wkWebView.configuration.userContentController.add(function, name: function.name)
        }
    }
    
    public func addScript(code:String,injectTime:WKUserScriptInjectionTime,forMainFrameOnly:Bool){
        if #available(iOS 14.0, *) {
            self.wkWebView.configuration.userContentController.addUserScript(WKUserScript(source: code, injectionTime: injectTime, forMainFrameOnly: forMainFrameOnly, in: .defaultClient))
        } else {
            self.wkWebView.configuration.userContentController.addUserScript(WKUserScript(source: code, injectionTime: injectTime, forMainFrameOnly: forMainFrameOnly))
        }
    }
    func loadingAction(){
        self.addMessageFunction(function: TinyFunction(name: "loadingStart", call: { (cc, sm) in
            self.blur.frame = self.bounds
            self.blur.isHidden = false
            self.indicate.startAnimating()
            UIView .transition(from: self.maskV, to: self.blur, duration: 0.3, options: [.curveEaseInOut,.transitionCrossDissolve]) { (_) in
            }
            
        }))
        
        self.addMessageFunction(function: TinyFunction(name: "loadingEnd", call: { (cc, sm) in
            self.blur.frame = self.bounds
            self.blur.isHidden = true
            self.indicate.stopAnimating()
            UIView .transition(from: self.blur, to: self.maskV, duration: 0.5, options: [.curveEaseInOut,.transitionCrossDissolve]) { (_) in
            }
        }))
        self.addScript(code: "window.webkit.messageHandlers.loadingStart.postMessage(null);", injectTime: .atDocumentStart, forMainFrameOnly: true)
        self.addScript(code: "window.webkit.messageHandlers.loadingEnd.postMessage(null);", injectTime: .atDocumentEnd, forMainFrameOnly: true)
    }
    func coverView(view:UIView){
        
        let a = [
            view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            view.topAnchor.constraint(equalTo: self.topAnchor),
            view.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ]
        view.translatesAutoresizingMaskIntoConstraints = false;
        self.addConstraints(a)
    }
    func centerView(view:UIView,container:UIView){
        let a = [
            view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ]
        view.translatesAutoresizingMaskIntoConstraints = false;
        container.addConstraints(a)
    }
}

public class TinyWebViewController:UIViewController {
    public var webView:TinyWebView
    @IBInspectable public var url:String?
    public required init?(coder: NSCoder) {
        self.webView = TinyWebView(configuration: WKWebViewConfiguration())
        super.init(coder: coder)
    }
    public override func loadView() {
        self.view = webView
    }
    public init(configuration:WKWebViewConfiguration){
        self.webView = TinyWebView(configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }
    public override func viewDidLoad() {
        super.viewDidLoad()
        if let u = self.url{
            self.loadUrl(url: u)
        }
        
    }
    public func loadUrl(url:String){
        self.url = url
        if let u = URL(string: url){
            self.webView.wkWebView.load(URLRequest(url: u))
        }
    }
}
