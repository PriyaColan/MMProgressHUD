//
//  MMHud.m
//  MMProgressHUD
//
//  Created by Lars Anderson on 6/28/12.
//  Copyright (c) 2012 Mutual Mobile. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "MMHud.h"
#import "MMProgressHUD.h"
#import "MMRadialProgressView.h"

CGFloat    const MMProgressHUDDefaultFontSize           = 16.f;

CGFloat    const MMProgressHUDMaximumWidth              = 300.f;
CGFloat    const MMProgressHUDMinimumWidth              = 100.f;
CGFloat    const MMProgressHUDContentPadding            = 5.f;

CGFloat    const MMProgressHUDAnimateInDurationLong     = 1.5f;
CGFloat    const MMProgressHUDAnimateInDurationMedium   = 0.75f;
CGFloat    const MMProgressHUDAnimateInDurationNormal   = 0.35f;
CGFloat    const MMProgressHUDAnimateInDurationShort    = 0.25f;
CGFloat    const MMProgressHUDAnimateInDurationVeryShort= 0.15f;

CGFloat    const MMProgressHUDAnimateOutDurationLong    = 0.75f;
CGFloat    const MMProgressHUDAnimateOutDurationMedium  = 0.55f;
CGFloat    const MMProgressHUDAnimateOutDurationShort   = 0.35f;

NSString * const MMProgressHUDFontNameBold = @"HelveticaNeue-Bold";
NSString * const MMProgressHUDFontNameNormal = @"HelveticaNeue-Light";

static const BOOL MMProgressHUDDebugModeEnabled = YES;

@interface MMHud()

@property (nonatomic, strong) UIView *progressViewContainer;
@property (nonatomic, strong) MMRadialProgressView *radialProgressView;
@property (nonatomic, readwrite, getter = isVisible) BOOL visible;
@property(nonatomic, strong, readwrite) UIActivityIndicatorView *activityIndicator;
@property (nonatomic) CGRect contentAreaFrame;
@property (nonatomic) CGRect statusFrame;
@property (nonatomic) CGRect titleFrame;

@end

@implementation MMHud

- (instancetype)init{
    if ( (self = [super init]) ) {
        _needsUpdate = YES;
        
        CGColorRef blackColor = CGColorRetain([UIColor blackColor].CGColor);
        
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
        self.layer.shadowColor  = blackColor;
        self.layer.shadowOpacity = 0.5;
        self.layer.shadowRadius = 15.0f;
        self.layer.cornerRadius = 10.0f;
        
        self.isAccessibilityElement = YES;
        
        CGColorRelease(blackColor);
        
        self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleBottomMargin;
    }
    
    return self;
}

- (void)dealloc{
    MMHudLog(@"dealloc");
    
    _delegate = nil;
    
    _titleText = nil;
    _messageText = nil;
    _image = nil;
    _animationImages = nil;
    
    _titleLabel = nil;
    _statusLabel = nil;
    _imageView = nil;
    
}

#pragma mark - Construction
- (void)buildHUDAnimated:(BOOL)animated{
    if (animated == YES) {
        [UIView
         animateWithDuration:0.33f
         animations:^{
             [self buildHUDAnimated:NO];
         }];
    }
    else{
        [self applyLayoutFrames];
    }
}

