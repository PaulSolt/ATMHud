/*
 *  ATMHud.m
 *  ATMHud
 *
 *  Created by Marcel Müller on 2011-03-01.
 *  Copyright (c) 2010-2011, Marcel Müller (atomcraft)
 *  All rights reserved.
 *
 *	https://github.com/atomton/ATMHud
 */

#import "ATMHud.h"
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioServices.h>
#import "ATMHudView.h"
#import "ATMProgressLayer.h"
#import "ATMHudDelegate.h"
#import "ATMSoundFX.h"
#import "ATMHudQueueItem.h"

@interface ATMHud (Private)
- (void)construct;
@end

@implementation ATMHud
@synthesize margin, padding, alpha, gray, hideDelay, animateDuration, appearScaleFactor, disappearScaleFactor, progressBorderRadius, progressBorderWidth, progressBarRadius, progressBarInset;
@synthesize delegate, accessoryPosition;
@synthesize center;
@synthesize shadowEnabled, blockTouches, allowSuperviewInteraction;
@synthesize showSound, updateSound, hideSound;
@synthesize __view, sound, displayQueue, queuePosition;
@synthesize userObject;

- (id)init {
	if ((self = [super init])) {
		[self construct];
	}
	return self;
}

- (id)initWithDelegate:(id)hudDelegate {
	if ((self = [super init])) {
		delegate = hudDelegate;
		[self construct];
	}
	return self;
}

- (void)dealloc {
	__view.p = nil;	// prevent crashes
	//NSLog(@"ATM_HUD DEALLOC");
}

- (void)loadView {
	UIView *base = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	base.backgroundColor = [UIColor clearColor];
	base.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
							 UIViewAutoresizingFlexibleHeight);
	base.userInteractionEnabled = NO;
	[base addSubview:__view];
	
	self.view = base;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}


+ (NSString *)buildInfo {
	return @"atomHUD 1.2 • 2011-03-01";
}

#pragma mark -
#pragma mark Overrides
- (void)setAppearScaleFactor:(CGFloat)value {
	if (value == 0) {
		value = 0.01f;
	}
	appearScaleFactor = value;
}

- (void)setDisappearScaleFactor:(CGFloat)value {
	if (value == 0) {
		value = 0.01f;
	}
	disappearScaleFactor = value;
}

- (void)setAlpha:(CGFloat)value {
	alpha = value;
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	__view.backgroundLayer.backgroundColor = [UIColor colorWithWhite:gray alpha:value].CGColor;
	[CATransaction commit];
}

- (void)setGray:(CGFloat)value {
	gray = value;
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	__view.backgroundLayer.backgroundColor = [UIColor colorWithWhite:gray alpha:alpha].CGColor;
	[CATransaction commit];
}

- (void)setCenter:(CGPoint)pt
{
	center = pt;
	
	if(__view) __view.center = center;
}

- (void)setShadowEnabled:(BOOL)value {
	shadowEnabled = value;
	if (shadowEnabled) {
		__view.layer.shadowOpacity = 0.4f;
	} else {
		__view.layer.shadowOpacity = 0.0f;
	}
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"HUD: caption=%@", __view.caption];
}

#pragma mark -
#pragma mark Property forwards
- (void)setCaption:(NSString *)caption {
	__view.caption = caption;
}

- (void)setImage:(UIImage *)image {
	__view.image = image;
}

- (void)setActivity:(BOOL)activity {
	__view.showActivity = activity;
	if (activity) {
		[__view.activity startAnimating];
	} else {
		[__view.activity stopAnimating];
	}
}

- (void)setActivityStyle:(UIActivityIndicatorViewStyle)activityStyle {
	__view.activityStyle = activityStyle;
	if (activityStyle == UIActivityIndicatorViewStyleWhiteLarge) {
		__view.activitySize = CGSizeMake(37, 37);
	} else {
		__view.activitySize = CGSizeMake(20, 20);
	}
}

- (void)setFixedSize:(CGSize)fixedSize {
	__view.fixedSize = fixedSize;
}

- (void)setProgress:(CGFloat)progress {
	if(progress < 0) progress = 0;
	else
	if(progress > 1.0f) progress = 1;
	
	__view.progress = progress;
	
	[__view.progressLayer setTheProgress:progress];
	[__view.progressLayer setNeedsDisplay];
}

