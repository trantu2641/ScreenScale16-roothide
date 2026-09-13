#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <math.h>

#pragma mark - Configuration

/*
 * Keep the original OneHand-style mechanism:
 * scale the root view, not UIWindow itself.
 */
static CGFloat const SC16_SCALE = 0.90;

/*
 * Physical crop in the final screen space.
 * Portrait: top/bottom.
 * Landscape: left/right.
 */
static CGFloat const SC16_CROP = 8.0;

#pragma mark - Process

static BOOL SC16IsEnabled(void)
{
    NSString *version = UIDevice.currentDevice.systemVersion;
    return [version hasPrefix:@"16."];
}

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    return [bundleID isEqualToString:@"com.apple.springboard"];
}

#pragma mark - Window detection

static BOOL SC16IsExcludedWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name = NSStringFromClass(window.class);

    static NSArray<NSString *> *excluded;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        excluded = @[
            @"UITextEffectsWindow",
            @"UIRemoteKeyboardWindow",
            @"KeyboardWindow",
            @"Keyboard",
            @"StatusBar",
            @"_UIStatusBar",
            @"UITextEffects"
        ];
    });

    for (NSString *item in excluded)
    {
        if ([name containsString:item])
            return YES;
    }

    return NO;
}

static UIWindow *SC16FindTargetWindow(void)
{
    UIApplication *application = UIApplication.sharedApplication;
    if (!application)
        return nil;

    UIWindow *fallback = nil;

    for (UIScene *scene in application.connectedScenes)
    {
        if (![scene isKindOfClass:UIWindowScene.class])
            continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;

        if (windowScene.activationState == UISceneActivationStateUnattached)
            continue;

        for (UIWindow *window in windowScene.windows)
        {
            if (!window || window.hidden || window.alpha <= 0.0)
                continue;

            if (SC16IsExcludedWindow(window))
                continue;

            if (!window.rootViewController)
                continue;

            /*
             * UIRootSceneWindow is the same root-window class used by
             * OneHandWizard. Prefer it, but retain a safe fallback.
             */
            if ([NSStringFromClass(window.class)
                    isEqualToString:@"UIRootSceneWindow"])
            {
                return window;
            }

            if (!fallback)
                fallback = window;
        }
    }

    return fallback;
}

#pragma mark - Geometry

/*
 * Exact OneHand-style transform:
 * the root view is scaled around its own center and the center is
 * explicitly restored before the transform is applied.
 */
static void SC16ApplyScaleToRootView(UIView *rootView)
{
    if (!rootView)
        return;

    UIView *superview = rootView.superview;
    if (!superview)
        return;

    CGRect bounds = rootView.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    CGFloat scale = SC16_SCALE;
    if (scale <= 0.0 || scale > 1.0)
        scale = 1.0;

    /*
     * Never use frame after applying a transform.
     * Reset first so repeated refreshes cannot compound transforms.
     */
    rootView.transform = CGAffineTransformIdentity;

    /*
     * Match OneHand's anchor-point behavior while preserving the
     * current visual position when UIKit gives us a non-standard anchor.
     */
    CALayer *layer = rootView.layer;
    if (layer)
    {
        CGPoint oldAnchor = layer.anchorPoint;
        if (fabs(oldAnchor.x - 0.5) > 0.0001 ||
            fabs(oldAnchor.y - 0.5) > 0.0001)
        {
            CGPoint oldPosition = layer.position;
            CGPoint newPosition = CGPointMake(
                oldPosition.x + (0.5 - oldAnchor.x) * layer.bounds.size.width,
                oldPosition.y + (0.5 - oldAnchor.y) * layer.bounds.size.height
            );
            layer.anchorPoint = CGPointMake(0.5, 0.5);
            layer.position = newPosition;
        }
    }

    /*
     * Center in the actual superview coordinate space.
     * This is the important correction: do not center UIWindow itself,
     * and do not derive the position from UIScreen.mainScreen.bounds.
     */
    CGPoint superCenter = CGPointMake(
        CGRectGetMidX(superview.bounds),
        CGRectGetMidY(superview.bounds)
    );

    rootView.center = superCenter;

    if (fabs(scale - 1.0) > 0.0001)
    {
        rootView.transform = CGAffineTransformMakeScale(scale, scale);
    }
}

#pragma mark - Crop / clipping

/*
 * Clip the already-scaled root view in its own coordinate system.
 * The mask is deliberately installed on the root VIEW layer, not on
 * UIWindow, so wallpaper/system windows cannot become displaced.
 */
