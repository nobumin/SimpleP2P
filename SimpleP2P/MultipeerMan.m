//
//  MultipeerMan.m
//  SimpleP2P
//
//  Created by 長島 伸光 on 2014/07/28.
//  Copyright (c) 2014年 長島 伸光. All rights reserved.
//

#import "MultipeerMan.h"
#import "VoiceReceiver.h"
#import "MainViewController.h"
#import "common.h"

@interface MultipeerMan () {
    MCPeerID *peerId_;
    MCSession *session_;
    MCNearbyServiceAdvertiser *nearbyServiceAdvertiser_;
    MCNearbyServiceBrowser *nearbyServiceBrowser_;
    NSString *lastName_;
    NSOutputStream *ostream_;

    dispatch_semaphore_t semaphore_;
    NSMutableData *soundData_;
    NSUInteger buffLength_;
    
    BOOL isSending_;
    id<MultipeerManDelegate> delegate_;
    VoiceReceiver *voiceReceiver_;
}
@end

@implementation MultipeerMan

- (id)initWithPeerInterface:(id<MultipeerManDelegate>)delegate
{
    self = [super init];
    if(self) {
        isSending_ = NO;
        semaphore_ = dispatch_semaphore_create(1);
        soundData_ = [[NSMutableData alloc] initWithCapacity:0];
        buffLength_ = 0;
        ostream_ = nil;
        delegate_ = delegate;
        voiceReceiver_ = [[VoiceReceiver alloc] init];
    }
    return self;
}

- (void)connectWithName:(NSString*)name
{
    peerId_ = [[MCPeerID alloc] initWithDisplayName:name];
    session_ = [[MCSession alloc] initWithPeer:peerId_];
    session_.delegate = self;
    nearbyServiceAdvertiser_ = [[MCNearbyServiceAdvertiser alloc] initWithPeer:peerId_ discoveryInfo:nil serviceType:SERVICE_TYPE];
    nearbyServiceAdvertiser_.delegate = self;
    [nearbyServiceAdvertiser_ startAdvertisingPeer];
    
    nearbyServiceBrowser_ = [[MCNearbyServiceBrowser alloc] initWithPeer:peerId_ serviceType:SERVICE_TYPE];
    nearbyServiceBrowser_.delegate = self;
    [nearbyServiceBrowser_ startBrowsingForPeers];
}

- (void)sessoinDisconnect
{
    if(nearbyServiceBrowser_) {
        [nearbyServiceBrowser_ stopBrowsingForPeers];
    }
    if(nearbyServiceAdvertiser_) {
        [nearbyServiceAdvertiser_ stopAdvertisingPeer];
    }
    if(session_) {
        [session_ disconnect];
    }
}

#pragma mark MCSessionDelegate
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    NSLog(@"didReceiveData");
    //nop
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName
       fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    NSLog(@"didStartReceivingResourceWithName");
    //nop
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName
       fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    NSLog(@"didFinishReceivingResourceWithName");
    //nop
}

//音声受信
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    unsigned char buff[2048];
    if([stream streamStatus] == NSStreamStatusNotOpen) {
        [stream open];
    }
    NSUInteger len = [stream read:buff maxLength:2048];
    BOOL isFirst = YES;
    while(len > 0) {
        //NSLog(@"didReceiveStream：%lu", len);
        [self setBuffer:buff length:len];
        @try {
            len = [stream read:buff maxLength:2048];
            if(isFirst) {
                isFirst = NO;
                [self playSound];
                if(!ostream_) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self startWalkyTalky:peerID];
                    });
                }
            }
        }
        @catch (NSException *exception) {
            NSLog(@"%@", [exception description]);
            len = -1;
        }
        @finally {
        }
    }
    [stream close];
    [voiceReceiver_ stopPlay];
    [soundData_ resetBytesInRange:NSMakeRange(0, [soundData_ length])];
    [soundData_ setLength:0];
    buffLength_ = 0;
    NSLog(@"didReceiveStream read end");
    dispatch_async(dispatch_get_main_queue(), ^{
        [MainViewController toast:@"停止" message:@"トランシーバー機能停止"];
    });
    
    if(isSending_) {
        [voiceReceiver_ stopRecord];
        if(ostream_) {
            [ostream_ close];
            ostream_ = nil;
        }
        if(session_) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICAITON_PROGRESS_ON object:self userInfo:nil];
            [session_ disconnect];
        }
        isSending_ = NO;
        NSLog(@"CLOSE SENDFING");
    }
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    if(state == MCSessionStateConnected) {
        [delegate_ sessoinStatusConnect:peerID];
    }else{
        [delegate_ sessoinStatusDisconnect:peerID];
    }
}

