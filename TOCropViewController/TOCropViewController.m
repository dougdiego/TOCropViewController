//
//  TOCropViewController.h
//
//  Copyright 2015 Timothy Oliver. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "TOCropViewController.h"
#import "TOCropView.h"
#import "TOCropToolbar.h"
#import "TOCropViewControllerTransitioning.h"
#import "TOActivityCroppedImageProvider.h"
#import "UIImage+CropRotate.h"
#import "TOCroppedImageAttributes.h"

typedef NS_ENUM(NSInteger, TOCropViewControllerAspectRatio) {
    TOCropViewControllerAspectRatioOriginal,
    TOCropViewControllerAspectRatioSquare,
    TOCropViewControllerAspectRatio3x2,
    TOCropViewControllerAspectRatio5x3,
    TOCropViewControllerAspectRatio4x3,
    TOCropViewControllerAspectRatio5x4,
    TOCropViewControllerAspectRatio7x5,
    TOCropViewControllerAspectRatio16x9
};

@interface TOCropViewController () <UIActionSheetDelegate, UIViewControllerTransitioningDelegate, TOCropViewDelegate>

@property (nonatomic, readwrite) UIImage *image;
@property (nonatomic, strong) TOCropToolbar *toolbar;
@property (nonatomic, strong) TOCropView *cropView;
@property (nonatomic, strong) UIView *snapshotView;
@property (nonatomic, strong) TOCropViewControllerTransitioning *transitionController;
@property (nonatomic, assign) BOOL inTransition;
@property (nonatomic, assign) CGSize aspectRatio;
@property (nonatomic, strong) UILabel *label;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@property (nonatomic, strong) UIPopoverController *activityPopoverController;
#pragma clang diagnostic pop

/* Button callback */
- (void)cancelButtonTapped;
- (void)doneButtonTapped;
- (void)showAspectRatioDialog;
- (void)resetCropViewLayout;
- (void)rotateCropView;

/* View layout */
- (CGRect)frameForToolBarWithVerticalLayout:(BOOL)verticalLayout;

@end

@implementation TOCropViewController

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super init];
    if (self) {
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        
        _transitionController = [[TOCropViewControllerTransitioning alloc] init];
        _image = image;
    }
    
    return self;
}

