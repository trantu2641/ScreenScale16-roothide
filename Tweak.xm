#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Khoảng cắt mỗi cạnh.
 *
 * Portrait:
 *   trên 34
 *   dưới 34
 *
 * Landscape:
 *   trái 34
 *   phải 34
 *
 * Đây là CẮT vùng hiển thị, không phải cộng thêm kích thước.
 */
static const CGFloat SC16_CROP = 34.0;

#pragma mark - Process

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;

    return [bundleID isEqualToString:@"com.apple.springboard"];
}

/*
 * Chỉ cho phép process ứng dụng thật.
 *
 * Không inject/scale:
 *   - daemon
 *   - extension
 *   - keyboard
 *   - các process hệ thống khác
 *
 * SpringBoard được xử lý riêng.
 */
static BOOL SC16IsApplicationProcess(void)
{
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

    return [version hasPrefix:@"16."];
}

#pragma mark - Geometry

/*
 * Tính scale để phần nội dung sau khi scale
 * nằm trong vùng đã bỏ SC16_CROP ở hai cạnh.
 *
 * Portrait:
 *   height -> height - 2 * crop
 *
 * Landscape:
 *   width -> width - 2 * crop
 */
static CGFloat SC16ScaleForSize(CGSize size)
{
    CGFloat width = size.width;
    CGFloat height = size.height;

    if (width <= 0.0 || height <= 0.0)
        return 1.0;

    if (height > width)
    {
        CGFloat availableHeight =
            height - (SC16_CROP * 2.0);

        if (availableHeight <= 0.0)
            return 1.0;

        return availableHeight / height;
    }

    CGFloat availableWidth =
        width - (SC16_CROP * 2.0);

    if (availableWidth <= 0.0)
        return 1.0;

    return availableWidth / width;
}

static void SC16ResetWindowTransform(UIWindow *window)
{
    if (!window)
        return;

    if (!CGAffineTransformIsIdentity(window.transform))
        window.transform = CGAffineTransformIdentity;
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

/*
 * Không đụng những window kỹ thuật của UIKit.
 */
static BOOL SC16IsUsableWindow(UIWindow *window)
{
    if (!window)
        return NO;

    if (window.hidden)
        return NO;

    if (window.alpha <= 0.0)
        return NO;

    if (SC16IsKeyboardWindow(window))
        return NO;

    return YES;
}

#pragma mark - Transform

/*
 * Scale quanh đúng tâm của window.
 *
 * Không thay frame.
 * Không thay bounds.
 * Không sửa rootView.
 *
 * Đây là điểm quan trọng để tránh phá layout
 * và tránh recursion.
 */
static void SC16ApplyCenteredTransform(
    UIWindow *window,
    CGFloat scale
)
{
    if (!window)
        return;

    if (scale <= 0.0 || scale >= 1.0)
    {
        SC16ResetWindowTransform(window);
        return;
    }

    /*
     * Chỉ transform.
     *
     * Không gọi:
     *   setFrame:
     *   setBounds:
     *   rootView.transform
     *   rootView.frame
     *
     * để tránh vòng lặp layout.
     */
    window.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );
}

#pragma mark - SpringBoard

/*
 * Scale system UI của SpringBoard.
 *
 * Đây là phần system-wide.
 *
 * Không áp dụng cho mọi process.
 * Chỉ chạy khi bundle = SpringBoard.
 */
static void SC16ScaleSpringBoardWindow(
    UIWindow *window
)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    if (!SC16IsUsableWindow(window))
        return;

    /*
     * Status bar và AssistiveTouch được giữ trong
     * cùng hệ tọa độ scale.
     */
    CGRect bounds = window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    /*
     * Với các window system nhỏ/đặc biệt,
     * không tự ý biến đổi vị trí của chúng.
     *
     * Chỉ scale window quanh tâm của chính nó.
     */
    CGFloat scale =
        SC16ScaleForSize(bounds.size);

    if (scale >= 1.0)
    {
        SC16ResetWindowTransform(window);
        return;
    }

    SC16ApplyCenteredTransform(
        window,
        scale
    );
}

#pragma mark - Application

/*
 * App UI.
 *
 * Chỉ chạy trong process app thật.
 *
 * Không transform từng subview.
 * Không transform rootView.
 *
 * Transform trực tiếp window giúp toàn bộ UI
 * trong window đi cùng một tỷ lệ.
 */
static void SC16ScaleApplicationWindow(
    UIWindow *window
)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsApplicationProcess())
        return;

    if (!SC16IsUsableWindow(window))
        return;

    /*
     * Không scale keyboard.
     */
    if (SC16IsKeyboardWindow(window))
        return;

    CGRect bounds =
        window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    CGFloat scale =
        SC16ScaleForSize(bounds.size);

    if (scale >= 1.0)
    {
        SC16ResetWindowTransform(window);
        return;
    }

    SC16ApplyCenteredTransform(
        window,
        scale
    );
}

#pragma mark - Scene

/*
 * Lấy windows từ UIWindowScene.
 *
 * Không dùng UIApplication.windows vì iOS 15+
 * đã deprecated.
 */
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
            SC16ScaleSpringBoardWindow(window);
        }
        else if (SC16IsApplicationProcess())
        {
            SC16ScaleApplicationWindow(window);
        }
    }
}

static void SC16ApplyAllScenes(void)
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

#pragma mark - Safe Refresh

/*
 * Chỉ refresh một lần ở main queue.
 *
 * Không gọi liên tục từ setFrame/setBounds.
 * Không gọi từ viewDidLayoutSubviews.
 */
static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAllScenes();
        }
    );
}

#pragma mark - UIWindow

%hook UIWindow

/*
 * Window vừa xuất hiện.
 */
- (void)makeKeyAndVisible
{
    %orig;

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

/*
 * Root VC thay đổi.
 */
- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

/*
 * Window hiện lại.
 */
- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!SC16Enabled())
        return;

    if (hidden)
        return;

    SC16ScheduleApply();
}

%end

#pragma mark - Scene Lifecycle

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
         * Chỉ chạy sau khi UIKit/SpringBoard
         * đã khởi tạo scene.
         */
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAllScenes();
            }
        );
    }
}