- (void)setBuffer:(const unsigned char*)buff length:(NSUInteger)len
{
    dispatch_semaphore_wait(semaphore_, DISPATCH_TIME_FOREVER);
    
    if(len > 0) {
        [soundData_ appendBytes:buff length:len];
        if([soundData_ length] == 0) {
            buffLength_ = len;
        }else{
            buffLength_ += len;
        }
    }
    
    dispatch_semaphore_signal(semaphore_);
}

- (void)createAudioQueue:(AudioQueueBufferRef)buff
{
    dispatch_semaphore_wait(semaphore_, DISPATCH_TIME_FOREVER);
    
    if(buffLength_ > 0 && [soundData_ length] > 0) {
//NSLog(@"<< %d >>", len);
        [soundData_ getBytes:buff->mAudioData length:buffLength_];
        buff->mAudioDataByteSize = (unsigned int)buffLength_;
        [soundData_ resetBytesInRange:NSMakeRange(0, [soundData_ length])];
        [soundData_ setLength:0];
        buffLength_ = 0;
    }
    
    [voiceReceiver_ playEnqueueBuffer:buff];
    
    dispatch_semaphore_signal(semaphore_);
}

#pragma mark MCNearbyServiceBrowserDelegate
- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"検索エラー" message:[error localizedDescription]
                                                   delegate:self cancelButtonTitle:@"閉じる" otherButtonTitles:nil];
    [alert show];
}

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    [delegate_ findPeer:peerID];
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    [delegate_ lostPeer:peerID];
}

#pragma mark MCNearbyServiceAdvertiserDelegate
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error
{
    //NOP
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context
 invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler
{
    invitationHandler(YES, session_);
    [MainViewController toast:@"接続確認" message:@"P2P接続を開始します。"];
}

- (void)startWalkyTalky:(MCPeerID *)pid
{
    NSError *error;
    ostream_ = [session_ startStreamWithName:[NSString stringWithFormat:@"talking_%@",pid.displayName] toPeer:pid error:&error];
    if(error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"オープンエラー" message:[error localizedDescription]
                                                       delegate:self cancelButtonTitle:@"閉じる" otherButtonTitles:nil];
        [alert show];
        ostream_ = nil;
    }else{
        [ostream_ open];
        isSending_ = YES;
        [MainViewController toast:@"送信開始" message:@"トランシーバー機能開始（送信）"];
        [self sendSound];
    }
}


- (NSOutputStream*)getOutputStream
{
    return ostream_;
}

//送信側（録音）
- (void)sendSound
{
    [voiceReceiver_ record:ostream_];
}

//受信側（再生）
- (void)playSound
{
    [voiceReceiver_ play:^(AudioQueueBufferRef buff) {
        [self createAudioQueue:buff];
    }];
}

- (void)selectPeer:(MCPeerID*)pid
{
    if(isSending_) {
        [voiceReceiver_ stopRecord];
        if(ostream_) {
            [ostream_ close];
            ostream_ = nil;
        }
        if(session_) {
            [session_ disconnect];
        }
        isSending_ = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICAITON_PROGRESS_OFF object:self userInfo:nil];
        [MainViewController toast:@"停止" message:@"トランシーバー機能停止"];
    }else{
        [self startWalkyTalky:pid];
    }
}

- (void)browsPeer:(MCPeerID*)pid
{
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICAITON_PROGRESS_OFF object:self userInfo:nil];
    [nearbyServiceBrowser_ invitePeer:pid toSession:session_
                          withContext:[@"hallo" dataUsingEncoding:NSUTF8StringEncoding] timeout:15];
}

@end
