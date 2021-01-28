//
//  socketUtil.c
//  TinySocket
//
//  Created by hao yin on 2021/1/22.
//

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <dirent.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/select.h>
#include <sys/ioctl.h>
#include <ifaddrs.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#define MAXBUFF 4 * 1024

int tiny_tcp(int domain){
    return socket(domain, SOCK_STREAM, IPPROTO_TCP);
}

int tiny_udp(int domain){
    return socket(domain, SOCK_DGRAM, IPPROTO_UDP);
}

int tiny_host_net_family(int family){
    struct ifaddrs * info;
    getifaddrs(&info);
    while (info != NULL) {
        if (info->ifa_addr->sa_family == family){
            return 1;
        }
    }
    return 0;
}
void tiny_send_timeout(int tcp,int seconds){
    setsockopt(tcp,SOL_SOCKET, SO_SNDTIMEO, &seconds, sizeof(int));
}
void tiny_connect_timeout(int tcp,int seconds){
    setsockopt(tcp,SOL_SOCKET, TCP_CONNECTIONTIMEOUT, &seconds, sizeof(int));
}
void tiny_recv_timeout(int tcp,int seconds){
    setsockopt(tcp,SOL_SOCKET, SO_RCVTIMEO, &seconds, sizeof(int));
}
int tiny_tcp_connect(int tcp,int domain,const char *ip,unsigned short port) {
    
    if (domain == AF_INET6){
        struct sockaddr_in6 ips;
        inet_pton(domain, ip, &ips.sin6_addr);
        ips.sin6_port = htons(port);
        ips.sin6_family = AF_INET6;
        return connect(tcp, (struct sockaddr *)&ips, sizeof(ips));
    }else{
        struct sockaddr_in ips;
        inet_pton(domain, ip, &ips.sin_addr);
        ips.sin_port = htons(port);
        ips.sin_family = AF_INET;
        return connect(tcp, (struct sockaddr *)&ips, sizeof(ips));
        
    }
}

size_t tiny_send(int socket,const void * data,size_t size){
    return send(socket, data, size, 0);
}

size_t tiny_send_string(int socket,const char * str){
    return send(socket, str, strlen(str), 0);
}
size_t tiny_recv(int socket,void *data,size_t size){
    
    return recv(socket, data, size, 0);
}

size_t tiny_recv_from(int socket,void *data,size_t size,const void **client,unsigned int * len){
    void * result = malloc(28);
    uint vlen = 28;
    size_t rsize = recvfrom(socket, data, size, 0, result, &vlen);
    
    *client = result;
    
    
    return rsize;
}
size_t tiny_recv_string(int socket,char *str,size_t size){
    
    return recv(socket, str, size, 0);
}

int tiny_close(int socket){
    return close(socket);
}


size_t tiny_send_to(int socket,
                 int domain,
                 const char *ip,
                 unsigned short port,
                 const void * data,
                 size_t size){
    
    if (domain == AF_INET6) {
        struct sockaddr_in6 ipadd;
        bzero(&ipadd, sizeof(ipadd));
        int i = inet_pton(AF_INET6, ip, &ipadd.sin6_addr);
        if(i == 1){
            ipadd.sin6_port = htons(port);
            ipadd.sin6_family = AF_INET6;
            return sendto(socket,data,size, 0, (struct sockaddr *)&ipadd, sizeof(ipadd));
        }
        return 0;
    }else{
        struct sockaddr_in ipadd;
        bzero(&ipadd, sizeof(ipadd));
        int i = inet_pton(AF_INET, ip, &ipadd.sin_addr);
        if(i == 1){
            ipadd.sin_port = htons(port);
            ipadd.sin_family = AF_INET;
            return sendto(socket,data,size, 0, (struct sockaddr *)&ipadd, sizeof(ipadd));
        }
        return  0;
    }
}
size_t tiny_send_string_to(int socket,
                           int domain,
                           const char *ip,
                           unsigned short port,
                           const char * data){
    size_t len = strlen(data);
    return tiny_send_to(socket, domain, ip, port, data, len);
}
int tiny_tcp_accept(int tcp,const void **client,unsigned int * len){
    struct sockaddr * sock = malloc(28);
    *len = 28;
    int socket = accept(tcp, sock, len);
    *client = sock;
    return socket;
}
int tiny_tcp_listen(int tcp,int count) {
    return listen(tcp, count);
}
int tiny_tcp_bind(int tcp,int domain,short port){
    
    if(domain == AF_INET6){
        struct sockaddr_in6 sock;
        bzero(&sock.sin6_addr, sizeof(sock.sin6_addr));
        sock.sin6_family = domain;
        sock.sin6_port = htons(port);
        return bind(tcp, (struct sockaddr *)&sock, sizeof(sock));
    }else{
        struct sockaddr_in sock;
        bzero(&sock.sin_addr, sizeof(sock.sin_addr));
        sock.sin_family = domain;
        sock.sin_port = htons(port);
        return bind(tcp, (struct sockaddr *)&sock, sizeof(sock));
    }
}

int tiny_addr_famaly(const void* addr){
    struct sockaddr * a = (struct sockaddr *)addr;
    return a->sa_family;
}
ushort tiny_addr_port(const void* addr,size_t size){
    if(tiny_addr_famaly(addr) == AF_INET6){
        struct sockaddr_in6 * s = (struct sockaddr_in6 *)addr;
        return ntohs(s->sin6_port);
    }else{
        struct sockaddr_in * s = (struct sockaddr_in *)addr;
        return ntohs(s->sin_port);
    }
}
const char * tiny_addr_ip(const void* addr,size_t size){
    if(tiny_addr_famaly(addr) == AF_INET6){
        struct sockaddr_in6 * s = (struct sockaddr_in6 *)addr;
        char *str = malloc(28);
        bzero(str, 28);
        inet_ntop(AF_INET6, &s->sin6_addr, str, 28);
        return str;
    }else{
        struct sockaddr_in * s = (struct sockaddr_in *)addr;
        char *str = malloc(16);
        bzero(str, 16);
        inet_ntop(AF_INET, &s->sin_addr, str, 16);
        return str;
    }
}

const void *tiny_addr_create(int domain,const char* addr,ushort port){
    if(domain == AF_INET6){
        struct sockaddr_in6 *ip = (struct sockaddr_in6 *)malloc(sizeof(struct sockaddr_in6));
        inet_pton(domain, addr, &ip->sin6_addr);
        ip->sin6_port = htons(port);
        ip->sin6_family = AF_INET6;
        return ip;
    }else{
        struct sockaddr_in *ip = (struct sockaddr_in *)malloc(sizeof(struct sockaddr_in));
        inet_pton(domain, addr, &ip->sin_addr);
        ip->sin_port = htons(port);
        ip->sin_family = AF_INET;
        return ip;
    }
}
