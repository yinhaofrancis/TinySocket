//
//  TinyVideoTracks.swift
//  TinySocket
//
//  Created by hao yin on 2021/2/6.
//

import Foundation
import AVFoundation




public class TinyTracks{
    let composition:AVMutableComposition = AVMutableComposition()
    var layerInstruction:[AVMutableVideoCompositionLayerInstruction] = []
    var videoComposition:AVMutableVideoComposition
    var frame:CMTimeScale
    public init(renderSize:CGSize,frameDuring:CMTimeScale){
        self.videoComposition = AVMutableVideoComposition()
        self.videoComposition.renderSize = renderSize
        self.videoComposition.frameDuration = CMTime(seconds: 1, preferredTimescale: frameDuring)
        self.frame = frameDuring
    }
    
    public func add(asset:AVAsset,range:Range<Double>,at:Double) throws{
        
        for i in asset.tracks(withMediaType: .video) {
            try self.add(assetTrack: i, type: .video, range: range, at: at)
        }
        for i in asset.tracks(withMediaType: .audio) {
            try self.add(assetTrack: i, type: .audio, range: range, at: at)
        }
    }
    
    public func add(assetTrack:AVAssetTrack,range:Range<Double>,at:Double) throws{
        try self.add(assetTrack: assetTrack, type: .video, range: range, at: at)
        try self.add(assetTrack: assetTrack, type: .audio, range: range, at: at)
        
    }
    
    public func add(assetTrack:AVAssetTrack,type:AVMediaType,range:Range<Double>,at:Double) throws{
        let v = composition.addMutableTrack(withMediaType: type, preferredTrackID: kCMPersistentTrackID_Invalid)
        if(type == .video) {
            let c = AVMutableVideoCompositionLayerInstruction(assetTrack: assetTrack)
            c.setTransform(assetTrack.preferredTransform, at: CMTime(seconds: at, preferredTimescale: self.frame))
            self.layerInstruction.append(c)
        }
        let range = CMTimeRange(start: CMTime(seconds: range.lowerBound, preferredTimescale: self.frame), duration: CMTime(seconds: range.upperBound, preferredTimescale: self.frame))
        try v?.insertTimeRange(range, of: assetTrack, at: CMTime(seconds: at, preferredTimescale: self.frame))
    }
    
    public func instuction(start:Double){
        let c = AVMutableVideoCompositionInstruction()
        c.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: self.frame), duration: self.composition.duration)
        c.layerInstructions = self.layerInstruction
        self.videoComposition.instructions = [c]
    }
    
    public func export(type:AVFileType,url:URL,complete:@escaping(Error?,Bool)->Void){
        let session = AVAssetExportSession(asset: self.composition, presetName: AVAssetExportPreset640x480)
        session?.videoComposition = self.videoComposition
        session?.outputFileType = type
        session?.shouldOptimizeForNetworkUse = true
        session?.outputURL = url
        session?.exportAsynchronously {
            
            complete(session?.error,session!.status == .completed)
        }
    }
}
