//
//  ViewController.m
//  RunloopThreadTest
//
//  Created by Keqiu Hu on 12/19/15.
//  Copyright © 2015 LinkedIn. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>

/**
 In this test project. I want to discover the relationship between dispatch_mainqueue / custom queue and 
 CFRunloop and potential flakiness in KIF test framework.
 */
@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIButton *tapButton;
@property (nonatomic) dispatch_queue_t queue;

@end

@implementation ViewController

- (IBAction)buttonTapped:(id)sender {
    // Test action can be triggered in runloops
    NSLog(@"BUTTON TAPPED.");
    // Test dispatch
    dispatch_async(_queue, ^{
        // Async queue test.
        NSLog(@"In async queue");
        dispatch_async(dispatch_get_main_queue(), ^{
            // Main queue test.
            NSLog(@"In main queue");
            // Notification test.
            [[NSNotificationCenter defaultCenter] postNotificationName:@"POST_NOTIFICATION" object:nil];
        });
    });
}

- (void)viewDidLoad {
    _queue = dispatch_queue_create("com.oliverhu.runlooptest", DISPATCH_QUEUE_SERIAL);
    [[NSNotificationCenter defaultCenter] addObserverForName:@"POST_NOTIFICATION" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        NSLog(@"Notification received!!");
    }];
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 10, false);
    NSLog(@"Run loop finished");
}


@end
