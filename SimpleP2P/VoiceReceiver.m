//
//  VoiceReceiver.m
//  SimpleP2P
//
//  Created by 長島 伸光 on 2014/07/28.
//  Copyright (c) 2014年 長島 伸光. All rights reserved.
//

#import "VoiceReceiver.h"
#import "MainViewController.h"
#import "common.h"

@interface VoiceReceiver() {
    AudioStreamBasicDescription audioFormat_;
    //録音
    AudioQueueRef queueRec_;
    AudioQueueBufferRef buffersRec[REC_BUFF_NUM];
    //再生
    AudioQueueRef queuePlay_;
    AudioQueueBufferRef buffersPlay[PLAY_BUFF_NUM];
    
    createAudioQueBuff createAudioQueBuff_;
    NSOutputStream *outStrem_;
}

@end

@implementation VoiceReceiver

- (id)init {
    self = [super init];
    if(self) {
        audioFormat_.mSampleRate         = 22050.0;
        audioFormat_.mFormatID           = kAudioFormatLinearPCM;
        audioFormat_.mFormatFlags        = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked; // | kLinearPCMFormatFlagIsBigEndian
        audioFormat_.mFramesPerPacket    = 1;
        audioFormat_.mChannelsPerFrame   = 1;
        audioFormat_.mBitsPerChannel     = 16;
        audioFormat_.mBytesPerPacket     = 2;
        audioFormat_.mBytesPerFrame      = 2;
        audioFormat_.mReserved           = 0;
        
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        [audioSession setActive:YES error:nil];
    }
    return  self;
}

//再生CALLBACK
static void audioQueuePlayCallback(void                                 *userdata,
                                   AudioQueueRef                       inAQ,
                                   AudioQueueBufferRef                 outBuffer)
{
    VoiceReceiver *voiceReceiver = (__bridge VoiceReceiver *)(userdata);
    [voiceReceiver callCreateAudioQueBuff:outBuffer];
}

//受信側（内部処理）
- (void)callCreateAudioQueBuff:(AudioQueueBufferRef)buff
{
    createAudioQueBuff_(buff);
}
- (void)playEnqueueBuffer:(AudioQueueBufferRef)buff
{
    AudioQueueEnqueueBuffer(queuePlay_, buff, 0, NULL);
}
//受信側（再生）
- (void)play:(createAudioQueBuff)createFunc;
{
    createAudioQueBuff_ = createFunc;
    //リアルタイム音声生成
    AudioQueueNewOutput(&audioFormat_, audioQueuePlayCallback, (__bridge void *)self, CFRunLoopGetMain(), kCFRunLoopCommonModes, 0, &queuePlay_);
    //
    UInt32  bufferByteSize = 1024 * audioFormat_.mBytesPerPacket;
    int bufferIndex;
    for (bufferIndex = 0; bufferIndex < PLAY_BUFF_NUM; bufferIndex++) {
        AudioQueueAllocateBuffer(queuePlay_, bufferByteSize, &buffersPlay[bufferIndex]);
        //
        audioQueuePlayCallback((__bridge void *)self, queuePlay_, (AudioQueueBufferRef)buffersPlay[bufferIndex]);
    }
    OSStatus error = AudioQueueStart(queuePlay_, nil);
    if(error < 0) {
        NSLog(@"AudioQueueStart(PLY) = %d", (int)error);
    }
    [MainViewController toast:@"受信開始" message:@"トランシーバー機能開始（受信）"];
}


//録音CALLBACK
static void audioQueueInputCallback(void                                *userdata,
                                    AudioQueueRef                       inAQ,
                                    AudioQueueBufferRef                 inBuffer,
                                    const AudioTimeStamp                *inStartTime,
                                    UInt32                              inNumberPacketDescriptions,
                                    const AudioStreamPacketDescription  *inPacketDescs)
{
    VoiceReceiver *voiceReceiver = (__bridge VoiceReceiver *)(userdata);
    [voiceReceiver callPlayAudioQueBuff:inBuffer];
}

//送信側（内部処理）
- (void)callPlayAudioQueBuff:(AudioQueueBufferRef)inBuffer
{
    AudioQueueLevelMeterState levelMeter;
    UInt32 levelMeterSize = sizeof(AudioQueueLevelMeterState);
    AudioQueueGetProperty(queueRec_, kAudioQueueProperty_CurrentLevelMeterDB, &levelMeter, &levelMeterSize);
    
    if(levelMeter.mPeakPower >= SEND_POWER_THRESHOLD) {
        //
        void *data = malloc(inBuffer->mAudioDataByteSize);
        memcpy(data, inBuffer->mAudioData, inBuffer->mAudioDataByteSize);
        NSInteger result = [outStrem_ write:data maxLength:inBuffer->mAudioDataByteSize];
        if(result == -1) {
            NSLog(@"error send %@", [[outStrem_ streamError] debugDescription]);
        }
        free(data);
    }
    AudioQueueEnqueueBuffer(queueRec_, inBuffer, 0, NULL);
}

//送信側（録音）
- (void)record:(NSOutputStream*)outStrem
{
    outStrem_ = outStrem;
    AudioQueueNewInput(&audioFormat_, audioQueueInputCallback, (__bridge void *)self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &queueRec_);
    //
    UInt32  bufferByteSize = 1024 * audioFormat_.mBytesPerPacket;
    int bufferIndex;
    for (bufferIndex = 0; bufferIndex < REC_BUFF_NUM; bufferIndex++) {
        AudioQueueAllocateBuffer(queueRec_, bufferByteSize, &buffersRec[bufferIndex]);
        AudioQueueEnqueueBuffer(queueRec_, buffersRec[bufferIndex], 0, NULL);
    }
    //
    OSStatus error = AudioQueueStart(queueRec_, nil);
    UInt32 enabledLevelMeter = true;
    AudioQueueSetProperty(queueRec_, kAudioQueueProperty_EnableLevelMetering, &enabledLevelMeter, sizeof(UInt32));
    if(error < 0) {
        NSLog(@"AudioQueueStart(REC) = %d", (int)error);
    }
}

- (void)stopPlay
{
    AudioQueueFlush(queuePlay_);
    AudioQueueStop(queuePlay_, NO);
    for(int i = 0; i < PLAY_BUFF_NUM; i++) {
        AudioQueueFreeBuffer(queuePlay_, buffersPlay[i]);
    }
    AudioQueueDispose(queuePlay_, YES);
}

- (void)stopRecord
{
    AudioQueueFlush(queueRec_);
    AudioQueueStop(queueRec_, NO);
    for(int i = 0; i < REC_BUFF_NUM; i++) {
        AudioQueueFreeBuffer(queueRec_, buffersRec[i]);
    }
    AudioQueueDispose(queueRec_, YES);
}

@end
