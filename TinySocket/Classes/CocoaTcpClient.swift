//
//  cocoatcp.swift
//  BackPack
//
//  Created by hao yin on 2021/1/25.
//

import Foundation
import CFNetwork


public protocol CocoaTcpClientDelegate:class{
    func CocoaSocket(socket:CocoaTcpClient,error:SocketError)
    func CocoaSocket(socket:CocoaTcpClient,recieveData:Data)
}

public class CocoaTcpClient{
    public weak var delegate:CocoaTcpClientDelegate?
    private class Context{
        weak var socket:CocoaTcpClient?
    }

    private var socketContext:CFSocketContext = CFSocketContext()
    private var socket:CFSocket?
    public var state:TcpClientState{
        return innerState
    }
    private var domain:SocketDomain = .SocketIpv4
    private var innerState:TcpClientState = .setup
    private var context:Context
    private var readSource:DispatchSourceRead?
    private var target:CFData?
    #if DEBUG
    private class debugDelegate:CocoaTcpClientDelegate{
        func CocoaSocket(socket: CocoaTcpClient, error: SocketError) {
            print(error.msg)
        }
        
        func CocoaSocket(socket: CocoaTcpClient, recieveData: Data) {
            print(String(data: recieveData, encoding: .utf8) ?? "")
        }
    }
    private var innerDelegate:debugDelegate = debugDelegate()
    #endif
    public init(domain:SocketDomain,host:Data,delegate:CocoaTcpClientDelegate? = nil) throws{
        var net = PF_INET
        self.domain = domain
        switch domain {
            
        case .SocketIpv4:
            net = PF_INET
        case .SocketIpv6:
            net = PF_INET6
        }
        let context = CocoaTcpClient.Context()
        #if DEBUG
        if(delegate == nil){
            self.delegate = self.innerDelegate
        }else{
            self.delegate = delegate
        }
        #else
        self.delegate = delegate
        #endif
       
        self.context = context
        self.socket = CFSocketCreate(kCFAllocatorDefault, net, SOCK_STREAM, IPPROTO_TCP, CFSocketCallBackType.connectCallBack.rawValue, { (socket, t, address, data, info) in
            
            guard let wself = info?.assumingMemoryBound(to: Context.self).pointee.socket else{
                return
            }
            if let d = data{
                wself.delegate?.CocoaSocket(socket: wself, error: SocketError(code: 0, msg: String(cString: d.assumingMemoryBound(to: UInt8.self))))
            }else{
                wself.innerState = .recieve
            }
        }, &self.socketContext)
        
        guard let so = self.socket else { return  }
        self.target = host as CFData
        let erro = CFSocketConnectToAddress(so,host as CFData,-1)
        context.socket = self
        switch erro{
        case .success:
            self .createRunLoop(info: &self.context)
            return
        case .error:
            
            throw SocketError(code: 0, msg: String(cString: strerror(Int32(erro.rawValue))))
        case .timeout:
            throw SocketError(code: 0, msg: "time out")
        @unknown default:
            throw SocketError(code: 0, msg: "unknowed")
        }
        
    }
    public  convenience init(domain:SocketDomain,server:String,port:UInt16,delegate:CocoaTcpClientDelegate? = nil) throws{
        let data = tiny_create_addr(domain: domain, addr: server, port: port)
        try self.init(domain: domain, host: data, delegate: delegate)
    }
    
    deinit {
        CFSocketInvalidate(self.socket)
    }
    private func createRunLoop(info:UnsafeMutableRawPointer?){
        let f = CFSocketGetNative(self.socket!)
        
        let source = DispatchSource.makeReadSource(fileDescriptor: f, queue: DispatchQueue.global())
        self.readSource = source
        source.setEventHandler {
            var result = Data()
            var c = 1024
            let buffer:UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: c)
            while(c == 1024){
                buffer.assign(repeating: 0, count: 1024)
                c = read(f, buffer, 1024)
                if (c <= 0) {
                    self.delegate?.CocoaSocket(socket: self, error: SocketError(code: 0, msg: String(cString: strerror(errno))))
                    source.cancel()
                    return
                }
                let data = Data(bytes: buffer, count: c)
                result.append(data)
            }
            buffer.deallocate()
            self.delegate?.CocoaSocket(socket: self, recieveData: result)
        }
        if #available(iOS 10.0, *) {
            source.activate()
        } else {
            source.resume()
        }
    }
    public func sendData(data:Data) throws{
        if let tar = self.target{
            let r = CFSocketSendData(self.socket, tar, data as CFData, -1)
            switch r {
            case .success:
                return
            case .error:
                throw SocketError(code: 0, msg: "error")
            case .timeout:
                throw SocketError(code: 0, msg: "time out")
            @unknown default:
                throw SocketError(code: 0, msg: "unknowed")
            }
        }else{
            throw SocketError(code: 0, msg: "no server info")
        }
    }
}


