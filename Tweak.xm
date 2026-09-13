#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * SCALE RIÊNG.
 *
 * 0.96 = 96%
 */
static CGFloat const SC16_SCALE = 0.96;

/*
 * CROP RIÊNG.
 *
 * Portrait:
 *     34px trên
 *     34px dưới
 *
 * Landscape:
 *     34px trái
 *     34px phải
 */
static CGFloat const SC16_CROP = 34.0;


/*
 * Tag dành riêng cho tweak.
 *
 * Dùng để không tạo overlay trùng.
 */
static NSInteger const SC16_CROP_TAG = 0x53433136;


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

    if ([name rangeOfString:@"Keyboard"
                    options:NSCaseInsensitiveSearch].location != NSNotFound)
        return YES;

    if ([name rangeOfString:@"UITextEffects"
                    options:NSCaseInsensitiveSearch].location != NSNotFound)
        return YES;

    if ([name rangeOfString:@"UIRemoteKeyboard"
                    options:NSCaseInsensitiveSearch].location != NSNotFound)
        return YES;

    if ([name rangeOfString:@"UIInput"
                    options:NSCaseInsensitiveSearch].location != NSNotFound)
        return YES;

    return NO;
}


static BOOL SC16IsStatusBarWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name =
        NSStringFromClass(window.class);

    if ([name rangeOfString:@"StatusBar"
                    options:NSCaseInsensitiveSearch].location != NSNotFound)
        return YES;

    if ([name rangeOfString:@"UIStatusBar"
                    options:NSCaseInsensitiveSearch].location != NSNotFound)
        return YES;

    return NO;
}


static BOOL SC16IsSystemWindow(UIWindow *window)
{
    if (!window)
        return YES;

    if (SC16IsKeyboardWindow(window))
        return YES;

    if (SC16IsStatusBarWindow(window))
        return YES;

    return NO;
}


static BOOL SC16IsRootSceneWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *name =
        NSStringFromClass(window.class);

    return [name isEqualToString:
                @"UIRootSceneWindow"];
}


#pragma mark - Scale

/*
 * Scale ROOT VIEW.
 *
 * Chỉ scale.
 *
 * Không thay:
 *   frame
 *   bounds
 *   center
 */
static void SC16ApplyScale(UIView *view)
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

    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        scale = 1.0;
    }

    /*
     * Chỉ scale quanh anchorPoint mặc định
     * của root view.
     */
    view.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );
}


#pragma mark - Crop Overlay

/*
 * Tìm overlay crop hiện tại.
 */
static UIView *SC16FindCropOverlay(UIWindow *window)
{
    if (!window)
        return nil;

    UIView *overlay =
        [window viewWithTag:
                    SC16_CROP_TAG];

    return overlay;
}


/*
 * Xóa crop cũ.
 */
static void SC16RemoveCropOverlay(UIWindow *window)
{
    if (!window)
        return;

    UIView *overlay =
        SC16FindCropOverlay(window);

    if (overlay)
        [overlay removeFromSuperview];
}


/*
 * Tạo lại crop.
 *
 * KHÔNG dùng window.layer.mask.
 *
 * KHÔNG scale crop.
 *
 * Crop luôn = 34px.
 */