- (void)updateLayoutFrames{
    
    self.titleFrame = CGRectZero;
    self.statusFrame = CGRectZero;
    self.contentAreaFrame = CGRectZero;
    
    CGSize titleSize = CGSizeZero;
    
    if(self.titleText){
        int numberOfLines = 20;
        CGFloat lineHeight = [self.titleText sizeWithFont:self.titleLabel.font].height;
        for (CGFloat targetWidth = MMProgressHUDMinimumWidth; numberOfLines > 2; targetWidth += 25.f) {
            if(targetWidth >= 300.f)
                break;
            titleSize = [self.titleText sizeWithFont:self.titleLabel.font constrainedToSize:CGSizeMake(targetWidth, 500.f)];
            numberOfLines = titleSize.height/lineHeight;
        }
        
        self.titleFrame = CGRectMake(MMProgressHUDContentPadding,
                                     MMProgressHUDContentPadding,
                                     titleSize.width,
                                     titleSize.height);
    }
    
    if ((self.image || self.animationImages.count > 0) &&
        self.completionState == MMProgressHUDCompletionStateNone) {
        self.contentAreaFrame = CGRectMake(0.f,
                                           CGRectGetMaxY(self.titleFrame) + MMProgressHUDContentPadding,
                                           100.f,
                                           100.f);
    }
    else if(self.completionState == MMProgressHUDCompletionStateError ||
            self.completionState == MMProgressHUDCompletionStateSuccess){
        UIImage *image = [self.delegate hud:self imageForCompletionState:self.completionState];
        
        self.contentAreaFrame = CGRectMake(0.f,
                                           CGRectGetMaxY(self.titleFrame) + MMProgressHUDContentPadding,
                                           image.size.width,
                                           image.size.height);
    }
    else{
        switch (self.progressStyle) {
            case MMProgressHUDProgressStyleIndeterminate:
                self.contentAreaFrame = CGRectMake(0.f,
                                                   CGRectGetMaxY(self.titleFrame) + MMProgressHUDContentPadding,
                                                   CGRectGetWidth(self.activityIndicator.frame),
                                                   CGRectGetHeight(self.activityIndicator.frame));
                break;
            case MMProgressHUDProgressStyleLinear:
                NSAssert(NO, @"Linear progress not yet implemented");
                break;
            case MMProgressHUDProgressStyleRadial:
                self.contentAreaFrame = CGRectMake(0.f,
                                                   CGRectGetMaxY(self.titleFrame) + MMProgressHUDContentPadding,
                                                   40.f,
                                                   40.f);
                break;
            default:
                break;
        }
    }
    
    if (!self.titleText) {
        //adjust content area frame to compensate for extra padding that would have been around title label
        self.contentAreaFrame = CGRectOffset(self.contentAreaFrame,
                                             0.f,
                                             MMProgressHUDContentPadding);
    }
    
    CGSize statusSize = CGSizeZero;
    if (self.messageText) {
        for (CGFloat targetWidth = MMProgressHUDMinimumWidth; statusSize.width < statusSize.height + 35.f; targetWidth += 25.f) {//35 is a fudge number
            if(targetWidth >= 300.f)
                break;
            statusSize = [self.messageText sizeWithFont:self.statusLabel.font
                                      constrainedToSize:CGSizeMake(targetWidth, 500.f)];
        }
        
        self.statusFrame = CGRectMake(MMProgressHUDContentPadding,
                                      CGRectGetMaxY(self.contentAreaFrame) + MMProgressHUDContentPadding,
                                      statusSize.width,
                                      statusSize.height);
    }
    
    CGFloat largerContentDimension = MAX(titleSize.width, statusSize.width);
    CGFloat upperBoundedContentWidth = MIN(largerContentDimension, MMProgressHUDMaximumWidth);
    CGFloat boundedContentWidth = MAX(upperBoundedContentWidth, MMProgressHUDMinimumWidth);
    CGFloat hudWidth = boundedContentWidth;
    
    if (self.titleText) {
        self.titleFrame = CGRectIntegral(CGRectMake(self.titleFrame.origin.x,
                                                    self.titleFrame.origin.y,
                                                    hudWidth,
                                                    self.titleFrame.size.height));
    }
    
    if(self.messageText){
        self.statusFrame = CGRectIntegral(CGRectMake(self.statusFrame.origin.x,
                                                     self.statusFrame.origin.y,
                                                     hudWidth,
                                                     self.statusFrame.size.height));
    }
    
    CGRect imageTitleRect = CGRectUnion(self.titleFrame, self.contentAreaFrame);
    CGRect finalHudBounds = CGRectUnion(imageTitleRect, self.statusFrame);
    
    //center stuff
    self.titleFrame = CGRectMake(MMProgressHUDContentPadding,
                                 self.titleFrame.origin.y,
                                 CGRectGetWidth(finalHudBounds),
                                 CGRectGetHeight(self.titleFrame));
    self.statusFrame = CGRectMake(MMProgressHUDContentPadding,
                                  self.statusFrame.origin.y,
                                  CGRectGetWidth(finalHudBounds),
                                  CGRectGetHeight(self.statusFrame));
    self.contentAreaFrame = CGRectMake(CGRectGetWidth(finalHudBounds)/2
                                           - CGRectGetWidth(self.contentAreaFrame)/2
                                           + MMProgressHUDContentPadding,
                                       self.contentAreaFrame.origin.y,
                                       CGRectGetWidth(self.contentAreaFrame),
                                       CGRectGetHeight(self.contentAreaFrame));
    
    self.titleFrame = CGRectIntegral(self.titleFrame);
    self.statusFrame = CGRectIntegral(self.statusFrame);
    self.contentAreaFrame = CGRectIntegral(self.contentAreaFrame);
    
    [self _layoutContentArea];
    
    self.needsUpdate = NO;
}

