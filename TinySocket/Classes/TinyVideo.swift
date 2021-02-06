//
//  TinyVideo.swift
//  TinySocket
//
//  Created by hao yin on 2021/2/4.
//

import Foundation
import UIKit
import AVFoundation
public protocol TinyVideoProcessOutput:class {
    func outputVideo(callback:@escaping (Int) -> (CMSampleBuffer?,CVPixelBuffer?,CMTime?)?)
    func outputAudio(callback:@escaping (Int)->CMSampleBuffer?)
    var session:TinyVideoSession? { get set}
    func start(videoInputCount:Int,audioCount:Int,handleEnd:@escaping (AVAssetWriter.Status)->Void)
    func setSourceSize(size:CGSize)
    func end()
}
public protocol TinyVideoProcessInput {
    var videoTracks:[AVAssetReaderTrackOutput] { get }
    var audioTracks:[AVAssetReaderTrackOutput] { get }
    var session:TinyVideoSession? { get set}
    func start()
    func end()
    var status:AVAssetReader.Status { get }
}

public protocol TinyVideoProcess{
    func run(buffer:CMSampleBuffer)->(CVPixelBuffer,CMTime)?
    var outputSize:CGSize { get }
    func setSourceSize(size: CGSize)
}

extension TinyVideoProcess {
    func getSamplePixel(buffer:CMSampleBuffer)->CVPixelBuffer?{
        return CMSampleBufferGetImageBuffer(buffer)
    }
    func getPresentationTimeStamp(buffer:CMSampleBuffer)->CMTime{
        return CMSampleBufferGetPresentationTimeStamp(buffer)
    }
    
}



public protocol TinyFilter{
    func filter(image:CIImage)->CGImage?
    var cicontext:CIContext { get }
    var screenSize:CGSize? {get set}
}
extension TinyFilter{
    public func imageTransform(img:CIImage,gravity:CALayerContentsGravity,originRect:CGRect,target:CGSize)->CIImage{
        let rect = originRect
        let pxw = target.width * UIScreen.main.scale
        let pxh = target.height * UIScreen.main.scale
        
        let wratio = pxw / rect.width
        let hratio = pxh / rect.height
        if gravity == .resizeAspectFill{
            
            let dw = pxw - rect.width * max(wratio, hratio)
            let dh = pxh - rect.height * max(wratio, hratio)
            return img.transformed(by: CGAffineTransform(translationX: dw / 2, y: dh / 2).scaledBy(x: max(wratio, hratio), y: max(wratio, hratio)))
        }else{
            let dw = pxw - rect.width * min(wratio, hratio)
            let dh = pxh - rect.height * min(wratio, hratio)
            return img.transformed(by: CGAffineTransform(translationX: dw / 2, y: dh / 2).scaledBy(x: min(wratio, hratio), y: min(wratio, hratio)))
        }
    }
}

public class ChromeFilter:TinyFilter{
    public var screenSize: CGSize?
    
    public var cicontext: CIContext
    public var saveCache:Bool = false
    public var cacheImage:CGImage?
    var filter:CIFilter
    let exposure:CIFilter
    
    lazy var cgctx:TinyDrawContext? = {
        guard let rect = self.screenSize else { return nil }
        let context = TinyDrawContext(width: Int(rect.width), height: Int(rect.height), bytesPerRow: Int(rect.width * 4), buffer: nil)
        return context
    }()
    public init(){
        self.cicontext = CIContext()
        self.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius":8])!
        self.exposure = CIFilter(name: "CIExposureAdjust", parameters: ["inputEV":-5])!
    }
    public func backProcess(img:CIImage)->CGImage?{
        self.filter.setValue(img, forKey: "inputImage")
        self.exposure.setValue(self.filter.outputImage, forKey: "inputImage")
        if let out = self.exposure.outputImage{
            
            return self.cicontext.createCGImage(out, from:img.extent)
        }
        return nil
    }
    public func filter(image: CIImage) -> CGImage? {
        return autoreleasepool { () -> CGImage? in
            if let ctx = self.cgctx {
                if let ci = self.cacheImage{
                    ctx.draw(image: ci, mode: .resizeFill)
                }else{
                    if let bac = self.backProcess(img:image){
                        ctx.draw(image: bac, mode: .resizeFill)
                        if self.saveCache {
                            self.cacheImage = bac
                        }
                    }
                }
                guard let ciimg = self.cicontext.createCGImage(image, from: image.extent) else { return nil }
                ctx.draw(image: ciimg, mode: .resizeFit)
                if #available(iOS 10.0, *) {
                    self.cicontext.clearCaches()
                } else {

                }
                return self.cgctx?.render()
            }else{
                return self.cicontext.createCGImage(image, from: image.extent)
            }
        }
        
    }
    
}