static void SC16ApplyCrop(UIWindow *window)
{
    if (!window)
        return;

    if (SC16IsSystemWindow(window))
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
     * Overlay cũ nếu có thì dùng lại.
     */
    UIView *overlay =
        SC16FindCropOverlay(window);

    if (!overlay)
    {
        overlay =
            [[UIView alloc]
                initWithFrame:CGRectZero];

        overlay.tag =
            SC16_CROP_TAG;

        overlay.backgroundColor =
            [UIColor clearColor];

        overlay.userInteractionEnabled =
            NO;

        overlay.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        /*
         * Overlay phải nằm trên root view.
         */
        [window addSubview:overlay];
    }


    overlay.frame =
        bounds;


    /*
     * Xóa hai thanh cũ.
     */
    for (UIView *subview in
         [overlay.subviews copy])
    {
        [subview removeFromSuperview];
    }


    CGFloat crop =
        SC16_CROP;

    BOOL portrait =
        height >= width;


    if (portrait)
    {
        /*
         * TOP
         */
        UIView *top =
            [[UIView alloc]
                initWithFrame:
                    CGRectMake(
                        0.0,
                        0.0,
                        width,
                        crop
                    )];

        top.backgroundColor =
            [UIColor blackColor];

        top.userInteractionEnabled =
            NO;

        [overlay addSubview:top];


        /*
         * BOTTOM
         */
        UIView *bottom =
            [[UIView alloc]
                initWithFrame:
                    CGRectMake(
                        0.0,
                        height - crop,
                        width,
                        crop
                    )];

        bottom.backgroundColor =
            [UIColor blackColor];

        bottom.userInteractionEnabled =
            NO;

        [overlay addSubview:bottom];
    }
    else
    {
        /*
         * LEFT
         */
        UIView *left =
            [[UIView alloc]
                initWithFrame:
                    CGRectMake(
                        0.0,
                        0.0,
                        crop,
                        height
                    )];

        left.backgroundColor =
            [UIColor blackColor];

        left.userInteractionEnabled =
            NO;

        [overlay addSubview:left];


        /*
         * RIGHT
         */
        UIView *right =
            [[UIView alloc]
                initWithFrame:
                    CGRectMake(
                        width - crop,
                        0.0,
                        crop,
                        height
                    )];

        right.backgroundColor =
            [UIColor blackColor];

        right.userInteractionEnabled =
            NO;

        [overlay addSubview:right];
    }
}


#pragma mark - Apply Window

static void SC16ApplyWindow(UIWindow *window)
{
    if (!window)
        return;

    if (window.hidden)
        return;

    if (window.alpha <= 0.0)
        return;

    if (SC16IsSystemWindow(window))
        return;


    /*
     * ==================================================
     * SPRINGBOARD
     * ==================================================
     *
     * Scale root window.
     */
    if (SC16IsSpringBoard())
    {
        /*
         * SpringBoard root window không nhất thiết
         * có rootViewController.
         *
         * Vì vậy xử lý trực tiếp window transform.
         */
        CGRect bounds =
            window.bounds;

        if (CGRectGetWidth(bounds) <= 0.0 ||
            CGRectGetHeight(bounds) <= 0.0)
        {
            return;
        }

        /*
         * Reset trước.
         */
        window.transform =
            CGAffineTransformIdentity;


        /*
         * Scale quanh tâm window.
         */
        CGFloat scale =
            SC16_SCALE;

        CGFloat centerX =
            CGRectGetMidX(bounds);

        CGFloat centerY =
            CGRectGetMidY(bounds);

        CGFloat tx =
            centerX * (1.0 - scale);

        CGFloat ty =
            centerY * (1.0 - scale);

        window.transform =
            CGAffineTransformMake(
                scale,
                0.0,
                0.0,
                scale,
                tx,
                ty
            );


        /*
         * Crop riêng.
         */
        SC16ApplyCrop(window);

        return;
    }


    /*
     * ==================================================
     * APPLICATION
     * ==================================================
     */

    UIViewController *root =
        window.rootViewController;

    if (!root)
        return;

    UIView *rootView =
        root.view;

    if (!rootView)
        return;


    /*
     * SCALE.
     *
     * Đây là phần app cần giữ lại.
     */
    SC16ApplyScale(rootView);


    /*
     * CROP.
     *
     * Hoàn toàn độc lập với scale.
     */
    SC16ApplyCrop(window);
}


#pragma mark - Find SpringBoard