- (instancetype)initWithImage:(UIImage *)image aspectRatio:(CGSize) aspectRatio
{
    self = [super init];
    if (self) {
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        
        _transitionController = [[TOCropViewControllerTransitioning alloc] init];
        _image = image;
        _aspectRatio = aspectRatio;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    BOOL landscapeLayout = CGRectGetWidth(self.view.frame) > CGRectGetHeight(self.view.frame);
    self.cropView = [[TOCropView alloc] initWithImage:self.image];
    self.cropView.frame = (CGRect){(landscapeLayout ? 44.0f : 0.0f),0,(CGRectGetWidth(self.view.bounds) - (landscapeLayout ? 44.0f : 0.0f)), (CGRectGetHeight(self.view.bounds)-(landscapeLayout ? 0.0f : 44.0f)) };
    self.cropView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.cropView.delegate = self;
    
    [self.view addSubview:self.cropView];
    if(!CGSizeEqualToSize(_aspectRatio, CGSizeZero)) {
       self.toolbar = [[TOCropToolbar alloc] initWithFrame:CGRectZero hideAction:true];
    } else {
        self.toolbar = [[TOCropToolbar alloc] initWithFrame:CGRectZero hideAction:false];
    }
    self.toolbar.frame = [self frameForToolBarWithVerticalLayout:CGRectGetWidth(self.view.bounds) < CGRectGetHeight(self.view.bounds)];
    
    [self.view addSubview:self.toolbar];
    
    __weak typeof(self) weakSelf = self;
    self.toolbar.doneButtonTapped =     ^{ [weakSelf doneButtonTapped]; };
    self.toolbar.cancelButtonTapped =   ^{ [weakSelf cancelButtonTapped]; };
    self.toolbar.resetButtonTapped =    ^{ [weakSelf resetCropViewLayout]; };
    self.toolbar.clampButtonTapped =    ^{ [weakSelf showAspectRatioDialog]; };
    self.toolbar.rotateButtonTapped =   ^{ [weakSelf rotateCropView]; };
    
    self.transitioningDelegate = self;
    
    self.view.backgroundColor = self.cropView.backgroundColor;
    
    // Setup Label
    self.label = [[UILabel alloc] initWithFrame:CGRectZero];
    self.label.frame = [self frameForLabel];
    self.label.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:17];
    self.label.textColor = UIColor.whiteColor;
    self.label.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.label];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //if ([UIApplication sharedApplication].statusBarHidden == NO) {
        self.inTransition = YES;
        [self setNeedsStatusBarAppearanceUpdate];
    //}
    
    if(!CGSizeEqualToSize(_aspectRatio, CGSizeZero)) {
       [self.cropView setAspectLockEnabledWithAspectRatio:_aspectRatio animated:YES];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.inTransition = NO;
    //if (animated && [UIApplication sharedApplication].statusBarHidden == NO) {
        [UIView animateWithDuration:0.3f animations:^{ [self setNeedsStatusBarAppearanceUpdate]; }];
        
        if (self.cropView.gridOverlayHidden)
            [self.cropView setGridOverlayHidden:NO animated:YES];
    //}
    
    [self updateLabelWithSize: self.cropView.croppedImageFrame.size];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.inTransition = YES;
    [UIView animateWithDuration:0.5f animations:^{ [self setNeedsStatusBarAppearanceUpdate]; }];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.inTransition = NO;
    [self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark - Status Bar -
- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

- (BOOL)prefersStatusBarHidden
{
    return !self.inTransition;
}

- (CGRect)frameForToolBarWithVerticalLayout:(BOOL)verticalLayout
{
    CGRect frame = self.toolbar.frame;
    if (verticalLayout ) {
        CGFloat verticalTopPadding = 20.0f;
        frame = self.toolbar.frame;
        frame.origin.x = 0.0f;
        frame.origin.y = verticalTopPadding;
        frame.size.width = 44.0f;
        frame.size.height = CGRectGetHeight(self.view.frame)-verticalTopPadding;
    }
    else {
        frame.origin.x = 0.0f;
        frame.origin.y = CGRectGetHeight(self.view.bounds) - 44.0f;
        frame.size.width = CGRectGetWidth(self.view.bounds);
        frame.size.height = 44.0f;
    }
    
    return frame;
}

-(CGRect)frameForLabel {
    return CGRectMake(8, 24, CGRectGetWidth(self.view.bounds)-16, 40 );
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    BOOL verticalLayout = CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds);
    if (verticalLayout ) {
        CGRect frame = self.cropView.frame;
        frame.origin.x = 44.0f;
        frame.size.width = CGRectGetWidth(self.view.bounds) - 44.0f;
        frame.size.height = CGRectGetHeight(self.view.bounds);
        self.cropView.frame = frame;
    }
    else {
        CGRect frame = self.cropView.frame;
        frame.origin.x = 0.0f;
        frame.size.width = CGRectGetWidth(self.view.bounds);
        frame.size.height = CGRectGetHeight(self.view.bounds) - 44.0f;
        self.cropView.frame = frame;
    }
    
    [UIView setAnimationsEnabled:NO];
    self.toolbar.frame = [self frameForToolBarWithVerticalLayout:verticalLayout];
    [self.toolbar setNeedsLayout];
    self.label.frame = [self frameForLabel];
    [UIView setAnimationsEnabled:YES];
}

#pragma mark - Rotation Handling -
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    self.snapshotView = [self.toolbar snapshotViewAfterScreenUpdates:NO];
    self.snapshotView.frame = self.toolbar.frame;
    
    if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
        self.snapshotView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    else
        self.snapshotView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin;
    
    [self.view addSubview:self.snapshotView];

    self.toolbar.frame = [self frameForToolBarWithVerticalLayout:UIInterfaceOrientationIsLandscape(toInterfaceOrientation)];
    [self.toolbar layoutIfNeeded];
    
    self.toolbar.alpha = 0.0f;
    
    self.cropView.simpleMode = YES;
    [self.cropView prepareforRotation];
    
    self.label.frame = [self frameForLabel];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    self.toolbar.frame = [self frameForToolBarWithVerticalLayout:UIInterfaceOrientationIsLandscape(toInterfaceOrientation)];
    
    [UIView animateWithDuration:duration animations:^{
        self.snapshotView.alpha = 0.0f;
        self.toolbar.alpha = 1.0f;
    }];
    [self.cropView performRelayoutForRotation];
    self.label.frame = [self frameForLabel];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.snapshotView removeFromSuperview];
    self.snapshotView = nil;
    
    [self.cropView setSimpleMode:NO animated:YES];
}

