#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>

#pragma mark - Configuration

/*
 * SCALE RIÊNG
 *
 * 0.96 = 96%
 */
static CGFloat const SC16_SCALE = 0.96;

/*
 * CROP RIÊNG
 *
 * Portrait  : 34px trên + 34px dưới
 * Landscape : 34px trái + 34px phải
 */
static CGFloat const SC16_CROP = 34.0;

static NSInteger const SC16_CROP_TAG = 0x5316;

#pragma mark - Process

static BOOL SC16Enabled(void)
{
    NSString *version =
        UIDevice.currentDevice.systemVersion;

    return [version hasPrefix:@"16."];
}

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    return [bundleID isEqualToString:
                @"com.apple.springboard"];
}

#pragma mark - Window Detection

static BOOL SC16IsKeyboardWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name =
        NSStringFromClass(window.class);

    return [name containsString:@"Keyboard"] ||
           [name containsString:@"UITextEffects"] ||
           [name containsString:@"UIRemoteKeyboard"] ||
           [name containsString:@"UIInput"];
}

static BOOL SC16IsSystemOverlayWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name =
        NSStringFromClass(window.class);

    return [name containsString:@"StatusBar"] ||
           [name containsString:@"_UIStatusBar"];
}

static BOOL SC16IsRootSceneWindow(UIWindow *window)
{
    if (!window)
        return NO;

    return [NSStringFromClass(window.class)
            isEqualToString:@"UIRootSceneWindow"];
}

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

    if (SC16IsSystemOverlayWindow(window))
        return NO;

    if (!window.rootViewController)
        return NO;

    return YES;
}

#pragma mark - Crop Overlay

static UIView *SC16FindCropOverlay(UIWindow *window)
{
    if (!window)
        return nil;

    for (UIView *view in window.subviews)
    {
        if (view.tag == SC16_CROP_TAG)
            return view;
    }

    return nil;
}

static UIView *SC16FindCropPart(
    UIView *overlay,
    NSInteger tag
)
{
    if (!overlay)
        return nil;

    for (UIView *view in overlay.subviews)
    {
        if (view.tag == tag)
            return view;
    }

    return nil;
}

/*
 * CROP HOÀN TOÀN ĐỘC LẬP VỚI SCALE.
 *
 * Không dùng layer.mask.
 * Không dùng transform.
 * Không thay frame của UIWindow.
 *
 * Vì vậy scale 96% sẽ không làm crop bị
 * 32.64px hoặc 35.xpx.
 */
static void SC16ApplyCrop(UIWindow *window)
{
    if (!window)
        return;

    if (SC16IsKeyboardWindow(window))
        return;

    if (SC16IsSystemOverlayWindow(window))
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

    UIView *overlay =
        SC16FindCropOverlay(window);

    if (!overlay)
    {
        overlay =
            [[UIView alloc] initWithFrame:bounds];

        overlay.tag =
            SC16_CROP_TAG;

        overlay.userInteractionEnabled =
            NO;

        overlay.backgroundColor =
            UIColor.clearColor;

        overlay.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        [window addSubview:overlay];
    }

    /*
     * Luôn đưa overlay lên trên nội dung.
     */
    [window bringSubviewToFront:overlay];

    overlay.frame =
        bounds;

    BOOL portrait =
        height >= width;

    UIView *first =
        SC16FindCropPart(
            overlay,
            SC16_CROP_TAG + 1
        );

    UIView *second =
        SC16FindCropPart(
            overlay,
            SC16_CROP_TAG + 2
        );

    if (!first)
    {
        first =
            [[UIView alloc] initWithFrame:CGRectZero];

        first.tag =
            SC16_CROP_TAG + 1;

        first.backgroundColor =
            UIColor.blackColor;

        first.userInteractionEnabled =
            NO;

        [overlay addSubview:first];
    }

    if (!second)
    {
        second =
            [[UIView alloc] initWithFrame:CGRectZero];

        second.tag =
            SC16_CROP_TAG + 2;

        second.backgroundColor =
            UIColor.blackColor;

        second.userInteractionEnabled =
            NO;

        [overlay addSubview:second];
    }

    if (portrait)
    {
        /*
         * DỌC:
         *
         * 34px trên
         * 34px dưới
         */
        first.frame =
            CGRectMake(
                0.0,
                0.0,
                width,
                SC16_CROP
            );

        second.frame =
            CGRectMake(
                0.0,
                height - SC16_CROP,
                width,
                SC16_CROP
            );
    }
    else
    {
        /*
         * NGANG:
         *
         * 34px trái
         * 34px phải
         */
        first.frame =
            CGRectMake(
                0.0,
                0.0,
                SC16_CROP,
                height
            );

        second.frame =
            CGRectMake(
                width - SC16_CROP,
                0.0,
                SC16_CROP,
                height
            );
    }
}

