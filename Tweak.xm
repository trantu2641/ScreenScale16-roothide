#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Khoảng chừa mỗi cạnh.
 *
 * Portrait:
 *     trên 34
 *     dưới 34
 *
 * Landscape:
 *     trái 34
 *     phải 34
 */
static const CGFloat SC16_CROP = 34.0;

#pragma mark - Process

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    return [bundleID isEqualToString:
            @"com.apple.springboard"];
}

static BOOL SC16IsApplicationProcess(void)
{
    /*
     * SpringBoard xử lý system UI.
     * Các process app xử lý app UI.
     *
     * Không scale daemon / extension / keyboard.
     */
    if (SC16IsSpringBoard())
        return NO;

    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    if (!bundleID)
        return NO;

    if ([bundleID hasPrefix:@"com.apple."])
        return NO;

    return YES;
}

static BOOL SC16Enabled(void)
{
    NSString *version =
        UIDevice.currentDevice.systemVersion;

    if (![version hasPrefix:@"16."])
        return NO;

    return YES;
}

#pragma mark - Geometry

static CGFloat SC16ScaleForSize(CGSize size)
{
    CGFloat width =
        size.width;

    CGFloat height =
        size.height;

    if (width <= 0.0 ||
        height <= 0.0)
    {
        return 1.0;
    }

    /*
     * Portrait
     */
    if (height > width)
    {
        CGFloat availableHeight =
            height -
            (SC16_CROP * 2.0);

        if (availableHeight <= 0.0)
            return 1.0;

        return availableHeight / height;
    }

    /*
     * Landscape
     */
    CGFloat availableWidth =
        width -
        (SC16_CROP * 2.0);

    if (availableWidth <= 0.0)
        return 1.0;

    return availableWidth / width;
}

static CGPoint SC16CenterForBounds(CGRect bounds)
{
    return CGPointMake(
        CGRectGetMidX(bounds),
        CGRectGetMidY(bounds)
    );
}

#pragma mark - Window Classification

static BOOL SC16IsKeyboardWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name =
        NSStringFromClass(window.class);

    if ([name containsString:@"Keyboard"])
        return YES;

    if ([name containsString:@"UITextEffects"])
        return YES;

    if ([name containsString:@"UIRemoteKeyboard"])
        return YES;

    return NO;
}

static BOOL SC16IsStatusBarWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *name =
        NSStringFromClass(window.class);

    if ([name containsString:@"StatusBar"])
        return YES;

    if ([name containsString:@"_UIStatusBar"])
        return YES;

    if ([name containsString:@"UIStatusBar"])
        return YES;

    return NO;
}

static BOOL SC16IsAssistiveTouchWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *name =
        NSStringFromClass(window.class);

    if ([name containsString:@"Assistive"])
        return YES;

    if ([name containsString:@"AssistiveTouch"])
        return YES;

    if ([name containsString:@"AX"])
        return YES;

    return NO;
}

#pragma mark - Transform Helpers

static void SC16ResetWindowTransform(UIWindow *window)
{
    if (!window)
        return;

    window.transform =
        CGAffineTransformIdentity;
}

static void SC16ApplyCenteredTransform(
    UIWindow *window,
    CGFloat scale
)
{
    if (!window)
        return;

    if (scale <= 0.0)
        return;

    CGRect bounds =
        window.bounds;

    CGPoint center =
        SC16CenterForBounds(bounds);

    /*
     * Reset trước khi tính.
     *
     * Không lấy frame sau transform.
     * Điều này tránh lỗi tích lũy transform.
     */
    window.transform =
        CGAffineTransformIdentity;

    /*
     * Giữ tâm hiện tại.
     */
    window.center =
        center;

    window.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    /*
     * Đảm bảo không bị trôi tâm.
     */
    window.center =
        center;
}

#pragma mark - Application UI

static void SC16ScaleApplicationWindow(
    UIWindow *window
)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsApplicationProcess())
        return;

    if (!window)
        return;

    if (window.hidden)
        return;

    if (window.alpha <= 0.0)
        return;

    /*
     * Không chạm keyboard.
     */
    if (SC16IsKeyboardWindow(window))
        return;

    UIViewController *root =
        window.rootViewController;

    if (!root)
        return;

    UIView *rootView =
        root.view;

    if (!rootView)
        return;

    CGRect screenBounds =
        UIScreen.mainScreen.bounds;

    CGFloat scale =
        SC16ScaleForSize(
            screenBounds.size
        );

    if (scale >= 1.0)
    {
        SC16ResetWindowTransform(window);
        return;
    }

    /*
     * APP WINDOW:
     *
     * Scale cả root view của app,
     * không scale từng subview.
     *
     * Vì vậy toàn bộ:
     *   navigation
     *   tab bar
     *   alert
     *   game UI
     *   app controls
     *
     * đi theo cùng một tỷ lệ.
     */
    rootView.transform =
        CGAffineTransformIdentity;

    CGPoint center =
        CGPointMake(
            CGRectGetMidX(
                rootView.superview ?
                rootView.superview.bounds :
                screenBounds
            ),
            CGRectGetMidY(
                rootView.superview ?
                rootView.superview.bounds :
                screenBounds
            )
        );

    rootView.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    /*
     * Căn giữa.
     */
    if (rootView.superview)
    {
        rootView.center =
            CGPointMake(
                CGRectGetMidX(
                    rootView.superview.bounds
                ),
                CGRectGetMidY(
                    rootView.superview.bounds
                )
            );
    }
    else
    {
        rootView.center =
            center;
    }
}