- (void)applyLayoutFrames{
    if (self.needsUpdate == YES) {
        [self updateLayoutFrames];
    }
    
    if (!self.titleText) {
        self.statusLabel.font = [UIFont fontWithName:MMProgressHUDFontNameBold size:MMProgressHUDDefaultFontSize];
    }
    else{
        self.statusLabel.font = [UIFont fontWithName:MMProgressHUDFontNameNormal size:MMProgressHUDDefaultFontSize];
    }
    
    //animate text change
    CATransition *titleAnimation = [CATransition animation];
    titleAnimation.duration = MMProgressHUDAnimateInDurationShort;
    titleAnimation.type = kCATransitionFade;
    titleAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.titleLabel.layer addAnimation:titleAnimation forKey:@"changeTextTransition"];
    
    self.titleLabel.text = self.titleText;
    
//    CATransition *statusAnimation = [CATransition animation];
//    statusAnimation.duration = MMProgressHUDAnimateInDurationShort;
//    statusAnimation.type = kCATransitionFade;
//    statusAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
//    [self.statusLabel.layer addAnimation:statusAnimation forKey:@"changeTextTransition"];
    
    self.statusLabel.text = self.messageText;
    
    //size HUD
    CGRect hudRect;
    
    //update container
    CGRect imageTitleRect = CGRectUnion(self.titleFrame, self.contentAreaFrame);
    CGRect finalHudBounds = CGRectUnion(imageTitleRect, self.statusFrame);
    
    if (!CGRectEqualToRect(self.frame, CGRectZero)) {
        //preserve center
        CGPoint center;
        if(self.isVisible){
            center = [self.delegate hudCenterPointForDisplay:self];
        }
        else{
            center = self.center;
        }
        
        hudRect = CGRectMake(roundf(center.x - self.layer.anchorPoint.x * CGRectGetWidth(finalHudBounds)),
                             roundf(center.y - self.layer.anchorPoint.y * CGRectGetHeight(finalHudBounds) + (0.5 - self.layer.anchorPoint.y) * 2 * MMProgressHUDContentPadding),
                             CGRectGetWidth(finalHudBounds),
                             CGRectGetHeight(finalHudBounds));
        
        hudRect = CGRectIntegral(CGRectInset(hudRect, -MMProgressHUDContentPadding, -MMProgressHUDContentPadding));
        
        self.frame = hudRect;
    }
    else{
        //create offscreen
        CGPoint center = [self.delegate hudCenterPointForDisplay:self];
        
        hudRect = CGRectMake(roundf(center.x - CGRectGetWidth(finalHudBounds)/2),
                             roundf(-finalHudBounds.size.height*2),
                             CGRectGetWidth(finalHudBounds),
                             CGRectGetHeight(finalHudBounds));
        
        
        hudRect = CGRectIntegral(CGRectInset(hudRect, -MMProgressHUDContentPadding, -MMProgressHUDContentPadding));
        
        self.frame = hudRect;
        
        CGColorRef blackColor = CGColorRetain([UIColor blackColor].CGColor);
        
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
        self.layer.shadowColor  = blackColor;
        self.layer.shadowOpacity = 0.5;
        self.layer.shadowRadius = 15.0f;
        self.layer.cornerRadius = 10.0f;
        
        CGColorRelease(blackColor);
        
        self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleBottomMargin;
    }
    
    //update subviews' frames
    self.titleLabel.frame = self.titleFrame;
    self.statusLabel.frame = self.statusFrame;
    self.progressViewContainer.frame = self.contentAreaFrame;
    
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.layer.cornerRadius].CGPath;
}