#pragma mark - Reset -
- (void)resetCropViewLayout
{
    [self.cropView resetLayoutToDefaultAnimated:YES];
    self.cropView.aspectLockEnabled = NO;
    self.toolbar.clampButtonGlowing = NO;
}

#pragma mark - Aspect Ratio Handling -
- (void)showAspectRatioDialog
{
    if (self.cropView.aspectLockEnabled) {
        self.cropView.aspectLockEnabled = NO;
        self.toolbar.clampButtonGlowing = NO;
        return;
    }
    
    UIAlertController * alert =   [UIAlertController
                                  alertControllerWithTitle:@"Error"
                                  message:@"This feature has been removed"
                                  preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction * action = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //
    }];
    [alert addAction:action];
    
    [self presentViewController:alert animated:YES completion:nil];
   
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    CGSize aspectRatio = CGSizeZero;
    
    switch (buttonIndex) {
        case TOCropViewControllerAspectRatioOriginal:
            aspectRatio = CGSizeZero;
            break;
        case TOCropViewControllerAspectRatioSquare:
            aspectRatio = CGSizeMake(1.0f, 1.0f);
            break;
        case TOCropViewControllerAspectRatio3x2:
            aspectRatio = CGSizeMake(3.0f, 2.0f);
            break;
        case TOCropViewControllerAspectRatio5x3:
            aspectRatio = CGSizeMake(5.0f, 3.0f);
            break;
        case TOCropViewControllerAspectRatio4x3:
            aspectRatio = CGSizeMake(4.0f, 3.0f);
            break;
        case TOCropViewControllerAspectRatio5x4:
            aspectRatio = CGSizeMake(5.0f, 4.0f);
            break;
        case TOCropViewControllerAspectRatio7x5:
            aspectRatio = CGSizeMake(7.0f, 5.0f);
            break;
        case TOCropViewControllerAspectRatio16x9:
            aspectRatio = CGSizeMake(16.0f, 9.0f);
            break;
        default:
            return;
    }
    
    if (self.cropView.cropBoxAspectRatioIsPortrait) {
        CGFloat width = aspectRatio.width;
        aspectRatio.width = aspectRatio.height;
        aspectRatio.height = width;
    }
    
    [self.cropView setAspectLockEnabledWithAspectRatio:aspectRatio animated:YES];
    self.toolbar.clampButtonGlowing = YES;
}

- (void)rotateCropView
{
    [self.cropView rotateImageNinetyDegreesAnimated:YES];
}

#pragma mark - Crop View Delegates -
- (void)cropViewDidBecomeResettable:(TOCropView *)cropView
{
    self.toolbar.resetButtonEnabled = YES;
}

- (void)cropViewDidBecomeNonResettable:(TOCropView *)cropView
{
    self.toolbar.resetButtonEnabled = NO;
}