static UIWindow *SC16FindSpringBoardWindow(void)
{
    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return nil;

    UIWindow *fallback = nil;

    for (UIScene *scene in
         application.connectedScenes)
    {
        if (![scene
              isKindOfClass:
                  [UIWindowScene class]])
        {
            continue;
        }

        UIWindowScene *sceneWindow =
            (UIWindowScene *)scene;

        if (sceneWindow.activationState ==
            UISceneActivationStateUnattached)
        {
            continue;
        }

        for (UIWindow *window in
             sceneWindow.windows)
        {
            if (!window)
                continue;

            if (window.hidden)
                continue;

            if (window.alpha <= 0.0)
                continue;

            if (SC16IsSystemWindow(window))
                continue;


            /*
             * UIRootSceneWindow ưu tiên.
             */
            if (SC16IsRootSceneWindow(window))
                return window;


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

    UIWindow *normalWindow = nil;
    UIWindow *keyWindow = nil;

    for (UIWindow *window in
         scene.windows)
    {
        if (!window)
            continue;

        if (window.hidden)
            continue;

        if (window.alpha <= 0.0)
            continue;

        if (SC16IsSystemWindow(window))
            continue;

        if (!window.rootViewController)
            continue;


        /*
         * Chỉ lấy window level bình thường.
         *
         * Tránh đụng:
         *   UIAlert
         *   keyboard
         *   system overlay
         */
        if (window.windowLevel !=
            UIWindowLevelNormal)
        {
            continue;
        }


        if (window.isKeyWindow)
        {
            keyWindow = window;
            break;
        }

        if (!normalWindow)
            normalWindow = window;
    }


    if (keyWindow)
        return keyWindow;

    return normalWindow;
}


#pragma mark - Apply All

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
            SC16ApplyWindow(window);

        return;
    }


    /*
     * Application.
     */
    for (UIScene *scene in
         application.connectedScenes)
    {
        if (![scene
              isKindOfClass:
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
            SC16ApplyWindow(window);
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

            SC16ApplyAll();
        }
    );
}


static void SC16ScheduleApplyAfter(
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

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();

    /*
     * App thường hoàn tất layout sau makeKeyAndVisible.
     */
    SC16ScheduleApplyAfter(0.10);
    SC16ScheduleApplyAfter(0.30);
}


- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();

    SC16ScheduleApplyAfter(0.10);
}


- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!SC16Enabled())
        return;

    if (!hidden)
        SC16ScheduleApply();
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
    SC16ScheduleApplyAfter(0.10);
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
     * Chỉ root VC của window mục tiêu.
     */
    if (window.rootViewController != self)
        return;

    if (SC16IsSystemWindow(window))
        return;


    /*
     * App có thể reset transform trong layout.
     *
     * Re-apply SCALE.
     */
    UIView *view =
        self.view;

    if (!view)
        return;

    CGAffineTransform expected =
        CGAffineTransformMakeScale(
            SC16_SCALE,
            SC16_SCALE
        );

    if (!CGAffineTransformEqualToTransform(
            view.transform,
            expected))
    {
        SC16ApplyScale(view);
    }


    /*
     * Crop cũng được kiểm tra lại.
     *
     * Điều này giúp app không mất crop sau
     * khi layout/root view thay đổi.
     */
    UIView *overlay =
        SC16FindCropOverlay(window);

    if (!overlay ||
        overlay.frame.size.width !=
            window.bounds.size.width ||
        overlay.frame.size.height !=
            window.bounds.size.height)
    {
        SC16ApplyCrop(window);
    }
}


- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:
           (id<UIViewControllerTransitionCoordinator>)coordinator
{
    %orig(
        size,
        coordinator
    );

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();

    [coordinator animateAlongsideTransition:
        nil
        completion:
        ^(id<UIViewControllerTransitionCoordinatorContext> context)
        {
            SC16ScheduleApply();
            SC16ScheduleApplyAfter(0.10);
        }
    ];
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
         * Chờ UIKit/Scene khởi tạo hoàn chỉnh.
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
    }
}
