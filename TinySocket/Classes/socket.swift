//
//  socket.swift
//  TinySocket
//
//  Created by hao yin on 2021/1/22.
//

import Foundation

@_silgen_name("tiny_tcp")
public func tiny_tcp(domain:Int)->Int

@_silgen_name("tiny_udp")
public func tiny_udp(domain:Int)->Int

@_silgen_name("tiny_host_net_family")
public func tiny_host_net_family(family:Int)->Int

@_silgen_name("tiny_tcp_connect")
public func tiny_tcp_connect(tcp:Int,domain:Int,ip:UnsafePointer<UInt8>,port:UInt16)->Int

@_silgen_name("tiny_send")
public func tiny_send(socket:Int,data:UnsafePointer<UInt8>,size:Int)->Int

@_silgen_name("tiny_send_string_to")
public func tiny_send_string_to(socket:Int,
                                domain:Int,
                                ip:UnsafePointer<UInt8>,
                                port:UInt16,
                                char:UnsafePointer<UInt8>)

@_silgen_name("tiny_send_to")
public func tiny_send_to(socket:Int,
                        domain:Int,
                        ip:UnsafePointer<UInt8>,
                        port:UInt16,
                        data:UnsafePointer<UInt8>,
                        size:Int)->Int

@_silgen_name("tiny_recv")
public func tiny_recv(socket:Int,data:UnsafePointer<UInt8>,size:Int)->Int

@_silgen_name("tiny_recv_from")
public func tiny_recv_from(socket:Int,
                           data:UnsafePointer<UInt8>,
                           size:Int,
                           client:UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
                           len:UnsafeMutablePointer<Int>)->Int

@_silgen_name("tiny_send_string")
public func tiny_send_string(socket:Int,data:UnsafePointer<UInt8>)->Int

@_silgen_name("tiny_close")
public func tiny_close(socket:Int)->Int

@_silgen_name("tiny_tcp_accept")
public func tiny_tcp_accept(tcp:Int,
                            client:UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
                            len:UnsafeMutablePointer<UInt>)->Int

@_silgen_name("tiny_tcp_listen")
public func tiny_tcp_listen(tcp:Int,count:Int)->Int

@_silgen_name("tiny_tcp_bind")
public func tiny_tcp_bind(tcp:Int,domain:Int,port:UInt16)->Int

@_silgen_name("tiny_addr_famaly")
public func tiny_addr_famaly(addr:UnsafePointer<UInt8>)->Int

@_silgen_name("tiny_addr_port")
public func tiny_addr_port(addr:UnsafePointer<UInt8>,size:size_t)->UInt16


@_silgen_name("tiny_addr_ip")
public func tiny_addr_ip(addr:UnsafePointer<UInt8>,size:Int)->UnsafePointer<UInt8>

@_silgen_name("tiny_addr_create")
public func tiny_addr_create(domain:Int ,addr:UnsafePointer<UInt8>,port:ushort)->UnsafePointer<UInt8>


@_silgen_name("tiny_send_timeout")
public func tiny_send_timeout(tcp:Int,seconds:Int)

@_silgen_name("tiny_connect_timeout")
public func tiny_connect_timeout(tcp:Int,seconds:Int)

@_silgen_name("tiny_recv_timeout")
public func tiny_recv_timeout(tcp:Int,seconds:Int)


public enum SocketDomain{
    case SocketIpv4
    case SocketIpv6
}

public struct SocketError:Error{
    public var code:Int
    public var msg:String
    public init(code:Int,msg:String){
        self.code = code
        self.msg = msg
    }
}
public struct SocketHost{
    public var name:String
    public var aliases:[String]
    public var length:Int
    public var addrType:SocketDomain
    public var ipStrAddr:[String]
    public var ipAddr:[Data]
}

public struct SocketAddress{
    public var origin:Data
    public var domain:SocketDomain?{
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: origin.count)
        self.origin.copyBytes(to: ptr, count: origin.count)
        let s = tiny_addr_famaly(addr: ptr)
        if(s == AF_INET){
            ptr.deallocate()
            return .SocketIpv4
        }else if(s == AF_INET6){
            ptr.deallocate()
            return .SocketIpv6
        }else{
            ptr.deallocate()
            return nil
        }
    }
    public var port:UInt16{
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: origin.count)
        self.origin.copyBytes(to: ptr, count: origin.count)
        
        let port = tiny_addr_port(addr: ptr, size: self.origin.count)
        ptr.deallocate()
        return port
    }
    public var ip:String {
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: origin.count)
        self.origin.copyBytes(to: ptr, count: origin.count)
        let p = tiny_addr_ip(addr: ptr, size: self.origin.count);
        ptr.deallocate()
        let str = String(cString: p)
        p.deallocate()
        return str
    }
    public init(origin:Data) {
        self.origin = origin
    }
    public init(domain:SocketDomain,ip:String,port:UInt16){
        switch domain {
        case .SocketIpv4:
            let p = tiny_addr_create(domain: Int(AF_INET), addr: ip, port: port)
            let data = Data(bytes: p, count: MemoryLayout<sockaddr_in>.size)
            self.origin = data
            p.deallocate()
        case .SocketIpv6:
            let p = tiny_addr_create(domain: Int(AF_INET6), addr: ip, port: port)
            let data = Data(bytes: p, count: MemoryLayout<sockaddr_in6>.size)
            self.origin = data
            p.deallocate()
            break
        }
    }
}

