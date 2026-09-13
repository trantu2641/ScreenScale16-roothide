#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Bản gốc:
 *
 * 34px trên + 34px dưới
 * hoặc
 * 34px trái + 34px phải
 */
static CGFloat const SC16_CROP = 34.0;

/*
 * Scale bổ sung.
 *
 * 0.96 = 96%
 *
 * Crop và scale được tính riêng,
 * sau đó mới ghép thành một transform.
 */
static CGFloat const SC16_SCALE = 0.96;

#pragma mark - Process

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    return [bundleID isEqualToString:
                @"com.apple.springboard"];
}

static BOOL SC16Enabled(void)
{
    return [UIDevice.currentDevice.systemVersion
            hasPrefix:@"16."];
}

#pragma mark - Window Detection

static BOOL SC16IsIgnoredWindow(UIWindow *window)
{
    if (!window)
        return YES;

    if (window.hidden)
        return YES;

    if (window.alpha <= 0.0)
        return YES;

    NSString *name =
        NSStringFromClass(window.class);

    if ([name containsString:@"Keyboard"])
        return YES;

    if ([name containsString:@"UITextEffects"])
        return YES;

    if ([name containsString:@"UIRemoteKeyboard"])
        return YES;

    if ([name containsString:@"StatusBar"])
        return YES;

    if ([name containsString:@"_UIStatusBar"])
        return YES;

    return NO;
}

#pragma mark - Original Crop Calculation

/*
 * GIỮ NGUYÊN Ý TƯỞNG CỦA BẢN .DEB GỐC.
 *
 * Bản gốc dùng 68px tổng:
 *
 * 34px + 34px = 68px
 *
 * và biến phần còn lại thành tỉ lệ scale.
 */
static CGFloat SC16CropFactor(CGRect bounds)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 ||
        height <= 0.0)
    {
        return 1.0;
    }

    CGFloat cropTotal =
        SC16_CROP * 2.0;

    if (height > width)
    {
        /*
         * Portrait:
         *
         * 34px trên
         * 34px dưới
         */
        if (height <= cropTotal)
            return 1.0;

        return (height - cropTotal) / height;
    }

    /*
     * Landscape:
     *
     * 34px trái
     * 34px phải
     */
    if (width <= cropTotal)
        return 1.0;

    return (width - cropTotal) / width;
}

#pragma mark - Centered Transform

/*
 * Ghép:
 *
 *     CROP
 *       +
 *     SCALE 96%
 *
 * quanh đúng tâm của root view.
 *
 * Không dùng frame.
 * Không thay bounds.
 */
static CGAffineTransform SC16MakeTransform(
    CGRect bounds
)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    CGFloat cropFactor =
        SC16CropFactor(bounds);

    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        scale = 1.0;
    }

    /*
     * Crop của bản gốc.
     */
    CGFloat finalScale =
        cropFactor * scale;

    if (finalScale <= 0.0)
        finalScale = 1.0;

    CGFloat cx =
        CGRectGetMidX(bounds);

    CGFloat cy =
        CGRectGetMidY(bounds);

    /*
     * QUAN TRỌNG:
     *
     * Translation được tính theo
     * tâm bounds, nên nội dung luôn
     * nằm chính giữa.
     */
    CGFloat tx =
        cx * (1.0 - finalScale);

    CGFloat ty =
        cy * (1.0 - finalScale);

    return CGAffineTransformMake(
        finalScale,
        0.0,
        0.0,
        finalScale,
        tx,
        ty
    );
}

#pragma mark - Apply Root View

static void SC16ApplyRootView(
    UIView *view
)
{
    if (!view)
        return;

    CGRect bounds =
        view.bounds;

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
     * Reset trước mỗi lần áp dụng.
     *
     * Tránh transform bị nhân chồng
     * khi chuyển scene/app.
     */
    view.transform =
        CGAffineTransformIdentity;

    /*
     * Scale crop + 96%
     * quanh chính giữa root view.
     */
    view.transform =
        SC16MakeTransform(bounds);
}

#pragma mark - Apply Window

static void SC16ApplyWindow(
    UIWindow *window
)
{
    if (!window)
        return;

    if (SC16IsIgnoredWindow(window))
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
     * Chỉ xử lý ROOT VIEW.
     *
     * Không scale từng subview.
     * Không scale keyboard.
     */
    SC16ApplyRootView(rootView);
}

#pragma mark - Find Window

static UIWindow *SC16FindWindow(
    UIWindowScene *scene
)
{
    if (!scene)
        return nil;

    UIWindow *fallback = nil;

    for (UIWindow *window in scene.windows)
    {
        if (!window)
            continue;

        if (SC16IsIgnoredWindow(window))
            continue;

        if (!window.rootViewController)
            continue;

        /*
         * Key window ưu tiên.
         */
        if (window.isKeyWindow)
            return window;

        if (!fallback)
            fallback = window;
    }

    return fallback;
}

#pragma mark - Apply Scene

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

    UIWindow *window =
        SC16FindWindow(scene);

    if (!window)
        return;

    SC16ApplyWindow(window);
}

#pragma mark - Apply All Scenes

static void SC16ApplyAllScenes(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return;

    for (UIScene *scene in
         application.connectedScenes)
    {
        if (![scene
              isKindOfClass:
                  [UIWindowScene class]])
        {
            continue;
        }

        SC16ApplyScene(
            (UIWindowScene *)scene
        );
    }
}

#pragma mark - Scheduling

static void SC16ScheduleApply(void)
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

            SC16ApplyAllScenes();
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

    if (!hidden)
        SC16ScheduleApply();
}

- (void)setBounds:(CGRect)bounds
{
    %orig(bounds);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

- (void)setFrame:(CGRect)frame
{
    %orig(frame);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

%end

#pragma mark - UIViewController

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated
{
    %orig(animated);

    if (!SC16Enabled())
        return;

    /*
     * Khi vào app / chuyển màn hình,
     * áp dụng lại cho root window.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIWindow *window =
                self.view.window;

            if (!window)
                return;

            if (window.rootViewController != self)
                return;

            SC16ApplyWindow(window);
        }
    );
}

%end

#pragma mark - UIWindowScene Hooks

%hook UIWindowScene

- (void)sceneDidBecomeActive
{
    %orig;

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

- (void)sceneWillEnterForeground
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
         * Chờ UIKit dựng xong window/scene.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    0.8 *
                    NSEC_PER_SEC
                )
            ),
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAllScenes();
            }
        );
    }
}
