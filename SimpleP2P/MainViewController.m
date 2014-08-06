//
//  MainViewController.m
//  SimpleP2P
//
//  Created by 長島 伸光 on 2014/03/26.
//  Copyright (c) 2014年 長島 伸光. All rights reserved.
//

#import "MainViewController.h"
#import "UIView+Toast.h"
#import "MultipeerMan.h"
#import "common.h"

@interface MainViewController () {
    NSString *lastName_;
    NSMutableArray *peers_;
    NSMutableArray *selectedPeers_;
    NSOutputStream *ostream_;
    
    NSInteger selected_;
    MultipeerMan *multipeerMan_;
}

@end

@implementation MainViewController

static UIView *mainView_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        mainView_ = self.view;
        NSNotificationCenter *notification = [NSNotificationCenter defaultCenter];
        [notification addObserver:self selector:@selector(progressVisible:) name:NOTIFICAITON_PROGRESS_ON object:nil];
        [notification addObserver:self selector:@selector(progressHidden:) name:NOTIFICAITON_PROGRESS_OFF object:nil];
        
        peers_ = [[NSMutableArray alloc] initWithCapacity:0];
        selectedPeers_ = [[NSMutableArray alloc] initWithCapacity:0];
        selected_ = -1;
        indicator_.center = self.view.center;
        multipeerMan_ = [[MultipeerMan alloc] initWithPeerInterface:self];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

+ (void)toast:(NSString*)title message:(NSString*)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [mainView_ makeToast:message duration:1.0 position:@"center" title:title];
    });
}

- (void)progressVisible:(NSNotification *)notification
{
//    dispatch_async(dispatch_get_main_queue(), ^{
//        progressView_.hidden = NO;
//    });
}

- (void)progressHidden:(NSNotification *)notification
{
//    dispatch_async(dispatch_get_main_queue(), ^{
//        progressView_.hidden = YES;
//    });
}

#pragma mark OnClick Event
- (IBAction)onTalk:(id)sender
{
    if([nameFiled_.text length] > 0 && [nameFiled_.text length] < 63) {
        [nameFiled_ resignFirstResponder];
        if(!lastName_ || ![lastName_ isEqualToString:nameFiled_.text]) {
            if(!lastName_) {
                //切断処理？
                [peers_ removeAllObjects];
                [table_ reloadData];
                [multipeerMan_ sessoinDisconnect];
                selected_ = -1;
            }
            [talkButton_ setTitle:@"WAIT CONN" forState:UIControlStateNormal];
            lastName_ = [NSString stringWithString:nameFiled_.text];
            [multipeerMan_ connectWithName:nameFiled_.text];
        }
    }
}

#pragma mark UITextFieldDelegate
- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    if([nameFiled_.text length] > 0 && [nameFiled_.text length] < 63) {
        talkButton_.enabled = YES;
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    if([nameFiled_.text length] > 0 && [nameFiled_.text length] < 63) {
        talkButton_.enabled = YES;
    }else{
        talkButton_.enabled = NO;
    }
    return YES;
}

#pragma mark MultipeerManDelegate
- (void)sessoinStatusConnect:(MCPeerID*)peerId
{
    if(selected_ < 0 ) {
        selected_ = [peers_ indexOfObject:peerId];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:selected_ inSection:0];
        UITableViewCell *cell = [table_ cellForRowAtIndexPath:indexPath];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        [selectedPeers_ addObject:[peers_ objectAtIndex:selected_]];
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICAITON_PROGRESS_OFF object:self userInfo:nil];
        [table_ reloadData];
        [MainViewController toast:@"接続完了" message:@"P2P接続が確立しました。"];
    });
}

- (void)sessoinStatusDisconnect:(MCPeerID*)peerId
{
    if(selected_ < 0 ) {
        selected_ = [peers_ indexOfObject:peerId];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:selected_ inSection:0];
        UITableViewCell *cell = [table_ cellForRowAtIndexPath:indexPath];
        cell.accessoryType = UITableViewCellAccessoryNone;
        if([selectedPeers_ containsObject:peerId]) {
            [selectedPeers_ removeObject:peerId];
            selected_ = -1;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICAITON_PROGRESS_OFF object:self userInfo:nil];
        [table_ reloadData];
    });
}

- (void)findPeer:(MCPeerID*)peerId
{
    if(![peers_ containsObject:peerId]) {
        [peers_ addObject:peerId];
        [table_ reloadData];
    }
}

- (void)lostPeer:(MCPeerID*)peerId
{
    if([peers_ containsObject:peerId]) {
        [peers_ removeObject:peerId];
        [table_ reloadData];
    }
    if([selectedPeers_ containsObject:peerId]) {
        [selectedPeers_ removeObject:peerId];
    }
}

#pragma mark UITableViewDataSource
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50.0;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [peers_ count];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    [cell.textLabel setText:[[peers_ objectAtIndex:indexPath.row] displayName]];
    if([selectedPeers_ containsObject:[peers_ objectAtIndex:indexPath.row]]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }else{
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    MCPeerID *pid = [peers_ objectAtIndex:indexPath.row];
    if(cell.accessoryType == UITableViewCellAccessoryCheckmark) {
        [multipeerMan_ selectPeer:pid];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }else{
        selected_ = indexPath.row;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [multipeerMan_ browsPeer:pid];
    }
}

@end
