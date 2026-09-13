#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

// Portrait: crop 34pt from the top and 34pt from the bottom.
static CGFloat const SC16_CROP_TOP = 34.0;
static CGFloat const SC16_CROP_BOTTOM = 34.0;

// Overall UI scale. 1.0 = original size.
// 0.90 gives a one-hand-like reduced presentation.
static CGFloat const SC16_SCALE = 0.90;

// Apply the scale around the center of the usable screen area.
static BOOL SC16Enabled(void)
{
    return [UIDevice.currentDevice.systemVersion hasPrefix:@"16."];
}

static BOOL SC16ShouldSkipWindow(UIWindow *window)
{
    if (!window || window.hidden || window.alpha <= 0.0)
        return YES;

    NSString *name = NSStringFromClass(window.class);

    if ([name containsString:@"UITextEffectsWindow"] ||
        [name containsString:@"UIRemoteKeyboardWindow"] ||
        [name containsString:@"Keyboard"] ||
        [name containsString:@"StatusBar"] ||
        [name containsString:@"_UIStatusBar"] ||
        [name containsString:@"Alert"] ||
        [name containsString:@"UIAlert"])
        return YES;

    return NO;
}

static void SC16ApplyScaleAndCrop(UIWindow *window)
{
    if (!SC16Enabled() || SC16ShouldSkipWindow(window))
        return;

    CGRect bounds = window.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    // Work in the window's existing coordinate system.
    // The crop remains 34pt top/bottom; scaling is independent.
    CGFloat usableHeight = height - SC16_CROP_TOP - SC16_CROP_BOTTOM;
    if (usableHeight <= 0.0)
        return;

    CALayer *layer = window.layer;

    // Crop only the renderable area. Do not move the UIWindow itself.
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.frame = bounds;

    CGRect visibleRect = CGRectMake(
        CGRectGetMinX(bounds),
        CGRectGetMinY(bounds) + SC16_CROP_TOP,
        width,
        usableHeight
    );

    CGPathRef path = CGPathCreateWithRect(visibleRect, NULL);
    mask.path = path;
    CGPathRelease(path);

    layer.mask = mask;

    // Scale the rendered contents inside the existing window.
    // This does not change frame/bounds or safe-area geometry.
    CGFloat scale = SC16_SCALE;
    if (scale <= 0.0 || scale > 1.0)
        scale = 1.0;

    layer.sublayerTransform = CATransform3DMakeScale(scale, scale, 1.0);

    // Keep the reduced UI centered in the usable screen region.
    CGFloat centerY = CGRectGetMinY(visibleRect) + usableHeight * 0.5;
    CGFloat deltaY = centerY - CGRectGetMidY(bounds);

    CATransform3D transform = CATransform3DMakeScale(scale, scale, 1.0);
    transform = CATransform3DTranslate(
        transform,
        0.0,
        deltaY / scale,
        0.0
    );
    layer.sublayerTransform = transform;
}

static void SC16ApplyAllScenes(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *application = UIApplication.sharedApplication;

    for (UIScene *scene in application.connectedScenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState == UISceneActivationStateUnattached)
            continue;

        for (UIWindow *window in windowScene.windows)
            SC16ApplyScaleAndCrop(window);
    }
}

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        SC16ApplyAllScenes();

        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAllScenes();
            }
        );
    });
}

#pragma mark - UIWindow Hooks

%hook UIWindow

- (void)makeKeyAndVisible
{
    %orig;
    SC16ScheduleApply();
}

- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!hidden)
        SC16ScheduleApply();
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        if (!SC16Enabled())
            return;

        SC16ScheduleApply();
    }
}