#pragma mark - Scale

/*
 * SCALE CHỈ SCALE.
 *
 * Không thay frame.
 * Không thay bounds.
 * Không thay center.
 * Không tính tx / ty.
 *
 * Transform của UIView lấy anchorPoint của
 * layer làm tâm. UIKit mặc định:
 *
 *     anchorPoint = (0.5, 0.5)
 *
 * nên 96% sẽ thu đúng vào giữa.
 */
static void SC16ApplyScale(UIView *view)
{
    if (!view)
        return;

    CGRect bounds =
        view.bounds;

    if (CGRectGetWidth(bounds) <= 0.0 ||
        CGRectGetHeight(bounds) <= 0.0)
    {
        return;
    }

    /*
     * Đảm bảo scale quanh chính giữa view.
     */
    CALayer *layer =
        view.layer;

    if (layer)
    {
        if (fabs(layer.anchorPoint.x - 0.5) > 0.0001 ||
            fabs(layer.anchorPoint.y - 0.5) > 0.0001)
        {
            layer.anchorPoint =
                CGPointMake(0.5, 0.5);
        }
    }

    /*
     * SCALE 96%.
     *
     * Tuyệt đối không có translation.
     */
    view.transform =
        CGAffineTransformMakeScale(
            SC16_SCALE,
            SC16_SCALE
        );
}

#pragma mark - Root View

static UIView *SC16RootView(
    UIWindow *window
)
{
    if (!window)
        return nil;

    UIViewController *root =
        window.rootViewController;

    if (!root)
        return nil;

    return root.view;
}

#pragma mark - Apply Window

static void SC16ApplyWindow(
    UIWindow *window
)
{
    if (!SC16IsUsableWindow(window))
        return;

    UIView *rootView =
        SC16RootView(window);

    if (!rootView)
        return;

    /*
     * ------------------------------------
     * SCALE
     * ------------------------------------
     *
     * 96% vào tâm.
     */
    SC16ApplyScale(rootView);

    /*
     * ------------------------------------
     * CROP
     * ------------------------------------
     *
     * 34px, độc lập hoàn toàn với scale.
     */
    SC16ApplyCrop(window);
}

#pragma mark - Find SpringBoard Window