static void SC16ApplyCrop(UIView *rootView)
{
    if (!rootView)
        return;

    CALayer *layer = rootView.layer;
    if (!layer)
        return;

    CGRect bounds = layer.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    CGFloat crop = SC16_CROP / SC16_SCALE;
    BOOL portrait = height > width;

    CGRect visible = bounds;

    if (portrait)
    {
        CGFloat maxCrop = MAX(0.0, (height - 1.0) * 0.5);
        crop = MIN(crop, maxCrop);
        visible = CGRectInset(bounds, 0.0, crop);
    }
    else
    {
        CGFloat maxCrop = MAX(0.0, (width - 1.0) * 0.5);
        crop = MIN(crop, maxCrop);
        visible = CGRectInset(bounds, crop, 0.0);
    }

    CAShapeLayer *mask = nil;

    if ([layer.mask isKindOfClass:CAShapeLayer.class])
        mask = (CAShapeLayer *)layer.mask;
    else
    {
        mask = [CAShapeLayer layer];
        layer.mask = mask;
    }

    mask.frame = bounds;

    CGPathRef path = CGPathCreateWithRect(visible, NULL);
    mask.path = path;
    CGPathRelease(path);
}


#pragma mark - Apply

static void SC16ApplyNow(void)
{
    if (!SC16IsEnabled() || !SC16IsSpringBoard())
        return;

    UIWindow *window = SC16FindTargetWindow();
    if (!window)
        return;

    UIViewController *rootVC = window.rootViewController;
    UIView *rootView = rootVC.view;
    if (!rootView)
        return;

    /* Make sure the view hierarchy has completed layout first. */
    [rootView layoutIfNeeded];

    SC16ApplyScaleToRootView(rootView);
    SC16ApplyCrop(rootView);
}

#pragma mark - Scheduling

static void SC16ScheduleApply(void)
{
    if (!SC16IsEnabled() || !SC16IsSpringBoard())
        return;

    static BOOL scheduled = NO;
    if (scheduled)
        return;

    scheduled = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        scheduled = NO;
        SC16ApplyNow();
    });
}

#pragma mark - Hooks

static void (*SC16OrigWindowMakeKeyAndVisible)(UIWindow *, SEL);
static void SC16WindowMakeKeyAndVisible(UIWindow *self, SEL _cmd)
{
    SC16OrigWindowMakeKeyAndVisible(self, _cmd);
    SC16ScheduleApply();
}

static void (*SC16OrigWindowSetRootViewController)(UIWindow *, SEL, UIViewController *);
static void SC16WindowSetRootViewController(UIWindow *self, SEL _cmd, UIViewController *vc)
{
    SC16OrigWindowSetRootViewController(self, _cmd, vc);
    SC16ScheduleApply();
}

static void (*SC16OrigWindowSetHidden)(UIWindow *, SEL, BOOL);
static void SC16WindowSetHidden(UIWindow *self, SEL _cmd, BOOL hidden)
{
    SC16OrigWindowSetHidden(self, _cmd, hidden);
    if (!hidden)
        SC16ScheduleApply();
}

static void (*SC16OrigWindowSetBounds)(UIWindow *, SEL, CGRect);
static void SC16WindowSetBounds(UIWindow *self, SEL _cmd, CGRect bounds)
{
    SC16OrigWindowSetBounds(self, _cmd, bounds);
    SC16ScheduleApply();
}

static void (*SC16OrigViewDidAppear)(UIViewController *, SEL, BOOL);
static void SC16ViewDidAppear(UIViewController *self, SEL _cmd, BOOL animated)
{
    SC16OrigViewDidAppear(self, _cmd, animated);
    SC16ScheduleApply();
}

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        if (!SC16IsEnabled() || !SC16IsSpringBoard())
            return;

        Class windowClass = objc_getClass("UIWindow");
        Class vcClass = objc_getClass("UIViewController");

        if (windowClass)
        {
            MSHookMessageEx(
                windowClass,
                @selector(makeKeyAndVisible),
                (IMP)SC16WindowMakeKeyAndVisible,
                (IMP *)&SC16OrigWindowMakeKeyAndVisible
            );

            MSHookMessageEx(
                windowClass,
                @selector(setRootViewController:),
                (IMP)SC16WindowSetRootViewController,
                (IMP *)&SC16OrigWindowSetRootViewController
            );

            MSHookMessageEx(
                windowClass,
                @selector(setHidden:),
                (IMP)SC16WindowSetHidden,
                (IMP *)&SC16OrigWindowSetHidden
            );

            MSHookMessageEx(
                windowClass,
                @selector(setBounds:),
                (IMP)SC16WindowSetBounds,
                (IMP *)&SC16OrigWindowSetBounds
            );
        }

        if (vcClass)
        {
            MSHookMessageEx(
                vcClass,
                @selector(viewDidAppear:),
                (IMP)SC16ViewDidAppear,
                (IMP *)&SC16OrigViewDidAppear
            );
        }

        /* Give SpringBoard scene creation time to finish. */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(0.75 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{
                SC16ApplyNow();
            }
        );
    }
}