#pragma mark - Updating Content
- (void)updateTitle:(NSString *)title animated:(BOOL)animated{
    self.titleText = title;
    
    [self updateAnimated:animated withCompletion:nil];
}

- (void)updateMessage:(NSString *)message animated:(BOOL)animated{
    self.messageText = message;
    
    [self updateAnimated:animated withCompletion:nil];
}

- (void)updateTitle:(NSString *)title message:(NSString *)message animated:(BOOL)animated{
    self.messageText = message;
    self.titleText = title;
    
    [self updateAnimated:animated withCompletion:nil];
}

- (void)updateAnimated:(BOOL)animated withCompletion:(void(^)(BOOL completed))updateCompletion{
    if (animated) {
        [UIView
         animateWithDuration:MMProgressHUDAnimateInDurationShort
         delay:0.f
         options:UIViewAnimationOptionCurveLinear
         animations:^{
             [self applyLayoutFrames];
         }
         completion:updateCompletion];
    }
    else{
        [self applyLayoutFrames];
        
        if (updateCompletion != nil) {
            updateCompletion(YES);
        }
    }
}

#pragma mark - Private Methods
- (void)_layoutContentArea{
    //hud should already be the correct size before getting into this method
    self.progressViewContainer.frame = self.contentAreaFrame;
    
    self.imageView.hidden = (self.image == nil && self.animationImages.count == 0);
    self.radialProgressView.hidden = (self.progressStyle != MMProgressHUDProgressStyleRadial);
    
    if (self.completionState == MMProgressHUDCompletionStateNone) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        
        if(self.animationImages.count > 0){
            self.imageView.image = nil;
            self.imageView.animationImages = self.animationImages;
            
            [self.activityIndicator stopAnimating];
            
            if (self.animationLoopDuration) {
                self.imageView.animationDuration = self.animationLoopDuration;
            }
            else{
                self.imageView.animationDuration = 0.5;
            }
            
            self.imageView.contentMode = UIViewContentModeScaleAspectFit;
            
            [self.imageView startAnimating];
        }
        else if(self.image != nil){
            self.imageView.animationImages = nil;
            self.imageView.image = self.image;
            
            [self.activityIndicator stopAnimating];
            
            //layout imageview content mode
//            if (self.imageView.image.size.width < CGRectGetWidth(self.imageView.frame) && self.imageView.image.size.height < CGRectGetHeight(self.imageView.frame)) {
//                self.imageView.contentMode = UIViewContentModeCenter;
//            }
//            else if(self.imageView.image.size.width > CGRectGetWidth(self.imageView.frame) && self.imageView.image.size.height > CGRectGetHeight(self.imageView.frame)){
//                self.imageView.contentMode = UIViewContentModeScaleAspectFit;
//            }
//            else{
//                self.imageView.contentMode = UIViewContentModeScaleAspectFill;
//            }
        }
        else {
            self.imageView.hidden = YES;
            
            if(self.progressStyle == MMProgressHUDProgressStyleIndeterminate){
                [self.activityIndicator startAnimating];
            }
            else{
                [self.activityIndicator stopAnimating];
            }
            
            switch (self.progressStyle) {
                case MMProgressHUDProgressStyleIndeterminate:
                    self.imageView.image = nil;
                    self.imageView.animationImages = nil;
                    
                    [self.progressViewContainer addSubview:self.activityIndicator];
                    break;
                case MMProgressHUDProgressStyleLinear:
                    NSAssert(NO, @"Linear progress not yet implemented");
                    break;
                case MMProgressHUDProgressStyleRadial:
                    break;
                default:
                    NSAssert(NO, @"Invalid progress style");
                    break;
            }
        }
        
        [CATransaction commit];
    }
    else{
        //completionState != MMProgressHUDCompletionStateNone
        
        UIImage *completionImage = [self.delegate hud:self imageForCompletionState:self.completionState];
//        UIViewAnimationOptions animationOptions =
//            UIViewAnimationOptionTransitionCrossDissolve |
//            UIViewAnimationOptionBeginFromCurrentState |
//            UIViewAnimationOptionCurveEaseInOut |
//            UIViewAnimationOptionAllowAnimatedContent;
//        
//        [UIView
//         transitionWithView:_progressViewContainer
//         duration:MMProgressHUDAnimateInDurationVeryShort
//         options:animationOptions
//         animations:^{
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
             [self.imageView stopAnimating];
             
             //layout imageview content mode
//             if ((completionImage.size.width <= CGRectGetWidth(self.imageView.frame)) &&
//                 (completionImage.size.height <= CGRectGetHeight(self.imageView.frame))) {
//                 self.imageView.contentMode = UIViewContentModeCenter;
//             }
//             else if((completionImage.size.width >= CGRectGetWidth(self.imageView.frame)) &&
//                     (completionImage.size.height >= CGRectGetHeight(self.imageView.frame))){
//                 self.imageView.contentMode = UIViewContentModeScaleAspectFit;
//             }
//             else{
//                 self.imageView.contentMode = UIViewContentModeScaleAspectFill;
//             }
        
             [self.activityIndicator stopAnimating];
             self.radialProgressView.hidden = YES;
             
             self.imageView.image = completionImage;
             self.imageView.hidden = NO;
        [CATransaction commit];
//         }
//         completion:nil];
    }
    
    self.completionState = MMProgressHUDCompletionStateNone;
}