static UIWindow *SC16FindSpringBoardWindow(void)
{
    if (!SC16IsSpringBoard())
        return nil;

    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return nil;

    UIWindow *fallback =
        nil;

    for (UIScene *scene in
         application.connectedScenes)
    {
        if (![scene isKindOfClass:
                  [UIWindowScene class]])
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

        for (UIWindow *window in
             windowScene.windows)
        {
            if (!window)
                continue;

            if (window.hidden)
                continue;

            if (window.alpha <= 0.0)
                continue;

            if (SC16IsKeyboardWindow(window))
                continue;

            if (SC16IsSystemOverlayWindow(window))
                continue;

            if (SC16IsRootSceneWindow(window))
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

#pragma mark - Find Application Window

static UIWindow *SC16FindApplicationWindow(
    UIWindowScene *scene
)
{
    if (!scene)
        return nil;

    UIWindow *fallback =
        nil;

    for (UIWindow *window in scene.windows)
    {
        if (!SC16IsUsableWindow(window))
            continue;

        /*
         * Ưu tiên key window.
         */
        if (window.isKeyWindow)
        {
            return window;
        }

        if (!fallback)
        {
            fallback = window;
        }
    }

    return fallback;
}

#pragma mark - Apply All Scenes

static void SC16ApplyAll(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return;

    /*
     * SpringBoard.
     */
    if (SC16IsSpringBoard())
    {
        UIWindow *window =
            SC16FindSpringBoardWindow();

        if (window)
        {
            SC16ApplyWindow(window);
        }

        return;
    }

    /*
     * Ứng dụng.
     *
     * Mỗi UIWindowScene được xử lý riêng.
     */
    for (UIScene *scene in
         application.connectedScenes)
    {
        if (![scene isKindOfClass:
                  [UIWindowScene class]])
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

        UIWindow *window =
            SC16FindApplicationWindow(
                windowScene
            );

        if (window)
        {
            SC16ApplyWindow(window);
        }
    }
}

#pragma mark - Scheduling

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    static BOOL scheduled =
        NO;

    if (scheduled)
        return;

    scheduled =
        YES;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            scheduled =
                NO;

            SC16ApplyAll();
        }
    );
}

static void SC16ScheduleDelayed(
    NSTimeInterval delay
)
{
    if (!SC16Enabled())
        return;

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(
                delay *
                NSEC_PER_SEC
            )
        ),
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAll();
        }
    );
}

#pragma mark - UIWindow Hooks

%hook UIWindow

- (void)makeKeyAndVisible
{
    %orig;

    SC16ScheduleApply();
    SC16ScheduleDelayed(0.15);
    SC16ScheduleDelayed(0.50);
}

- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    SC16ScheduleApply();
    SC16ScheduleDelayed(0.15);
}

- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!hidden)
    {
        SC16ScheduleApply();
        SC16ScheduleDelayed(0.15);
    }
}

%end

#pragma mark - UIViewController Hooks

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated
{
    %orig(animated);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
    SC16ScheduleDelayed(0.10);
}

- (void)viewDidLayoutSubviews
{
    %orig;

    if (!SC16Enabled())
        return;

    UIWindow *window =
        self.view.window;

    if (!window)
        return;

    /*
     * Chỉ xử lý root view.
     */
    if (window.rootViewController != self)
        return;

    if (!SC16IsUsableWindow(window))
        return;

    /*
     * UIKit có thể reset transform trong lúc
     * layout. Kiểm tra và phục hồi 96%.
     */
    CGAffineTransform wanted =
        CGAffineTransformMakeScale(
            SC16_SCALE,
            SC16_SCALE
        );

    if (!CGAffineTransformEqualToTransform(
            self.view.transform,
            wanted))
    {
        SC16ApplyScale(self.view);
    }

    /*
     * Crop cũng được cập nhật lại theo
     * kích thước window hiện tại.
     */
    SC16ApplyCrop(window);
}

- (void)viewWillTransitionToSize:
    (CGSize)size
    withTransitionCoordinator:
        (id<UIViewControllerTransitionCoordinator>)coordinator
{
    %orig(size, coordinator);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();

    [coordinator
        animateAlongsideTransition:nil
        completion:
        ^(id<UIViewControllerTransitionCoordinatorContext> context)
        {
            (void)context;

            SC16ScheduleApply();
            SC16ScheduleDelayed(0.10);
        }];
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
    SC16ScheduleDelayed(0.15);
}

- (void)sceneWillEnterForeground
{
    %orig;

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
    SC16ScheduleDelayed(0.15);
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
         * Đợi UIKit tạo xong UIWindow/Scene.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    0.50 *
                    NSEC_PER_SEC
                )
            ),
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAll();
            }
        );

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    1.50 *
                    NSEC_PER_SEC
                )
            ),
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAll();
            }
        );
    }
}