- (void)cropView:(TOCropView *)cropView didChangeToCropSize: (CGSize) size {
    //NSLog(@"didChangeToCropSize: %@", NSStringFromCGSize(size));
    [self updateLabelWithSize: size];
}

- (void) updateLabelWithSize: (CGSize) size {
    
    NSString * sizeString = [NSString stringWithFormat:@"%@x%@", @(size.width), @(size.height)];
    if( size.width >= 3840){
        self.label.text = [NSString stringWithFormat:@"%@ (Best Quality)", sizeString];
         self.toolbar.doneButtonEnabled = true;
    } else if (size.width < 1920){
        self.label.text = [NSString stringWithFormat:@"%@ (Low Quality)", sizeString];
        self.toolbar.doneButtonEnabled = true;
    } else {
        self.label.text = [NSString stringWithFormat:@"%@ (Good Quality)", sizeString];
        //self.label.text = sizeString;
        self.toolbar.doneButtonEnabled = true;
    }
}

#pragma mark - Presentation Handling -
- (void)presentAnimatedFromParentViewController:(UIViewController *)viewController fromFrame:(CGRect)frame completion:(void (^)(void))completion
{
    self.transitionController.image = self.image;
    self.transitionController.fromFrame = frame;

    __weak typeof (self) weakSelf = self;
    [viewController presentViewController:self animated:YES completion:^ {
        typeof (self) strongSelf = weakSelf;
        if (completion) {
            completion();
        }
        
        [strongSelf.cropView setCroppingViewsHidden:NO animated:YES];
        if (!CGRectIsEmpty(frame)) {
            [strongSelf.cropView setGridOverlayHidden:NO animated:YES];
        }
    }];
}

- (void)dismissAnimatedFromParentViewController:(UIViewController *)viewController withCroppedImage:(UIImage *)image toFrame:(CGRect)frame completion:(void (^)(void))completion
{
    self.transitionController.image = image;
    self.transitionController.fromFrame = [self.cropView convertRect:self.cropView.cropBoxFrame toView:self.view];
    self.transitionController.toFrame = frame;

    [viewController dismissViewControllerAnimated:YES completion:^ {
        if (completion) {
            completion();
        }
    }];
}

- (void)dismissAnimatedFromParentViewController:(UIViewController *)viewController toFrame:(CGRect)frame completion:(void (^)(void))completion
{
    self.transitionController.image = self.image;
    self.transitionController.fromFrame = [self.cropView convertRect:self.cropView.imageViewFrame toView:self.view];
    self.transitionController.toFrame = frame;
    
    [viewController dismissViewControllerAnimated:YES completion:^ {
        if (completion) {
            completion();
        }
    }];
}

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    __weak typeof (self) weakSelf = self;
    self.transitionController.prepareForTransitionHandler = ^{
        typeof (self) strongSelf = weakSelf;
        strongSelf.transitionController.toFrame = [strongSelf.cropView convertRect:strongSelf.cropView.cropBoxFrame toView:strongSelf.view];
        if (!CGRectIsEmpty(strongSelf.transitionController.fromFrame))
            strongSelf.cropView.croppingViewsHidden = YES;
        
        if (strongSelf.prepareForTransitionHandler)
            strongSelf.prepareForTransitionHandler();
        
        strongSelf.prepareForTransitionHandler = nil;
    };
    
    self.transitionController.isDismissing = NO;
    return self.transitionController;
}

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    __weak typeof (self) weakSelf = self;
    self.transitionController.prepareForTransitionHandler = ^{
        typeof (self) strongSelf = weakSelf;
        if (!CGRectIsEmpty(strongSelf.transitionController.toFrame))
            strongSelf.cropView.croppingViewsHidden = YES;
        else
            strongSelf.cropView.simpleMode = YES;
        
        if (strongSelf.prepareForTransitionHandler)
            strongSelf.prepareForTransitionHandler();
    };
    
    self.transitionController.isDismissing = YES;
    return self.transitionController;
}

