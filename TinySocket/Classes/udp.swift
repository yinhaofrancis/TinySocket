//
//  udp.swift
//  TinySocket
//
//  Created by hao yin on 2021/1/23.
//

import Foundation
import Darwin
public enum UdpState{
    case setup
    case prepare
    case recieve
    case close
}
public class UdpClient{
    public var udp:Int
    public let bufferSize = 64 * 1024
    public typealias handleData = (Data?,SocketAddress?,SocketError?)->Void
    public typealias handleServerData = (Data?,SocketError?)->Void
    private var socketdomain:Int
    private var queue = DispatchQueue(label: "udp_client", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)

    private var source:DispatchSourceRead?
    public var state:UdpState{
        return udpState
    }
    private var udpState:UdpState = .setup
    public init(domain:SocketDomain) {
        switch domain {
        case .SocketIpv4:
            socketdomain = Int(AF_INET)
        case .SocketIpv6:
            socketdomain = Int(AF_INET6)
        }
        self.udp = tiny_udp(domain: self.socketdomain)
    }
    public func sendTo(data:Data,ip:String,port:UInt16){
        self.queue.async {
            let p = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            data.copyBytes(to: p, count: data.count)
            let a = tiny_send_to(socket: self.udp, domain: self.socketdomain, ip: ip, port: port, data: p, size: data.count)
            if a <= 0{
                print(String(cString:strerror(errno)))
            }
            p.deallocate()
        }
    }
    public func close(){
        self.udpState = .close
        _ = tiny_close(socket: self.udp)
    }
    public func listenServer(callback:@escaping handleServerData){
        self.source = DispatchSource.makeReadSource(fileDescriptor: Int32(self.udp), queue: self.queue)
        self.source?.setEventHandler(handler: {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.bufferSize)
            let c = read(Int32(self.udp), buffer, self.bufferSize)
            if c > 0{
                callback(Data(bytes: buffer, count: c), nil)
            }else{
                callback(nil,SocketError(code: 0, msg: String(cString: strerror(errno))))
            }
        })
        if #available(iOS 10.0, *) {
            self.source?.activate()
        } else {
            self.source?.resume()
        }
    }
    public func listen(port:UInt16,callback:@escaping handleData) {
        self.queue.async {
            var a:UInt32 = 1;
            var r = setsockopt(Int32(self.udp), SOL_SOCKET, SO_REUSEADDR, &a, 4)
            if(r != 0){
                callback(nil,nil,SocketError(code: 6, msg: String(cString: strerror(errno))))
            }
            r = Int32(tiny_tcp_bind(tcp: self.udp, domain: self.socketdomain, port: port))
            if(r != 0){
                callback(nil,nil,SocketError(code: 6, msg: String(cString: strerror(errno))))
            }
            
            while(true){
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.bufferSize)
                var ipbuffer:UnsafeMutablePointer<UInt8>?
                var len = 28
                self.udpState = .prepare
                let flag = tiny_recv_from(socket: self.udp, data: buffer, size: self.bufferSize, client: &ipbuffer, len: &len)
                self.udpState = .recieve
                guard flag > 0 else{
                    buffer.deallocate()
                    return
                }
                guard let ip = ipbuffer else {
                    buffer.deallocate()
                    return
                }
                let addr = SocketAddress(origin: Data(bytes: ip, count: len))
                ip.deallocate()
                let data = Data(bytes: buffer, count: flag)
                callback(data,addr,nil)
            }
        }
    }
    deinit {
        if let so = self.source{
            if so.isCancelled == false{
                so.cancel()
            }
        }
    }
}
