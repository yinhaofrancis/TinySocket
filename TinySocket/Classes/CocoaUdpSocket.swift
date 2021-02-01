//
//  CocoaUdpSocket.swift
//  BackPack
//
//  Created by hao yin on 2021/1/28.
//

import Foundation
import CFNetwork

public protocol CocoaUdpDelegate:class{
    func CocoaSocket(socket:CocoaUdpSocket,error:SocketError)
    func CocoaSocket(socket:CocoaUdpSocket,recieveData:Data)
}

public class CocoaUdpSocket {
    public weak var delegate:CocoaUdpDelegate?
    private var domain:SocketDomain = .SocketIpv4
    private class Context{
        weak var socket:CocoaUdpSocket?
    }

    let bufferSize:Int = 1024 * 1024
    private var socketContext:CFSocketContext = CFSocketContext()
    private var socket:CFSocket?
    public var state:TcpClientState{
        return innerState
    }
    private var innerState:TcpClientState = .setup
    private var context:Context
    private var readSource:DispatchSourceRead?
    private var target:CFData?
    #if DEBUG
    private class debugDelegate:CocoaUdpDelegate{
        func CocoaSocket(socket: CocoaUdpSocket, error: SocketError) {
            print(error.msg)
        }
        
        func CocoaSocket(socket: CocoaUdpSocket, recieveData: Data) {
            print(String(data: recieveData, encoding: .utf8) ?? "")
        }
    }
    private var innerDelegate:debugDelegate = debugDelegate()
    #endif
    public init(domain:SocketDomain,delegate:CocoaUdpDelegate? = nil) throws{
        let context = CocoaUdpSocket.Context()
        self.context = context

        #if DEBUG
        if(delegate == nil){
            self.delegate = self.innerDelegate
        }else{
            self.delegate = delegate
        }
        #else
        self.delegate = delegate
        #endif
        context.socket = self
        var net = PF_INET
        self.domain = domain
        switch domain {
            
        case .SocketIpv4:
            net = PF_INET
        case .SocketIpv6:
            net = PF_INET6
        }
        self.socket = CFSocketCreate(kCFAllocatorDefault, net, SOCK_DGRAM, IPPROTO_UDP, CFSocketCallBackType.connectCallBack.rawValue, { (socket, t, address, data, info) in
            
            guard let wself = info?.assumingMemoryBound(to: Context.self).pointee.socket else{
                return
            }
            if let d = data{
                wself.delegate?.CocoaSocket(socket: wself, error: SocketError(code: 0, msg: String(cString: d.assumingMemoryBound(to: UInt8.self))))
            }else{
                wself.innerState = .recieve
            }
        }, &self.socketContext)
        self.createRunLoop()
    }
    deinit {
        CFSocketInvalidate(self.socket)
    }
    private func createRunLoop(){
        let f = CFSocketGetNative(self.socket!)
        
        let source = DispatchSource.makeReadSource(fileDescriptor: f, queue: DispatchQueue.global())
        self.readSource = source
        source.setEventHandler {
            var result = Data()
            var c = self.bufferSize
            let buffer:UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: c)
            while(c == self.bufferSize){
                buffer.assign(repeating: 0, count: self.bufferSize)
                c = read(f, buffer, self.bufferSize)
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
    
    public func sendTo(data:Data,ip:String,port:UInt16){
        let ip = tiny_create_addr(domain: domain, addr: ip, port: port) as CFData
        CFSocketSendData(self.socket, ip, data as CFData, -1)
    }
}