- (void)_buildStatusLabel{
    if (!_statusLabel) {
        _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _statusLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _statusLabel.numberOfLines = 0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _statusLabel.lineBreakMode = UILineBreakModeWordWrap;
        _statusLabel.textAlignment = UITextAlignmentCenter;
#pragma clang diagnostic pop
        _statusLabel.backgroundColor = [UIColor clearColor];
        _statusLabel.font = [UIFont fontWithName:MMProgressHUDFontNameNormal size:MMProgressHUDDefaultFontSize];
        _statusLabel.textColor = [UIColor whiteColor];
        _statusLabel.shadowColor = [UIColor blackColor];
        _statusLabel.shadowOffset = CGSizeMake(0, -1);
        
        if (MMProgressHUDDebugModeEnabled == YES) {
            CGColorRef redColor = CGColorRetain([UIColor redColor].CGColor);
            
            _statusLabel.layer.borderColor = redColor;
            _statusLabel.layer.borderWidth = 1.f;
            
            CGColorRelease(redColor);
        }
        
        [self addSubview:_statusLabel];
    }
}

- (void)_buildTitleLabel{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _titleLabel.numberOfLines = 0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _titleLabel.lineBreakMode = UILineBreakModeWordWrap;
        _titleLabel.textAlignment = UITextAlignmentCenter;
#pragma clang diagnostic pop
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [UIFont fontWithName:MMProgressHUDFontNameBold size:MMProgressHUDDefaultFontSize];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.shadowColor = [UIColor blackColor];
        _titleLabel.shadowOffset = CGSizeMake(0, -1);
        
        if (MMProgressHUDDebugModeEnabled == YES) {
            CGColorRef blueColor = CGColorRetain([UIColor blueColor].CGColor);
            
            _titleLabel.layer.borderColor = blueColor;
            _titleLabel.layer.borderWidth = 1.f;
            
            CGColorRelease(blueColor);
        }
        
        [self addSubview:_titleLabel];
    }
}

