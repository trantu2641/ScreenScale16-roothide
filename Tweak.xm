#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma mark - Configuration

/*
 * ScreenScale16 - Roothide
 *
 * Mục tiêu:
 *
 * Portrait:
 *   34px trên
 *   34px dưới
 *
 * Landscape:
 *   34px trái
 *   34px phải
 *
 * Đây là SCALE toàn bộ UI.
 *
 * Không:
 *   - dịch UI 10px
 *   - thay đổi frame để crop
 *   - bo góc màn hình
 *
 * UI sau khi scale luôn nằm ở GIỮA màn hình.
 */

static const CGFloat SC16_MARGIN = 34.0;

#pragma mark - Enable

static BOOL SC16Enabled(void)
{
    NSString *version = UIDevice.currentDevice.systemVersion;

    return [version hasPrefix:@"16."];
}

#pragma mark - Window Filter

static BOOL SC16ShouldSkipWindow(UIWindow *window)
{
    if (!window)
        return YES;

    if (window.hidden)
        return YES;

    if (window.alpha <= 0.0)
        return YES;

    NSString *className =
        NSStringFromClass(window.class);

    /*
     * Không scale keyboard.
     */
    if ([className containsString:@"UITextEffectsWindow"])
        return YES;

    if ([className containsString:@"UIRemoteKeyboardWindow"])
        return YES;

    if ([className containsString:@"KeyboardWindow"])
        return YES;

    if ([className containsString:@"Keyboard"])
        return YES;

    /*
     * Không scale system status bar.
     */
    if ([className containsString:@"StatusBar"])
        return YES;

    if ([className containsString:@"_UIStatusBar"])
        return YES;

    /*
     * Không đụng các window không có root VC.
     */
    if (!window.rootViewController)
        return YES;

    return NO;
}

#pragma mark - Calculate Scale

static CGFloat SC16ScaleForWindow(UIWindow *window)
{
    CGRect bounds = window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return 1.0;

    /*
     * Portrait:
     *
     * 34px trên
     * 34px dưới
     */
    if (height > width)
    {
        CGFloat usableHeight =
            height - (SC16_MARGIN * 2.0);

        if (usableHeight <= 0.0)
            return 1.0;

        return usableHeight / height;
    }

    /*
     * Landscape:
     *
     * 34px trái
     * 34px phải
     */
    CGFloat usableWidth =
        width - (SC16_MARGIN * 2.0);

    if (usableWidth <= 0.0)
        return 1.0;

    return usableWidth / width;
}

#pragma mark - Apply Scale

static void SC16ApplyScale(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (SC16ShouldSkipWindow(window))
        return;

    UIViewController *root =
        window.rootViewController;

    if (!root)
        return;

    UIView *rootView =
        root.view;

    if (!rootView)
        return;

    CGRect bounds =
        window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    /*
     * Luôn reset trước.
     *
     * Điều này rất quan trọng khi xoay:
     *
     * Portrait -> Landscape
     * Landscape -> Portrait
     *
     * Không được scale chồng lên nhau.
     */
    rootView.transform =
        CGAffineTransformIdentity;

    /*
     * Lấy đúng tâm của màn hình.
     */
    CGPoint screenCenter =
        CGPointMake(
            CGRectGetMidX(bounds),
            CGRectGetMidY(bounds)
        );

    /*
     * Scale theo kích thước màn hình.
     */
    CGFloat scale =
        SC16ScaleForWindow(window);

    if (scale <= 0.0 || scale > 1.0)
        scale = 1.0;

    /*
     * Scale quanh tâm của root view.
     */
    rootView.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    /*
     * Đưa tâm root UI về đúng tâm màn hình.
     *
     * KHÔNG cộng/trừ 10px.
     * KHÔNG dịch theo margin.
     *
     * Vì vậy:
     *
     * Portrait:
     *   khoảng trống trên = khoảng trống dưới
     *
     * Landscape:
     *   khoảng trống trái = khoảng trống phải
     */
    rootView.center =
        screenCenter;
}

#pragma mark - Apply All Windows

static void SC16ApplyAllWindows(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return;

    NSSet<UIScene *> *scenes =
        application.connectedScenes;

    for (UIScene *scene in scenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        UISceneActivationState state =
            windowScene.activationState;

        if (state == UISceneActivationStateUnattached)
            continue;

        NSArray<UIWindow *> *windows =
            windowScene.windows;

        for (UIWindow *window in windows)
        {
            SC16ApplyScale(window);
        }
    }
}

#pragma mark - Delayed Apply

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAllWindows();

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(
                        0.20 *
                        NSEC_PER_SEC
                    )
                ),
                dispatch_get_main_queue(),
                ^{
                    SC16ApplyAllWindows();
                }
            );

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(
                        0.75 *
                        NSEC_PER_SEC
                    )
                ),
                dispatch_get_main_queue(),
                ^{
                    SC16ApplyAllWindows();
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

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!SC16Enabled())
        return;

    if (hidden)
        return;

    SC16ScheduleApply();
}

- (void)layoutSubviews
{
    %orig;

    if (!SC16Enabled())
        return;

    /*
     * UIKit có thể layout lại root view khi:
     *
     * - xoay màn hình
     * - thay đổi safe area
     * - chuyển app
     *
     * Apply lại sau layout để giữ scale.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyScale(self);
        }
    );
}

%end

#pragma mark - UIViewController

%hook UIViewController

/*
 * Ẩn Status Bar.
 *
 * Không ẩn Home Bar.
 * Không transform Status Bar.
 */
- (BOOL)prefersStatusBarHidden
{
    if (SC16Enabled())
        return YES;

    return %orig;
}

%end

#pragma mark - Orientation

%hook UIWindowScene

- (void)setInterfaceOrientation:
    (UIInterfaceOrientation)orientation
{
    %orig(orientation);

    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAllWindows();
        }
    );
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        if (!SC16Enabled())
            return;

        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAllWindows();

                dispatch_after(
                    dispatch_time(
                        DISPATCH_TIME_NOW,
                        (int64_t)(
                            0.25 *
                            NSEC_PER_SEC
                        )
                    ),
                    dispatch_get_main_queue(),
                    ^{
                        SC16ApplyAllWindows();
                    }
                );

                dispatch_after(
                    dispatch_time(
                        DISPATCH_TIME_NOW,
                        (int64_t)(
                            1.0 *
                            NSEC_PER_SEC
                        )
                    ),
                    dispatch_get_main_queue(),
                    ^{
                        SC16ApplyAllWindows();
                    }
                );
            }
        );
    }
}