public class TinyDrawContext{
    
    public enum TinyDrawContextContentMode{
        case resize
        case resizeFit
        case resizeFill
    }
    
    
    public var context:CGContext
    
    
    public init?(width:Int,height:Int,bytesPerRow:Int,buffer:UnsafeMutableRawPointer?){
        let temp = CGContext(data: buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        guard let c = temp else { return nil }
        self.context = c;
    }
    public convenience init?(pixel:CVPixelBuffer){
        self.init(width: CVPixelBufferGetWidth(pixel),
                  height: CVPixelBufferGetHeight(pixel),
                  bytesPerRow: CVPixelBufferGetBytesPerRow(pixel),
                  buffer: CVPixelBufferGetBaseAddress(pixel))
    }
    public func draw(callback:@escaping (TinyDrawContext)->Void)->TinyDrawContext{
        DispatchQueue.global().async {
            callback(self)
        }
        return self
    }
    public func draw(image:CGImage,mode:TinyDrawContextContentMode){
        let wRatio:CGFloat = CGFloat(self.context.width) / CGFloat(image.width)
        let hRatio:CGFloat = CGFloat(self.context.height) / CGFloat(image.height)
        switch mode {
        case .resize:
            self.context.draw(image, in: CGRect(x: 0, y: 0, width: self.context.width, height: self.context.height))
            break
        case .resizeFit:
            let dw = CGFloat(self.context.width) - CGFloat(image.width) * min(wRatio, hRatio)
            let dh = CGFloat(self.context.height) - CGFloat(image.height) * min(wRatio, hRatio)
            let x = dw / 2
            let y = dh / 2
            self.context.draw(image, in: CGRect(x: x, y: y, width: CGFloat(image.width) * min(wRatio, hRatio), height: CGFloat(image.height) * min(wRatio, hRatio)))
            break
        case .resizeFill:
            let dw = CGFloat(self.context.width) - CGFloat(image.width) * max(wRatio, hRatio)
            let dh = CGFloat(self.context.height) - CGFloat(image.height) * max(wRatio, hRatio)
            let x = dw / 2
            let y = dh / 2
            self.context.draw(image, in: CGRect(x: x, y: y, width: CGFloat(image.width) * max(wRatio, hRatio), height: CGFloat(image.height) * max(wRatio, hRatio)))
            break
        }
    }
    public func render(callback:@escaping (CGImage?)->Void){
        DispatchQueue.global().async {
            callback(self.context.makeImage())
        }
    }
    public func render()->CGImage?{
        return self.context.makeImage()
    }
    public class func createPixelBuffer(content:CGImage)->CVPixelBuffer?{
        
        let options = [kCVPixelBufferCGImageCompatibilityKey:true,kCVPixelBufferCGBitmapContextCompatibilityKey:true]
        var buffer:CVPixelBuffer?
        let width = content.width
        let height = content.height
        let rsult = CVPixelBufferCreate(kCFAllocatorDefault, width ,height , kCVPixelFormatType_32ARGB, options as CFDictionary, &buffer)
        if rsult == kCVReturnSuccess{
            if let bf = buffer{
                CVPixelBufferLockBaseAddress(bf, CVPixelBufferLockFlags(rawValue: 0))
                if let ctx = TinyDrawContext(pixel:bf){
                    ctx.context.draw(content, in: CGRect(x: 0, y: 0, width: width, height: height))
                }
                
                CVPixelBufferUnlockBaseAddress(bf, CVPixelBufferLockFlags(rawValue: 0))
            }
            
            return buffer
        }else{
            return nil
        }
    }
}

public class TinyCoreImageProcess:TinyVideoProcess{
    public func setSourceSize(size: CGSize) {
        if outputSize.width == 0 || outputSize.height == 0{
            self.outputSize = size
        }
    }
    

    
    public var outputSize: CGSize = CGSize.zero
    public var filter:TinyFilter
    public var ctx:CIContext
    public init(filter:TinyFilter,context:CIContext = CIContext(),size:CGSize? = nil) {
        self.filter = filter
        self.ctx = context
        if size != nil{
            self.outputSize = size!
        }
    }
    public func run(buffer: CMSampleBuffer) -> (CVPixelBuffer, CMTime)? {
//        return buffer
        guard let pixel = self.getSamplePixel(buffer: buffer) else { return nil }
        let origin = CIImage(cvImageBuffer: pixel)
        guard let cgresult = self.filter.filter(image: origin) else { return nil }
        guard let resultpb = TinyDrawContext.createPixelBuffer(content: cgresult) else { return nil }

        return (resultpb,self.getPresentationTimeStamp(buffer: buffer))
    }
    
}




public class TinyVideoSession{
    var input:TinyVideoProcessInput
    var outout:TinyVideoProcessOutput
    let process:TinyVideoProcess
    let group = DispatchGroup()
    let videoQueue = DispatchQueue(label: "videoQueue")
    let audioQueue = DispatchQueue(label: "audioQueue")
    public init(input:TinyVideoProcessInput,out:TinyVideoProcessOutput,process:TinyVideoProcess){
        self.input = input
        self.outout = out
        self.process = process
        self.input.session = self
        self.outout.session = self
    }
    public func run(complete:@escaping(Error?)->Void){
        self.input.start()
        let size = self.input.videoTracks.first?.track.naturalSize ?? .zero
        self.outout.setSourceSize(size: size)
        self.process.setSourceSize(size: size)
        self.outout.outputVideo { [weak self](i) -> (CMSampleBuffer?, CVPixelBuffer?, CMTime?)? in
            if let ws = self,let origin = ws.input.videoTracks[i].copyNextSampleBuffer(){
                guard let buffer = ws.process.run(buffer: origin) else { return (origin,nil,nil) }
                return (nil,buffer.0,buffer.1)
            }
            return nil
        }
        self.outout.outputAudio { [weak self](i) -> CMSampleBuffer? in
            if let ws = self{
                return ws.input.audioTracks[i].copyNextSampleBuffer()
            }
            return nil
        }
        self.outout.start(videoInputCount: self.input.videoTracks.count, audioCount: self.input.audioTracks.count){ i in
            if i == .completed{
                complete(nil)
            }else{
                self.input.end()
                self.outout.end()
                complete(NSError(domain: "异常结束", code: 0, userInfo: nil))
            }
        }
    }
}

public class TinyAssetVideoProcessInput:TinyVideoProcessInput{
    public var status: AVAssetReader.Status {
        return self.reader.status
    }
    