#pragma mark - Button Feedback -
- (void)cancelButtonTapped
{
    if ([self.delegate respondsToSelector:@selector(cropViewController:didFinishCancelled:)]) {
        [self.delegate cropViewController:self didFinishCancelled:YES];
        return;
    }
    
    self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)doneButtonTapped
{
    //NSLog(@"doneButtonTapped");
    CGRect cropFrame = self.cropView.croppedImageFrame;
    NSInteger angle = self.cropView.angle;

    //If desired, when the user taps done, show an activity sheet
    if (self.showActivitySheetOnDone) {
        TOActivityCroppedImageProvider *imageItem = [[TOActivityCroppedImageProvider alloc] initWithImage:self.image cropFrame:cropFrame angle:angle];
        TOCroppedImageAttributes *attributes = [[TOCroppedImageAttributes alloc] initWithCroppedFrame:cropFrame angle:angle originalImageSize:self.image.size];
        
        NSMutableArray *activityItems = [@[imageItem, attributes] mutableCopy];
        if (self.activityItems)
            [activityItems addObjectsFromArray:self.activityItems];
        
        UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:self.applicationActivities];
        activityController.excludedActivityTypes = self.excludedActivityTypes;
        
        if (NSClassFromString(@"UIPopoverPresentationController")) {
            activityController.modalPresentationStyle = UIModalPresentationPopover;
            activityController.popoverPresentationController.sourceView = self.toolbar;
            activityController.popoverPresentationController.sourceRect = self.toolbar.doneButtonFrame;
            [self presentViewController:activityController animated:YES completion:nil];
        }
        else {
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                [self presentViewController:activityController animated:YES completion:nil];
            }
            else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                [self.activityPopoverController dismissPopoverAnimated:NO];
                self.activityPopoverController = [[UIPopoverController alloc] initWithContentViewController:activityController];
                [self.activityPopoverController presentPopoverFromRect:self.toolbar.doneButtonFrame inView:self.toolbar permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
#pragma clang diagnostic pop
            }
        }
        __weak typeof(activityController) blockController = activityController;
        #if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
        activityController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
            if (!completed)
                return;
            
            if ([self.delegate respondsToSelector:@selector(cropViewController:didFinishCancelled:)]) {
                [self.delegate cropViewController:self didFinishCancelled:NO];
            }
            else {
                [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
                blockController.completionWithItemsHandler = nil;
            }
        };
        #else
        activityController.completionHandler = ^(NSString *activityType, BOOL completed) {
            if (!completed)
                return;
            
            if ([self.delegate respondsToSelector:@selector(cropViewController:didFinishCancelled:)]) {
                [self.delegate cropViewController:self didFinishCancelled:NO];
            }
            else {
                [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
                blockController.completionHandler = nil;
            }
        };
        #endif
        
        return;
    }
    
    //If the delegate that only supplies crop data is provided, call it
    if ([self.delegate respondsToSelector:@selector(cropViewController:didCropImageToRect:angle:)]) {
        [self.delegate cropViewController:self didCropImageToRect:cropFrame angle:angle];
    }
    //If the delegate that requires the specific cropped image is provided, call it
    else if ([self.delegate respondsToSelector:@selector(cropViewController:didCropToImage:withRect:angle:)]) {
        //NSLog(@"about to crop");
        UIImage *image = nil;
        if (angle == 0 && CGRectEqualToRect(cropFrame, (CGRect){CGPointZero, self.image.size})) {
            image = self.image;
        }
        else {
            image = [self.image croppedImageWithFrame:cropFrame angle:0];
            //image = [self.image croppedImageWithFrame:cropFrame];
        }
        //NSLog(@"did crop");
        
        //dispatch on the next run-loop so the animation isn't interuppted by the crop operation
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.delegate cropViewController:self didCropToImage:image withRect:cropFrame angle:angle];
        });
    }
    else {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
