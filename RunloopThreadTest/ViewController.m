//
//  ViewController.m
//  RunloopThreadTest
//
//  Created by Keqiu Hu on 12/19/15.
//  Copyright © 2015 LinkedIn. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>
#import "PushViewController.h"

#define NOTIFICATION @"POST_NOTIFICATION"

// Declaration of basic structs.
typedef struct __CFRuntimeBase {
    uintptr_t _cfisa;
    uint8_t _cfinfo[4];
#if __LP64__
    uint32_t _rc;
#endif
} CFRuntimeBase;

struct __CFRunLoopObserver {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;
    CFRunLoopRef _runLoop;
    CFIndex _rlCount;
    CFOptionFlags _activities;		/* immutable */
    CFIndex _order;			/* immutable */
    CFRunLoopObserverCallBack _callout;	/* immutable */
    CFRunLoopObserverContext _context;	/* immutable, except invalidation */
};

/**
 In this test project. I want to discover the relationship between dispatch_mainqueue / custom queue and 
 CFRunloop and potential flakiness in KIF test framework.
 */
@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIButton *tapButton;
@property (nonatomic) dispatch_queue_t queue;

@end

@implementation ViewController

- (IBAction)pushViewControllerTapped:(id)sender {
    [self presentViewController:[PushViewController new] animated:YES completion:nil];
}

- (IBAction)buttonTapped:(id)sender {
    // Test action can be triggered in runloops
    NSLog(@"Button tapped.");
    // Test dispatch
    dispatch_async(_queue, ^{
        // Async queue test.
        NSLog(@"In async queue");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSLog(@"Timer main queue");
        });
        dispatch_async(dispatch_get_main_queue(), ^{
            // Main queue test.
            NSLog(@"In main queue");
        });
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION object:nil];
    });
}

- (IBAction)runloopButtonTapped:(id)sender {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, NO);
}

- (void)viewTest:(int)number {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"asyn! %d", number);
    });
}

- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"view will appear");
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    NSLog(@"view did appear");
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    NSLog(@"view will disappear");
    [super viewWillDisappear:animated];
}

- (void)viewDidLoad {
    _queue = dispatch_queue_create("com.oliverhu.runlooptest", DISPATCH_QUEUE_SERIAL);
    [self viewTest:0];

    // WaitUntilAllOperationsAreFinished won't wait for dispatched blocks to finish (empty output)
    [[NSOperationQueue mainQueue] waitUntilAllOperationsAreFinished];

    // Print out 'async'. Run runloop for 0.1 second will drain the blocks dispatched in the runloop and output `async`.
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, NO);

    [self viewTest:1];

    // Print out 'async'. Run runloop till source handled will drain the current block (maybe, if there is no other source.) and output 'async'.
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, YES);

    // If queue is nil, the block will be dispatched to the queue which posted this notification
    [[NSNotificationCenter defaultCenter] addObserverForName:NOTIFICATION object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        NSLog(@"Notification received!! %@ in queue %@", @"ha ha", dispatch_get_current_queue());
    }];

    // Print out 'ha ha'. Post notification will synchronously call all observers' blocks.
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION object:nil];

    /**
     2016-07-07 19:48:57.355 RunloopThreadTest[8076:212215] view will appear
     2016-07-07 19:48:57.363 RunloopThreadTest[8076:212215] --CFRunLoopEntry--!
     2016-07-07 19:48:57.363 RunloopThreadTest[8076:212215] --CFRunLoopBeforeTimers--!
     2016-07-07 19:48:57.363 RunloopThreadTest[8076:212215] --CFRunLoopBeforeSources--!
     2016-07-07 19:48:57.364 RunloopThreadTest[8076:212215] asyn! 2
     2016-07-07 19:48:57.364 RunloopThreadTest[8076:212215] --CFRunLoopBeforeTimers--!
     2016-07-07 19:48:57.364 RunloopThreadTest[8076:212215] --CFRunLoopBeforeSources--!
     2016-07-07 19:48:57.364 RunloopThreadTest[8076:212215] --CFRunLoopBeforeTimers--!
     2016-07-07 19:48:57.365 RunloopThreadTest[8076:212215] --CFRunLoopBeforeSources--!
     2016-07-07 19:48:57.365 RunloopThreadTest[8076:212215] beforeWaiting!
     2016-07-07 19:48:57.365 RunloopThreadTest[8076:212215] view did appear
     viewWillAppear & viewDidLoad are in the same run loop. view did appear is in another. The UI rendering happens by end of current runloop cycle.
     */
    [self viewTest:2];

    [super viewDidLoad];

    void (^beforeWaiting) (CFRunLoopObserverRef observer, CFRunLoopActivity activity) =
    ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        NSLog(@"beforeWaiting!");
    };

    /**
     Run loop modes.
      kCFRunLoopEntry = (1UL << 0),
      kCFRunLoopBeforeTimers = (1UL << 1),
      kCFRunLoopBeforeSources = (1UL << 2),
      kCFRunLoopBeforeWaiting = (1UL << 5),
      kCFRunLoopAfterWaiting = (1UL << 6),
      kCFRunLoopExit = (1UL << 7),
      kCFRunLoopAllActivities = 0x0FFFFFFFU
     */
    void (^CFRunLoopEntry) (CFRunLoopObserverRef observer, CFRunLoopActivity activity) =
    ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        NSLog(@"--CFRunLoopEntry--!");
    };

    void (^CFRunLoopAfterWaiting) (CFRunLoopObserverRef observer, CFRunLoopActivity activity) =
    ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        NSLog(@"--CFRunLoopAfterWaiting--!");
    };

    void (^CFRunLoopExit) (CFRunLoopObserverRef observer, CFRunLoopActivity activity) =
    ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        NSLog(@"--CFRunLoopExit--!");
    };

//    void (^CFRunLoopAllActivities) (CFRunLoopObserverRef observer, CFRunLoopActivity activity) =
//    ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
//        NSLog(@"--CFRunLoopAllActivities--!");
//    };

    void (^CFRunLoopBeforeSources) (CFRunLoopObserverRef observer, CFRunLoopActivity activity) =
    ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        // Runloop's pointer is always the same, which means, the runloop would exit & re-enter
        // but it's still the same runloop.
        NSLog(@"--CFRunLoopBeforeSources--! Runloop's pointer is %p", observer->_runLoop);
    };

    void (^CFRunLoopBeforeTimers) (CFRunLoopObserverRef observer, CFRunLoopActivity activity) =
    ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        NSLog(@"--CFRunLoopBeforeTimers--!");
    };

    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, true, 0, beforeWaiting);
    CFRunLoopObserverRef observer1 = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopEntry, true, 0, CFRunLoopEntry);
    CFRunLoopObserverRef observer2 = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopAfterWaiting, true, 0, CFRunLoopAfterWaiting);
    CFRunLoopObserverRef observer3 = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopExit, true, 0, CFRunLoopExit);
//    CFRunLoopObserverRef observer4 = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopAllActivities, true, 0, CFRunLoopAllActivities);
    CFRunLoopObserverRef observer5 = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeSources, true, 0, CFRunLoopBeforeSources);
    CFRunLoopObserverRef observer6 = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeTimers, true, 0, CFRunLoopBeforeTimers);
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopDefaultMode);
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer1, kCFRunLoopDefaultMode);
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer2, kCFRunLoopDefaultMode);
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer3, kCFRunLoopDefaultMode);
//    CFRunLoopAddObserver(CFRunLoopGetMain(), observer4, kCFRunLoopDefaultMode);
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer5, kCFRunLoopDefaultMode);
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer6, kCFRunLoopDefaultMode);
}

@end