    public var session: TinyVideoSession?
    
    public var videoTracks: [AVAssetReaderTrackOutput] = []
    
    public var audioTracks: [AVAssetReaderTrackOutput] = []
    
    public func start() {
        let videoSetting:[String:Any] = [
            kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA
        ]
        self.videoTracks = self.loadAsset(asset: self.reader.asset, type: .video, setting: videoSetting)
        self.audioTracks = self.loadAsset(asset: self.reader.asset, type: .audio, setting: [AVFormatIDKey:kAudioFormatLinearPCM])
        self.reader.startReading()
    }
    
    public func end() {
        self.reader.cancelReading()
    }
    
    public var reader:AVAssetReader
    public init(asset:AVAsset) throws {
        reader = try AVAssetReader(asset: asset)
    }
    
    func loadAsset(asset:AVAsset,type:AVMediaType,setting:[String:Any]?)->[AVAssetReaderTrackOutput]{
        var array:[AVAssetReaderTrackOutput] = []
        for i in asset.tracks(withMediaType: type) {
            let tra = AVAssetReaderTrackOutput(track: i, outputSettings: setting)
            if(self.reader.canAdd(tra)){
                array.append(tra)
                self.reader.add(tra)
            }
        }
        return array
    }
}


public class TinyAssetVideoProcessOut:TinyVideoProcessOutput{
    public func setSourceSize(size: CGSize) {
        if self.width == 0 || self.height == 0{
            self.width = Int(size.width)
            self.height = Int(size.height)
        }
    }
    
    public var session: TinyVideoSession?
    
    
    var videoTracks:AVAssetWriterInput?
    var videoTracksAdaptor:AVAssetWriterInputPixelBufferAdaptor?
    var audioTracks:AVAssetWriterInput?
    