public func tiny_host(name:String)->SocketHost?{
    guard let end = gethostbyname(name) else { return nil }
    var ptr = end.pointee.h_aliases
    var alias:[String] = []
    while ptr?.pointee != nil {
        alias.append(String(cString: ptr!.pointee!))
        ptr = ptr?.advanced(by: 1)
    }
    
    
    ptr = end.pointee.h_addr_list
    var address:[String] = []
    var addrData:[Data] = []
    let p = UnsafeMutablePointer<Int8>.allocate(capacity: 32)
    while ptr?.pointee != nil {
        inet_ntop(end.pointee.h_addrtype, ptr!.pointee!, p, 32)
        address.append(String(cString: p))
        let data = Data(bytes: ptr!.pointee!, count: Int(end.pointee.h_length))
        addrData.append(data)
        ptr = ptr?.advanced(by: 1)
        bzero(p, 32)
    }
    freehostent(end)
    p.deallocate()
    return SocketHost(name: String(cString: end.pointee.h_name), aliases: alias, length: Int(end.pointee.h_length), addrType: end.pointee.h_addrtype == AF_INET6 ? .SocketIpv6 : .SocketIpv4, ipStrAddr: address, ipAddr: addrData)
}
public func tiny_host()->SocketHost?{
    guard let end = gethostent() else { return nil }
    var ptr = end.pointee.h_aliases
    var alias:[String] = []
    while ptr?.pointee != nil {
        alias.append(String(cString: ptr!.pointee!))
        ptr = ptr?.advanced(by: 1)
    }
    
    
    ptr = end.pointee.h_addr_list
    var address:[String] = []
    var addrData:[Data] = []
    let p = UnsafeMutablePointer<Int8>.allocate(capacity: 32)
    while ptr?.pointee != nil {
        inet_ntop(end.pointee.h_addrtype, ptr!.pointee!, p, 32)
        address.append(String(cString: p))
        let data = Data(bytes: ptr!.pointee!, count: Int(end.pointee.h_length))
        addrData.append(data)
        ptr = ptr?.advanced(by: 1)
        bzero(p, 32)
    }
    freehostent(end)
    p.deallocate()
    return SocketHost(name: String(cString: end.pointee.h_name), aliases: alias, length: Int(end.pointee.h_length), addrType: end.pointee.h_addrtype == AF_INET6 ? .SocketIpv6 : .SocketIpv4, ipStrAddr: address, ipAddr: addrData)
}

public func tiny_pton(ip:String,socket:SocketDomain)->Data {
    switch socket {
    case .SocketIpv4:
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: MemoryLayout<in_addr>.size)
        inet_pton(AF_INET , ip, p)
        let data = Data(bytes: p, count: MemoryLayout<in_addr>.size)
        p.deallocate()
        return data
    case .SocketIpv6:
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: MemoryLayout<in6_addr>.size)
        inet_pton(AF_INET6 , ip, p)
        let data = Data(bytes: p, count: MemoryLayout<in6_addr>.size)
        p.deallocate()
        return data
    }
}
public func tiny_ntop(data:Data,socket:SocketDomain)->String {
    let p = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
    data.copyBytes(to: p, count: data.count)
    let r = UnsafeMutablePointer<Int8>.allocate(capacity: 32)
    switch socket {
    case .SocketIpv4:
        inet_ntop(AF_INET, p, r, 32)
        let str = String(cString: r)
        p.deallocate()
        r.deallocate()
        return str
    case .SocketIpv6:
        inet_ntop(AF_INET, p, r, 32)
        let str = String(cString: r)
        p.deallocate()
        r.deallocate()
        return str
    }
}
public func tiny_create_addr(domain:SocketDomain,addr:String,port:UInt16)->Data{
    switch domain {
    case .SocketIpv4:
        let addr = tiny_addr_create(domain: Int(AF_INET), addr: addr, port: port)
        let data = Data(bytes: addr, count: MemoryLayout<sockaddr_in>.size)
        addr.deallocate()
        return data
    case .SocketIpv6:
        let addr = tiny_addr_create(domain: Int(AF_INET6), addr: addr, port: port)
        let data = Data(bytes: addr, count: MemoryLayout<sockaddr_in6>.size)
        addr.deallocate()
        return data
    }
}

public typealias SocketSendCallBack = (SocketError?)->Void
