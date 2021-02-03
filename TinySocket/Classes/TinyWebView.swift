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
    public var functions:[String:TinyFunction] = [:]
    public init(configuration: WKWebViewConfiguration) {
        self.wkWebView = WKWebView(frame: UIScreen.main.bounds, configuration: configuration)
        super.init(frame: UIScreen.main.bounds)
        self.addSubview(self.wkWebView)
        let a = [
            self.wkWebView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.wkWebView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.wkWebView.topAnchor.constraint(equalTo: self.topAnchor),
            self.wkWebView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ]
        self.wkWebView.translatesAutoresizingMaskIntoConstraints = false;
        self.addConstraints(a)
        
    }
    
    required init?(coder: NSCoder) {
        self.wkWebView = WKWebView(frame: UIScreen.main.bounds, configuration: WKWebViewConfiguration())
        super.init(coder: coder)
        self.addSubview(self.wkWebView)
        let a = [
            self.wkWebView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.wkWebView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.wkWebView.topAnchor.constraint(equalTo: self.topAnchor),
            self.wkWebView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ]
        self.wkWebView.translatesAutoresizingMaskIntoConstraints = false;
        self.addConstraints(a)
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
}
