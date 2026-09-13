#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma mark - Configuration

/*
 * Khoảng chừa ở mỗi cạnh.
 *
 * Portrait:
 *   34pt trên
 *   34pt dưới
 *
 * Landscape:
 *   34pt trái
 *   34pt phải
 *
 * UI được scale vào chính giữa vùng hiển thị.
 */
static const CGFloat SC16_CROP = 34.0;

#pragma mark - Process Check

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    return [bundleID isEqualToString:@"com.apple.springboard"];
}

#pragma mark - iOS 16 Check

static BOOL SC16Enabled(void)
{
    if (!SC16IsSpringBoard())
        return NO;

    NSString *version =
        UIDevice.currentDevice.systemVersion;

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
     * Không trực tiếp transform các window
     * chuyên dùng cho status bar.
     *
     * Status bar sẽ tự nằm trong hệ thống layout
     * của SpringBoard.
     */
    if ([className containsString:@"StatusBar"])
        return YES;

    if ([className containsString:@"_UIStatusBar"])
        return YES;

    /*
     * Một số window nội bộ không phải UI chính.
     */
    if ([className containsString:@"UITextEffects"])
        return YES;

    return NO;
}

#pragma mark - Main Window Detection

static UIWindow *SC16MainWindowForScene(UIWindowScene *scene)
{
    if (!scene)
        return nil;

    NSArray<UIWindow *> *windows =
        scene.windows;

    UIWindow *bestWindow = nil;

    for (UIWindow *window in windows)
    {
        if (SC16ShouldSkipWindow(window))
            continue;

        /*
         * Ưu tiên key window.
         */
        if (window.isKeyWindow)
            return window;

        /*
         * Nếu chưa có key window thì lấy window
         * có rootViewController.
         */
        if (!bestWindow &&
            window.rootViewController)
        {
            bestWindow = window;
        }
    }

    return bestWindow;
}

#pragma mark - Scale

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

    UIView *view =
        root.view;

    if (!view)
        return;

    CGRect bounds =
        window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 ||
        height <= 0.0)
    {
        return;
    }

    /*
     * Chỉ scale khi view thực sự là UI chính.
     */
    if (view.superview == nil &&
        window.superview != nil)
    {
        return;
    }

    /*
     * Luôn reset trước khi tính lại.
     * Điều này rất quan trọng khi xoay màn hình.
     */
    view.transform =
        CGAffineTransformIdentity;

    /*
     * Đảm bảo anchor nằm giữa.
     */
    view.layer.anchorPoint =
        CGPointMake(0.5, 0.5);

    CGPoint center =
        CGPointMake(
            CGRectGetMidX(bounds),
            CGRectGetMidY(bounds)
        );

    /*
     * Portrait
     *
     * Chiều cao khả dụng:
     *
     *     height - 34 - 34
     *
     * Scale theo chiều cao.
     */
    if (height > width)
    {
        CGFloat availableHeight =
            height -
            (SC16_CROP * 2.0);

        if (availableHeight <= 0.0)
            return;

        CGFloat scale =
            availableHeight / height;

        if (scale <= 0.0 ||
            scale >= 1.0)
        {
            return;
        }

        view.center = center;

        view.transform =
            CGAffineTransformMakeScale(
                scale,
                scale
            );

        /*
         * Sau transform, giữ tâm chính xác
         * ở giữa màn hình.
         */
        view.center = center;
    }

    /*
     * Landscape
     *
     * Chiều rộng khả dụng:
     *
     *     width - 34 - 34
     *
     * Scale theo chiều rộng.
     *
     * Đây là phần quan trọng để tránh UI
     * bị lệch khi xoay ngang.
     */
    else
    {
        CGFloat availableWidth =
            width -
            (SC16_CROP * 2.0);

        if (availableWidth <= 0.0)
            return;

        CGFloat scale =
            availableWidth / width;

        if (scale <= 0.0 ||
            scale >= 1.0)
        {
            return;
        }

        view.center = center;

        view.transform =
            CGAffineTransformMakeScale(
                scale,
                scale
            );

        /*
         * Giữ chính xác tâm màn hình.
         */
        view.center = center;
    }
}

#pragma mark - Apply Scene

static void SC16ApplyScene(UIWindowScene *scene)
{
    if (!SC16Enabled())
        return;

    if (!scene)
        return;

    if (scene.activationState ==
        UISceneActivationStateUnattached)
    {
        return;
    }

    /*
     * Chỉ lấy window chính của scene.
     *
     * Không quét UIApplication.windows.
     * Không transform toàn bộ UIWindow.
     */
    UIWindow *window =
        SC16MainWindowForScene(scene);

    if (!window)
        return;

    SC16ApplyScale(window);
}

#pragma mark - Apply All SpringBoard Scenes

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

#pragma mark - Delayed Apply

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAllScenes();

            /*
             * UIKit có thể tiếp tục thay đổi
             * window/root view sau khi SpringBoard
             * vừa khởi tạo.
             */
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
                    SC16ApplyAllScenes();
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
                    SC16ApplyAllScenes();
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
                    SC16ApplyAllScenes();
                }
            );
        }
    );
}

#pragma mark - UIWindow Hooks

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

- (void)setBounds:(CGRect)bounds
{
    %orig(bounds);

    if (!SC16Enabled())
        return;

    /*
     * Khi xoay màn hình hoặc thay đổi resolution,
     * tính lại scale.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyScale(self);
        }
    );
}

%end

#pragma mark - Orientation

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated
{
    %orig(animated);

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
        /*
         * Cực kỳ quan trọng:
         *
         * Tweak chỉ hoạt động trong SpringBoard.
         *
         * App bên thứ ba:
         *   return
         *
         * Keyboard:
         *   không transform
         *
         * Process khác:
         *   không transform
         */
        if (!SC16Enabled())
            return;

        SC16ScheduleApply();
    }
}
