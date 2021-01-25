import Foundation
import Darwin

public enum TcpClientState{
    case setup
    case prepare
    case recieve
    case close
}

public class TcpClient{
    public typealias handleData = (Data?,SocketError?)->Void
    public var socket:Int = 0
    public let domain:SocketDomain
    public let buffsize:Int = 4 * 1024
    private var socketDomain:Int32 = AF_INET
    public var state:TcpClientState{
        return self.tcpState
    }
    private var tcpState:TcpClientState = .setup
    private var queue = DispatchQueue(label: "tcp_client", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    public init(domain:SocketDomain) {
        self.domain = domain
        
        switch domain {
        case .SocketIpv4:
            self.socketDomain = AF_INET
            self.socket = tiny_tcp(domain: Int(AF_INET))
            break
        case .SocketIpv6:
            self.socketDomain = AF_INET6
            self.socket = tiny_tcp(domain: Int(AF_INET6))
            break
        }
    }
    public func connect(ip:String,port:UInt16,callback:@escaping handleData){
        self.queue.async {
            let r = tiny_tcp_connect(tcp: self.socket, domain: Int(self.socketDomain), ip: ip, port: port)
            if r != 0{
                if let e = strerror(errno){
                    callback(nil,SocketError(code: 2, msg: String(cString: e)))
                }else{
                    callback(nil,SocketError(code: 2, msg: "unknowed error"))
                }
                return
            }
            var result = 1;
            let p = UnsafeMutablePointer<UInt8>.allocate(capacity: self.buffsize)
            while result > 0 {
                var hasBuffer:Bool = true
                var data:Data = Data()
                while hasBuffer {
                    self.tcpState = .prepare
                    result = tiny_recv(socket: self.socket, data: p, size: self.buffsize)
                    self.tcpState = .recieve
                    if(result == self.buffsize){
                        hasBuffer = true
                    }else{
                        hasBuffer = false
                    }
                    if(result > 0){
                        data.append(Data(bytes: p, count: result))
                    }
                }
                hasBuffer = true
                if(result > 0){
                    callback(data,nil)
                }
            }
            p.deallocate()
            self.close()
        }
    }
    public func send(data:Data){
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        data.copyBytes(to: p, count: data.count)
        _ = tiny_send(socket: self.socket, data: p, size: data.count)
    }
    public func close() {
        _ = tiny_close(socket: self.socket)
        self.tcpState = .close
    }
}

public class TcpServer {
    public class LinkClient{
        public var socket:Int
        public var address:SocketAddress
        public var state:TcpClientState
        public init(socket:Int,address:SocketAddress,state:TcpClientState){
            self.socket = socket
            self.address = address
            self.state = state
        }
    }
    public enum TcpServerState{
        case setup
        case accepting
        case listening
        case close
    }
    private var tcpState:TcpServerState = .setup
    public typealias handleData = (Data?,LinkClient?,SocketError?)->Void
    public var links:[LinkClient] = []
    public var boujonr:Int
    private var domain:Int
    public let buffsize:Int = 4 * 1024
    public var sockDomain:SocketDomain
    private var queue = DispatchQueue(label: "tcp_server", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    public init (domain:SocketDomain){
        switch domain {
        case .SocketIpv4:
            self.sockDomain = domain
            self.domain = Int(AF_INET);
            self.boujonr = tiny_tcp(domain: Int(AF_INET))
            break
        case .SocketIpv6:
            self.sockDomain = domain
            self.domain = Int(AF_INET6);
            self.boujonr = tiny_tcp(domain: Int(AF_INET6))
            break
        }
    }
    public func close(){
        _ = tiny_close(socket: self.boujonr)
    }
    public func listen(port:UInt16,count:Int,callback:@escaping handleData) {
        
        self.queue.async {
            var r = tiny_tcp_bind(tcp: self.boujonr, domain: self.domain, port: port)
            if(r != 0){
                self.close()
                if let e = strerror(errno){
                    callback(nil,nil,SocketError(code: 4, msg: String(cString: e)))
                }else{
                    callback(nil,nil,SocketError(code: 4, msg: "unknowed error"))
                }
                return
            }
            
            r = tiny_tcp_listen(tcp: self.boujonr, count: count)
            if(r != 0){
                self.close()
                if let e = strerror(errno){
                    callback(nil,nil,SocketError(code: 4, msg: String(cString: e)))
                }else{
                    callback(nil,nil,SocketError(code: 4, msg: "unknowed error"))
                }
                return
            }
            while(true){
                var pointer:UnsafeMutablePointer<UInt8>?
                var len:UInt = 0
                self.tcpState = .listening
                let socket = tiny_tcp_accept(tcp: self.boujonr, client: &pointer, len: &len)
                self.tcpState = .accepting
                if socket > 0{
                    let lc = LinkClient(socket: socket,
                                        address: SocketAddress(origin: Data(bytes: pointer!, count: Int(len))), state: .setup)
                    pointer?.deallocate()
                    self.revc(socket: lc, callback: callback)
                    self.links.append(lc)
                }else{
                    if let e = strerror(errno){
                        callback(nil,nil,SocketError(code: 3, msg: String(cString: e)))
                    }else{
                        callback(nil,nil,SocketError(code: 3, msg: "unknowed error"))
                    }
                    
                }
                
            }
        }
    }
    private func revc(socket:LinkClient,callback:@escaping handleData){
        self.queue.async {
            var result = 1;
            let p = UnsafeMutablePointer<UInt8>.allocate(capacity: self.buffsize)
            while result > 0 {
                var hasBuffer:Bool = true
                var data:Data = Data()
                while hasBuffer {
                    socket.state = .prepare
                    result = tiny_recv(socket: socket.socket, data: p, size: self.buffsize)
                    socket.state = .recieve
                    if(result == self.buffsize){
                        hasBuffer = true
                    }else{
                        hasBuffer = false
                    }
                    if(result > 0){
                        data.append(Data(bytes: p, count: result))
                    }
                }
                hasBuffer = true
                if(result > 0){
                    callback(data,socket,nil)
                }else if result == 0{
                    socket.state = .close
                    for i in 0 ..< self.links.count{
                        if self.links[i].socket == socket.socket{
                            self.links.remove(at: i)
                        }
                    }
                }
            }
            p.deallocate()
        }
    }
}
