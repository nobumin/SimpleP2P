//
//  MultipeerMan.h
//  SimpleP2P
//
//  Created by 長島 伸光 on 2014/07/28.
//  Copyright (c) 2014年 長島 伸光. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@protocol MultipeerManDelegate <NSObject>

- (void)sessoinStatusConnect:(MCPeerID*)peerId;
- (void)sessoinStatusDisconnect:(MCPeerID*)peerId;
- (void)findPeer:(MCPeerID*)peerId;
- (void)lostPeer:(MCPeerID*)peerId;

@end


@interface MultipeerMan : NSObject<MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate> {
    
}

- (id)initWithPeerInterface:(id<MultipeerManDelegate>)delegate;
- (void)connectWithName:(NSString*)name;
- (void)sessoinDisconnect;
- (void)selectPeer:(MCPeerID*)pid;
- (void)browsPeer:(MCPeerID*)pid;

@end
