//
//  MainViewController.h
//  SimpleP2P
//
//  Created by 長島 伸光 on 2014/03/26.
//  Copyright (c) 2014年 長島 伸光. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "MultipeerMan.h"

#define NOTIFICAITON_PROGRESS_ON @"progress_on"
#define NOTIFICAITON_PROGRESS_OFF @"progress_off"

@interface MainViewController : UIViewController
<UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate, MultipeerManDelegate> {
    
    IBOutlet UITextField *nameFiled_;
    IBOutlet UIButton *talkButton_;
    IBOutlet UITableView *table_;
    
    IBOutlet UIView *progressView_;
    IBOutlet UIActivityIndicatorView *indicator_;
}

+ (void)toast:(NSString*)title message:(NSString*)message;
- (IBAction)onTalk:(id)sender;

@end