#pragma mark - Property Overrides
- (UIImageView *)imageView{
    if (_imageView == nil) {
        _imageView = [[UIImageView alloc] initWithFrame:_progressViewContainer.bounds];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.contentMode = UIViewContentModeCenter;
        [self.progressViewContainer addSubview:_imageView];
    }
    
    return _imageView;
}

- (MMRadialProgressView *)radialProgressView{
    if (_radialProgressView == nil) {
        _radialProgressView = [[MMRadialProgressView alloc] initWithFrame:self.progressViewContainer.bounds];
        _radialProgressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.progressViewContainer addSubview:_radialProgressView];
    }
    
    return _radialProgressView;
}

- (UIView *)progressViewContainer{
    if (_progressViewContainer == nil) {
        _progressViewContainer = [[UIView alloc] initWithFrame:self.contentAreaFrame];
        _progressViewContainer.backgroundColor = [UIColor clearColor];
        
        if (MMProgressHUDDebugModeEnabled == YES) {
            CGColorRef yellowColor = CGColorRetain([UIColor yellowColor].CGColor);
            
            _progressViewContainer.layer.borderColor = yellowColor;
            _progressViewContainer.layer.borderWidth = 1.f;
            
            CGColorRelease(yellowColor);
        }
        
        [self addSubview:_progressViewContainer];
    }
    
    return _progressViewContainer;
}

- (UIActivityIndicatorView *)activityIndicator{
    if (_activityIndicator == nil) {
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        
        _activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        _activityIndicator.hidesWhenStopped = YES;
    }
    return _activityIndicator;
}

- (void)setProgress:(CGFloat)progress{
    [self setProgress:progress animated:YES];
}

- (void)setProgress:(CGFloat)progress animated:(BOOL)animated{
    _progress = progress;
    
    typeof(self) __weak weakSelf = self;
    
    void(^completionBlock)(BOOL completed) = ^(BOOL completed) {
        typeof(weakSelf) blockSelf = weakSelf;
        
        if ( (completed == YES) &&
            (progress >= 1.f) &&
            ([blockSelf.delegate respondsToSelector:@selector(hudDidCompleteProgress:)] == YES)){
            [blockSelf.delegate hudDidCompleteProgress:blockSelf];
        }
    };
    
    [self.radialProgressView setProgress:progress
                                animated:animated
                          withCompletion:completionBlock];
}

- (UILabel *)statusLabel{
    [self _buildStatusLabel];
    
    return _statusLabel;
}

- (UILabel *)titleLabel{
    [self _buildTitleLabel];
    
    return _titleLabel;
}

- (void)setMessageText:(NSString *)messageText{
    if ([messageText isEqualToString:self.messageText]) {
        return;
    }
    
    _messageText = [messageText copy];
    if (self.titleText == nil) {
        self.accessibilityLabel = _messageText;
    }
    else{
        self.accessibilityHint = _messageText;
    }
    
    [self setNeedsUpdate:YES];
}

- (void)setTitleText:(NSString *)titleText{
    if ([titleText isEqualToString:self.titleText]) {
        return;
    }
    
    _titleText = [titleText copy];
    
    self.accessibilityLabel = _titleText;
    
    [self setNeedsUpdate:YES];
}

- (void)setDisplayStyle:(MMProgressHUDDisplayStyle)style{
    _displayStyle = style;
    
    switch (style) {
        case MMProgressHUDDisplayStyleBordered:{
            CGColorRef whiteColor = CGColorRetain([UIColor whiteColor].CGColor);
            self.layer.borderColor = whiteColor;
            self.layer.borderWidth = 2.0f;
            CGColorRelease(whiteColor);
        }
            break;
        case MMProgressHUDDisplayStylePlain:
            self.layer.borderWidth = 0.0f;
            break;
        default:
            break;
    }
}

- (void)prepareForReuse{
    self.titleLabel.text = nil;
    self.statusLabel.text = nil;
    self.imageView.image = nil;
    self.imageView.animationImages = nil;
    self.progress = 0.f;
    self.layer.transform = CATransform3DIdentity;
    self.layer.opacity = 1.f;
    self.completionState = MMProgressHUDCompletionStateNone;
    self.visible = NO;
}

@end