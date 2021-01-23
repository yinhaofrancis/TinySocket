//
//  udp.swift
//  TinySocket
//
//  Created by hao yin on 2021/1/23.
//

import Foundation
import Darwin

public class UdpClient{
    public var udp:Int
    public let bufferSize = 64 * 1024
    public typealias handleData = (Data?,SocketAddress?,SocketError?)->Void
    private var socketdomain:Int
    private var queue = DispatchQueue(label: "tcp_client", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
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
            tiny_send_to(socket: self.udp, domain: self.socketdomain, ip: ip, port: port, data: p, size: data.count)
            p.deallocate()
        }
    }
    public func close(){
        _ = tiny_close(socket: self.udp)
    }
    public func listen(port:UInt16,callback:@escaping handleData) {
        self.queue.async {
            let r = tiny_tcp_bind(tcp: self.udp, domain: self.socketdomain, port: port)
            if(r != 0){
                callback(nil,nil,SocketError(code: 6, msg: String(cString: strerror(errno))))
            }
            while(true){
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.bufferSize)
                var ipbuffer:UnsafeMutablePointer<UInt8>?
                var len = 28
                let flag = tiny_recv_from(socket: self.udp, data: buffer, size: self.bufferSize, client: &ipbuffer, len: &len)
                
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
    
}