#pragma mark - SpringBoard System UI

static void SC16ScaleSpringBoardWindow(
    UIWindow *window
)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    if (!window)
        return;

    if (window.hidden)
        return;

    if (window.alpha <= 0.0)
        return;

    /*
     * Keyboard không thuộc vùng scale.
     */
    if (SC16IsKeyboardWindow(window))
        return;

    CGRect bounds =
        window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 ||
        height <= 0.0)
        return;

    CGFloat scale =
        SC16ScaleForSize(
            bounds.size
        );

    if (scale >= 1.0)
    {
        SC16ResetWindowTransform(window);
        return;
    }

    /*
     * Status Bar:
     *
     * Không bỏ window này.
     * Nó phải đi cùng vùng scale.
     */
    if (SC16IsStatusBarWindow(window))
    {
        SC16ApplyCenteredTransform(
            window,
            scale
        );

        return;
    }

    /*
     * AssistiveTouch / Home ảo:
     *
     * Cũng phải nằm trong hệ tọa độ scale.
     */
    if (SC16IsAssistiveTouchWindow(window))
    {
        SC16ApplyCenteredTransform(
            window,
            scale
        );

        return;
    }

    /*
     * Các system window còn lại.
     *
     * Chỉ xử lý window có root VC,
     * tránh đụng các window kỹ thuật của UIKit.
     */
    if (!window.rootViewController)
        return;

    /*
     * Window full-screen:
     * scale toàn bộ window quanh tâm.
     */
    if (fabs(width -
             CGRectGetWidth(
                 UIScreen.mainScreen.bounds
             )) < 1.0 &&
        fabs(height -
             CGRectGetHeight(
                 UIScreen.mainScreen.bounds
             )) < 1.0)
    {
        SC16ApplyCenteredTransform(
            window,
            scale
        );

        return;
    }

    /*
     * Overlay không full-screen:
     *
     * Không ép nó về giữa màn hình.
     * Chỉ scale quanh tâm của chính nó.
     *
     * Điều này tránh Notification /
     * Control Center / popup bị lệch.
     */
    SC16ApplyCenteredTransform(
        window,
        scale
    );
}

#pragma mark - Scene Windows

static void SC16ApplyScene(
    UIWindowScene *scene
)
{
    if (!scene)
        return;

    if (scene.activationState ==
        UISceneActivationStateUnattached)
    {
        return;
    }

    NSArray<UIWindow *> *windows =
        scene.windows;

    for (UIWindow *window in windows)
    {
        if (SC16IsSpringBoard())
        {
            SC16ScaleSpringBoardWindow(
                window
            );
        }
        else
        {
            SC16ScaleApplicationWindow(
                window
            );
        }
    }
}

static void SC16ApplyAllScenes(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *application =
        UIApplication.sharedApplication;

    NSSet<UIScene *> *scenes =
        application.connectedScenes;

    for (UIScene *scene in scenes)
    {
        if (![scene
              isKindOfClass:[UIWindowScene class]])
        {
            continue;
        }

        SC16ApplyScene(
            (UIWindowScene *)scene
        );
    }
}

#pragma mark - Refresh

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAllScenes();

            /*
             * UIKit / SpringBoard thường tiếp tục
             * tạo hoặc thay đổi window sau đó.
             */
            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(
                        0.10 *
                        NSEC_PER_SEC
                    )
                ),
                dispatch_get_main_queue(),
                ^{
                    SC16ApplyAllScenes();
                }
            );

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(
                        0.30 *
                        NSEC_PER_SEC
                    )
                ),
                dispatch_get_main_queue(),
                ^{
                    SC16ApplyAllScenes();
                }
            );

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(
                        0.70 *
                        NSEC_PER_SEC
                    )
                ),
                dispatch_get_main_queue(),
                ^{
                    SC16ApplyAllScenes();
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

- (void)setFrame:(CGRect)frame
{
    %orig(frame);

    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            if (SC16IsSpringBoard())
            {
                SC16ScaleSpringBoardWindow(
                    self
                );
            }
            else
            {
                SC16ScaleApplicationWindow(
                    self
                );
            }
        }
    );
}

- (void)setBounds:(CGRect)bounds
{
    %orig(bounds);

    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            if (SC16IsSpringBoard())
            {
                SC16ScaleSpringBoardWindow(
                    self
                );
            }
            else
            {
                SC16ScaleApplicationWindow(
                    self
                );
            }
        }
    );
}

%end

#pragma mark - View Controller

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated
{
    %orig(animated);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

- (void)viewDidLayoutSubviews
{
    %orig;

    /*
     * Chỉ reapply khi đang ở SpringBoard.
     *
     * Không liên tục reset app layout.
     */
    if (!SC16Enabled())
        return;

    if (SC16IsSpringBoard())
        SC16ScheduleApply();
}

%end

#pragma mark - Scene

%hook UIWindowScene

- (void)sceneDidBecomeActive
{
    %orig;

    if (!SC16Enabled())
        return;

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

        /*
         * Chạy sau khi UIKit đã khởi tạo.
         */
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAllScenes();
            }
        );
    }
}