    var videoOut:((Int) -> (CMSampleBuffer?,CVPixelBuffer?,time:CMTime?)?)?
    var audioOut:((Int) -> CMSampleBuffer?)?
    
    var height:Int = 0
    var width:Int = 0
    
    
    public var videoFrameRate:Int = 30
    public var videoBitRate:Double = 1.38 * 1024 * 1024
    public var audioSampleRate:Double = 44100
    public var audioBitRate:Double = 64000
    public var numberOfChannel:Int = 2
    
    
    
    public func start(videoInputCount:Int,audioCount:Int,handleEnd:@escaping (AVAssetWriter.Status)->Void) {
       
        
        let compress:[String:Any] = [
            AVVideoAverageBitRateKey:self.videoBitRate,
            AVVideoExpectedSourceFrameRateKey:self.videoFrameRate,
            AVVideoProfileLevelKey:AVVideoProfileLevelH264HighAutoLevel
        ]
        
        var vset:[String:Any] = [
            AVVideoWidthKey:self.width,
            AVVideoHeightKey:self.height,
            AVVideoCompressionPropertiesKey:compress
        ]
        if #available(iOS 11.0, *) {
            
            vset[AVVideoCodecKey] = AVVideoCodecType.h264.rawValue
        } else {
            vset[AVVideoCodecKey] = AVVideoCodecH264
            // Fallback on earlier versions
        }
        self.videoTracks = loadAsset(type: .video, setting: vset)
        if let vt = self.videoTracks{
            self.videoTracksAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vt, sourcePixelBufferAttributes: nil)
        }
        
        let dic = [
            AVFormatIDKey : kAudioFormatMPEG4AAC,
            AVEncoderBitRateKey:self.audioBitRate,
            AVSampleRateKey:self.audioSampleRate,
            AVNumberOfChannelsKey:self.numberOfChannel
        ] as [String : Any]
        
        self.audioTracks = loadAsset(type: .audio, setting: dic)
        
        self.writer.startWriting()
        self.writer.startSession(atSourceTime: .zero)
        var videoEnd = false
        var audioEnd = false
        self.session?.group.enter()
        self.videoTracks?.requestMediaDataWhenReady(on: self.session!.videoQueue, using: {
            while (!videoEnd && self.videoTracks!.isReadyForMoreMediaData){
                guard let buffer = self.videoOut?(0) else { videoEnd = true ; break }
                if let cm = buffer.0{
                    self.videoTracks!.append(cm)
                    continue
                }
                
                if let cm = buffer.1, let vt = self.videoTracksAdaptor{
                    vt.append(cm, withPresentationTime:buffer.2!)
                    continue
                }
            }
            if videoEnd{
                self.videoTracks?.markAsFinished()
                self.session?.group.leave()
            }
        });
        self.session?.group.enter()
        self.audioTracks?.requestMediaDataWhenReady(on: self.session!.audioQueue, using: {
            while (!audioEnd && self.audioTracks!.isReadyForMoreMediaData){
                guard let buffer = self.audioOut?(0) else { audioEnd = true;break}
                self.audioTracks!.append(buffer)
            }
            if audioEnd {
                self.audioTracks?.markAsFinished()
                self.session!.group.leave()
            }
            
        });
        self.session?.group.notify(queue: DispatchQueue.global(), execute: {
            self.writer.finishWriting {
                handleEnd(self.writer.status)
            }
        })
    }
    
    public func end() {
        self.writer.cancelWriting()
    }
    
    public func outputVideo(callback: @escaping (Int) -> (CMSampleBuffer?,CVPixelBuffer?,CMTime?)?) {
        self.videoOut = callback
    }
    
    public func outputAudio(callback: @escaping (Int) -> CMSampleBuffer?) {
        self.audioOut = callback
    }
    let writer:AVAssetWriter
    public init(url:URL,type:AVFileType) throws{
        self.writer = try AVAssetWriter(outputURL: url, fileType: type)
        
        if(FileManager.default.fileExists(atPath: url.path)){
            try! FileManager.default.removeItem(at: url)
        }
    }
    
    func loadAsset(type:AVMediaType,setting:[String:Any]?)->AVAssetWriterInput?{
        let a = AVAssetWriterInput(mediaType: type, outputSettings: setting)
        if(self.writer.canAdd(a)){
            self.writer.add(a)
            return a
        }
        return nil
    }
}
