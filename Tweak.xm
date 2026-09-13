#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

static const CGFloat SC16_CROP = 34.0;

#pragma mark - Process

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundle =
        NSBundle.mainBundle.bundleIdentifier;

    return [bundle isEqualToString:@"com.apple.springboard"];
}

static BOOL SC16Enabled(void)
{
    if (!SC16IsSpringBoard())
        return NO;

    NSString *version =
        UIDevice.currentDevice.systemVersion;

    return [version hasPrefix:@"16."];
}

#pragma mark - Screen Geometry

static CGRect SC16ScreenBounds(void)
{
    UIScreen *screen =
        UIScreen.mainScreen;

    return screen.bounds;
}

static CGFloat SC16ScaleForBounds(CGRect bounds)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return 1.0;

    if (height > width)
    {
        CGFloat available =
            height -
            (SC16_CROP * 2.0);

        if (available <= 0.0)
            return 1.0;

        return available / height;
    }

    CGFloat available =
        width -
        (SC16_CROP * 2.0);

    if (available <= 0.0)
        return 1.0;

    return available / width;
}

#pragma mark - Window Filter

static BOOL SC16SkipWindow(UIWindow *window)
{
    if (!window)
        return YES;

    if (window.hidden)
        return YES;

    if (window.alpha <= 0.0)
        return YES;

    NSString *cls =
        NSStringFromClass(window.class);

    /*
     * Keyboard tuyệt đối không scale.
     */
    if ([cls containsString:@"Keyboard"])
        return YES;

    if ([cls containsString:@"UITextEffects"])
        return YES;

    if ([cls containsString:@"UIRemoteKeyboard"])
        return YES;

    return NO;
}

#pragma mark - Transform

static void SC16TransformWindow(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (SC16SkipWindow(window))
        return;

    CGRect screenBounds =
        SC16ScreenBounds();

    CGFloat scale =
        SC16ScaleForBounds(screenBounds);

    if (scale >= 1.0)
    {
        window.transform =
            CGAffineTransformIdentity;

        return;
    }

    /*
     * Không dùng frame sau khi transform.
     * Dùng bounds + center để tránh
     * frame bị UIKit tính sai khi xoay.
     */

    CGPoint screenCenter =
        CGPointMake(
            CGRectGetMidX(screenBounds),
            CGRectGetMidY(screenBounds)
        );

    /*
     * Với window toàn màn hình:
     * center chính là tâm màn hình.
     *
     * Với system overlay:
     * giữ nguyên center nếu nó đã có
     * vị trí riêng của SpringBoard.
     */
    BOOL fullScreen =
        CGRectEqualToRect(
            window.bounds,
            screenBounds
        );

    if (fullScreen)
    {
        window.center =
            screenCenter;
    }

    window.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    /*
     * Chỉ sửa lại tâm cho full-screen window.
     * Không ép mọi overlay về giữa màn hình.
     */
    if (fullScreen)
    {
        window.center =
            screenCenter;
    }
}

#pragma mark - SpringBoard Windows

static void SC16ApplySpringBoardWindows(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *app =
        UIApplication.sharedApplication;

    NSSet<UIScene *> *scenes =
        app.connectedScenes;

    for (UIScene *scene in scenes)
    {
        if (![scene
              isKindOfClass:[UIWindowScene class]])
        {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState ==
            UISceneActivationStateUnattached)
        {
            continue;
        }

        /*
         * QUAN TRỌNG:
         *
         * Dùng UIWindowScene.windows.
         * Không dùng UIApplication.windows.
         */
        NSArray<UIWindow *> *windows =
            windowScene.windows;

        for (UIWindow *window in windows)
        {
            SC16TransformWindow(window);
        }
    }
}

#pragma mark - Reapply

static void SC16ScheduleRefresh(void)
{
    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplySpringBoardWindows();

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(
                        0.15 *
                        NSEC_PER_SEC
                    )
                ),
                dispatch_get_main_queue(),
                ^{
                    SC16ApplySpringBoardWindows();
                }
            );

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(
                        0.5 *
                        NSEC_PER_SEC
                    )
                ),
                dispatch_get_main_queue(),
                ^{
                    SC16ApplySpringBoardWindows();
                }
            );
        }
    );
}

#pragma mark - UIWindow

%hook UIWindow

- (void)makeKeyAndVisible
{
    %orig;

    if (SC16Enabled())
        SC16ScheduleRefresh();
}

- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (SC16Enabled())
        SC16ScheduleRefresh();
}

- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (SC16Enabled() && !hidden)
        SC16ScheduleRefresh();
}

- (void)setFrame:(CGRect)frame
{
    %orig(frame);

    if (SC16Enabled())
    {
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                SC16ApplySpringBoardWindows();
            }
        );
    }
}

%end

#pragma mark - Orientation

%hook UIWindowScene

- (void)setInterfaceOrientation:
    (UIInterfaceOrientation)orientation
{
    %orig(orientation);

    if (SC16Enabled())
        SC16ScheduleRefresh();
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        /*
         * CHỈ SpringBoard.
         *
         * Đây là lớp bảo vệ quan trọng nhất
         * để tránh transform toàn bộ app.
         */
        if (!SC16Enabled())
            return;

        SC16ScheduleRefresh();
    }
}