#pragma mark -
#pragma mark Queue
- (void)addQueueItem:(ATMHudQueueItem *)item {
	[displayQueue addObject:item];
}

- (void)addQueueItems:(NSArray *)items {
	[displayQueue addObjectsFromArray:items];
}

- (void)clearQueue {
	[displayQueue removeAllObjects];
}

- (void)startQueue {
	queuePosition = 0;
	if (!CGSizeEqualToSize(__view.fixedSize, CGSizeZero)) {
		CGSize newSize = __view.fixedSize;
		CGSize targetSize;
		ATMHudQueueItem *queueItem;
		for (NSUInteger i = 0; i < [displayQueue count]; i++) {
			queueItem = [displayQueue objectAtIndex:i];
			
			targetSize = [__view calculateSizeForQueueItem:queueItem];
			if (targetSize.width > newSize.width) {
				newSize.width = targetSize.width;
			}
			if (targetSize.height > newSize.height) {
				newSize.height = targetSize.height;
			}
		}
		[self setFixedSize:newSize];
	}
	[self showQueueAtIndex:queuePosition];
}

- (void)showNextInQueue {
	queuePosition++;
	[self showQueueAtIndex:queuePosition];
}

- (void)showQueueAtIndex:(NSUInteger)index {
	if ([displayQueue count] > 0) {
		queuePosition = index;
		if (queuePosition == [displayQueue count]) {
			[self hide];
			return;
		}
		ATMHudQueueItem *item = [displayQueue objectAtIndex:queuePosition];
		
		__view.caption = item.caption;
		__view.image = item.image;
		
		BOOL flag = item.showActivity;
		__view.showActivity = flag;
		if (flag) {
			[__view.activity startAnimating];
		} else {
			[__view.activity stopAnimating];
		}
		
		self.accessoryPosition = item.accessoryPosition;
		[self setActivityStyle:item.activityStyle];
		
		if (queuePosition == 0) {
			[__view show];
		} else {
			[__view update];
		}
	}
}

#pragma mark -
#pragma mark Controlling
- (void)show {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hide) object:nil]; 
    
	[__view show];
}

- (void)update {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hide) object:nil]; 
    
	[__view update];
}

- (void)hide {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hide) object:nil]; 
    
	[__view hide];
}

- (void)hideAfter:(NSTimeInterval)delay {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hide) object:nil]; 
	[self performSelector:@selector(hide) withObject:nil afterDelay:delay];
}

- (void)cancelHideAfterDelay {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hide) object:nil]; 
}

#pragma mark -
#pragma mark Internal methods
- (void)construct {
	margin = padding = 10.0f;
	alpha = 0.7f;
	gray = 0.0f;
	animateDuration = 0.1f;
	progressBorderRadius = 8.0f;
	progressBorderWidth = 2.0f;
	progressBarRadius = 5.0f;
	progressBarInset = 3.0f;
	accessoryPosition = ATMHudAccessoryPositionBottom;
	appearScaleFactor = disappearScaleFactor = .8f;
	
	__view = [[ATMHudView alloc] initWithFrame:CGRectZero andController:self];
	__view.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin |
							   UIViewAutoresizingFlexibleRightMargin |
							   UIViewAutoresizingFlexibleBottomMargin |
							   UIViewAutoresizingFlexibleLeftMargin);
	
	displayQueue = [[NSMutableArray alloc] init];
	queuePosition = 0;
	center = CGPointZero;
	blockTouches = NO;
	allowSuperviewInteraction = NO;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	if (!blockTouches) {
		UITouch *aTouch = [touches anyObject];
		if (aTouch.tapCount == 1) {
			CGPoint p = [aTouch locationInView:self.view];
			if (CGRectContainsPoint(__view.frame, p)) {
				if ([(id)self.delegate respondsToSelector:@selector(userDidTapHud:)]) {
					[self.delegate userDidTapHud:self];
				}
			}
		}
	}
}

- (void)playSound:(NSString *)soundPath {
	sound = [[ATMSoundFX alloc] initWithContentsOfFile:soundPath];
	[sound play];
}

@end
