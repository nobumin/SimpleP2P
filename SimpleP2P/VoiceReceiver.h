//
//  VoiceReceiver.h
//  SimpleP2P
//
//  Created by 長島 伸光 on 2014/07/28.
//  Copyright (c) 2014年 長島 伸光. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

typedef void(^createAudioQueBuff)(AudioQueueBufferRef buff);

@interface VoiceReceiver : NSObject {
    
}

- (void)play:(createAudioQueBuff)createFunc;
- (void)record:(NSOutputStream*)outStrem;
- (void)stopPlay;
- (void)stopRecord;

//Play
- (void)playEnqueueBuffer:(AudioQueueBufferRef)buff;

@end
