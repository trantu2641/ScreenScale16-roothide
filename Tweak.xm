#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma mark - Configuration

static CGFloat const SC16_SCALE = 0.90;
static CGFloat const SC16_CROP  = 8.0;

#pragma mark - Helpers

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    return [bundleID isEqualToString:@"com.apple.springboard"];
}

static BOOL SC16Enabled(void)
{
    NSString *version = UIDevice.currentDevice.systemVersion;
    return [version hasPrefix:@"16."];
}

static BOOL SC16IsKeyboardWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name = NSStringFromClass(window.class);

    return [name containsString:@"Keyboard"] ||
           [name containsString:@"UITextEffects"] ||
           [name containsString:@"UIRemoteKeyboard"];
}

#pragma mark - Root Window

static UIWindow *SC16FindRootWindow(void)
{
    UIApplication *app = UIApplication.sharedApplication;

    if (!app)
        return nil;

    UIWindow *fallback = nil;

    for (UIScene *scene in app.connectedScenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *sceneWindow =
            (UIWindowScene *)scene;

        if (sceneWindow.activationState ==
            UISceneActivationStateUnattached)
            continue;

        for (UIWindow *window in sceneWindow.windows)
        {
            if (!window)
                continue;

            if (window.hidden)
                continue;

            if (window.alpha <= 0.0)
                continue;

            if (SC16IsKeyboardWindow(window))
                continue;

            NSString *className =
                NSStringFromClass(window.class);

            /*
             * SpringBoard root window.
             */
            if ([className isEqualToString:
                    @"UIRootSceneWindow"])
            {
                return window;
            }

            if (!fallback &&
                window.rootViewController)
            {
                fallback = window;
            }
        }
    }

    return fallback;
}

#pragma mark - Transform

static void SC16ResetView(UIView *view)
{
    if (!view)
        return;

    view.transform = CGAffineTransformIdentity;

    CALayer *layer = view.layer;

    if (layer)
    {
        layer.mask = nil;
        layer.anchorPoint =
            CGPointMake(0.5, 0.5);
    }
}

static void SC16ApplyView(UIView *view,
                          UIWindow *window)
{
    if (!view || !window)
        return;

    if (!view.window)
        return;

    CGRect bounds = view.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 ||
        height <= 0.0)
        return;

    /*
     * Không thay frame.
     * Không thay bounds.
     *
     * Chỉ dùng transform.
     */
    view.transform =
        CGAffineTransformIdentity;

    /*
     * Anchor ở chính giữa view.
     */
    view.layer.anchorPoint =
        CGPointMake(0.5, 0.5);

    /*
     * Root view của SpringBoard thường
     * đã phủ toàn bộ vùng window.
     *
     * Transform quanh tâm của chính root view.
     */
    view.transform =
        CGAffineTransformMakeScale(
            SC16_SCALE,
            SC16_SCALE
        );

    /*
     * Crop 8px ở vùng hiển thị.
     *
     * Vì view đã scale 90%, crop trong
     * tọa độ source phải bù lại:
     *
     *     8 / 0.90
     */
    CGFloat crop =
        SC16_CROP / SC16_SCALE;

    BOOL portrait =
        height > width;

    CGRect maskRect = bounds;

    if (portrait)
    {
        maskRect.origin.y += crop;
        maskRect.size.height -= crop * 2.0;
    }
    else
    {
        maskRect.origin.x += crop;
        maskRect.size.width -= crop * 2.0;
    }

    if (maskRect.size.width <= 0.0 ||
        maskRect.size.height <= 0.0)
        return;

    CAShapeLayer *mask =
        [CAShapeLayer layer];

    mask.frame = bounds;

    CGPathRef path =
        CGPathCreateWithRect(
            maskRect,
            NULL
        );

    mask.path = path;

    CGPathRelease(path);

    view.layer.mask = mask;
}

#pragma mark - Apply SpringBoard

static void SC16Apply(void)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    UIWindow *window =
        SC16FindRootWindow();

    if (!window)
        return;

    UIViewController *root =
        window.rootViewController;

    if (!root)
        return;

    UIView *rootView =
        root.view;

    if (!rootView)
        return;

    /*
     * Chờ layout hoàn tất.
     */
    [rootView layoutIfNeeded];

    SC16ApplyView(
        rootView,
        window
    );
}

#pragma mark - Scheduling

static void SC16Schedule(void)
{
    if (!SC16Enabled())
        return;

    static BOOL scheduled = NO;

    if (scheduled)
        return;

    scheduled = YES;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            scheduled = NO;

            SC16Apply();
        }
    );
}

#pragma mark - UIViewController

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated
{
    %orig(animated);

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    /*
     * Chỉ schedule.
     *
     * Không scale controller con.
     */
    SC16Schedule();
}

%end

#pragma mark - UIApplication

%hook UIApplication

- (void)applicationDidBecomeActive:
    (UIApplication *)application
{
    %orig(application);

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    SC16Schedule();
}

%end

#pragma mark - UIWindowScene

%hook UIWindowScene

- (void)sceneDidBecomeActive
{
    %orig;

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    SC16Schedule();
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        if (!SC16Enabled())
            return;

        if (!SC16IsSpringBoard())
            return;

        /*
         * Đợi SpringBoard dựng xong UI.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)
                (1.0 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{
                SC16Apply();
            }
        );
    }
}
