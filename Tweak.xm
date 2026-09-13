#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * SCALE RIÊNG.
 *
 * 0.96 = 96%.
 */
static CGFloat const SC16_SCALE = 0.96;

/*
 * CROP RIÊNG.
 *
 * Portrait : 34pt trên + 34pt dưới.
 * Landscape: 34pt trái + 34pt phải.
 */
static CGFloat const SC16_CROP = 34.0;

static NSInteger const SC16_TAG = 0x5316;

#pragma mark - Process

static BOOL SC16Enabled(void)
{
    NSString *version = UIDevice.currentDevice.systemVersion;
    return [version hasPrefix:@"16."];
}

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    return [bundleID isEqualToString:@"com.apple.springboard"];
}

#pragma mark - Window Detection

static BOOL SC16IsKeyboardWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name = NSStringFromClass(window.class);

    return [name containsString:@"Keyboard"] ||
           [name containsString:@"UITextEffects"] ||
           [name containsString:@"UIRemoteKeyboard"] ||
           [name containsString:@"UIInput"];
}

static BOOL SC16IsSystemOverlayWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name = NSStringFromClass(window.class);

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

#pragma mark - Root View

static UIView *SC16RootViewForWindow(UIWindow *window)
{
    if (!window)
        return nil;

    UIViewController *root = window.rootViewController;
    if (!root)
        return nil;

    UIView *view = root.view;
    if (!view)
        return nil;

    return view;
}

#pragma mark - Scale

/*
 * SCALE CHỈ SCALE.
 *
 * Không thay frame / bounds / center.
 * Không tự tính tx / ty.
 *
 * UIView transform được áp dụng quanh anchorPoint của layer.
 * Root view được đưa anchorPoint về tâm trước khi scale.
 */
static void SC16ApplyScale(UIView *view)
{
    if (!view)
        return;

    CGRect bounds = view.bounds;

    if (CGRectGetWidth(bounds) <= 0.0 ||
        CGRectGetHeight(bounds) <= 0.0)
    {
        return;
    }

    /*
     * Chỉ scale, không thay frame/bounds/center.
     *
     * UIView transform mặc định quay quanh anchorPoint
     * (0.5, 0.5) của root view, vì vậy tâm không bị
     * tự dịch bởi một tx/ty do tweak tính ra.
     */
    view.transform = CGAffineTransformMakeScale(
        SC16_SCALE,
        SC16_SCALE
    );
}

#pragma mark - Crop

/*
 * Crop là lớp riêng, KHÔNG dùng transform để tạo crop.
 *
 * Một overlay cố định ở ngoài cùng window tạo viền đen.
 * Vì overlay không nằm trong root view đã scale nên 34pt
 * luôn là 34pt trên màn hình, không bị nhân với 0.96.
 */
static UIView *SC16FindCropOverlay(UIWindow *window)
{
    if (!window)
        return nil;

    for (UIView *subview in window.subviews)
    {
        if (subview.tag == SC16_TAG)
            return subview;
    }

    return nil;
}

static void SC16ApplyCrop(UIWindow *window)
{
    if (!window)
        return;

    if (SC16IsKeyboardWindow(window))
        return;

    CGRect bounds = window.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    UIView *overlay = SC16FindCropOverlay(window);

    if (!overlay)
    {
        overlay = [[UIView alloc] initWithFrame:CGRectZero];
        overlay.tag = SC16_TAG;
        overlay.userInteractionEnabled = NO;
        overlay.backgroundColor = UIColor.clearColor;
        overlay.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        [window addSubview:overlay];
    }

    BOOL portrait = height >= width;

    CGRect topOrLeft;
    CGRect bottomOrRight;

    if (portrait)
    {
        topOrLeft = CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMinY(bounds),
            width,
            SC16_CROP
        );

        bottomOrRight = CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMaxY(bounds) - SC16_CROP,
            width,
            SC16_CROP
        );
    }
    else
    {
        topOrLeft = CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMinY(bounds),
            SC16_CROP,
            height
        );

        bottomOrRight = CGRectMake(
            CGRectGetMaxX(bounds) - SC16_CROP,
            CGRectGetMinY(bounds),
            SC16_CROP,
            height
        );
    }

    /*
     * Overlay có kích thước toàn màn hình.
     * Chỉ hai dải đen là nhìn thấy.
     */
    overlay.frame = bounds;

    /*
     * Dùng hai subview con thay vì layer.mask.
     * Không phá mask của app/root view.
     */
    UIView *first = nil;
    UIView *second = nil;

    for (UIView *subview in overlay.subviews)
    {
        if (subview.tag == SC16_TAG + 1)
            first = subview;
        else if (subview.tag == SC16_TAG + 2)
            second = subview;
    }

    if (!first)
    {
        first = [[UIView alloc] initWithFrame:CGRectZero];
        first.tag = SC16_TAG + 1;
        first.backgroundColor = UIColor.blackColor;
        [overlay addSubview:first];
    }

    if (!second)
    {
        second = [[UIView alloc] initWithFrame:CGRectZero];
        second.tag = SC16_TAG + 2;
        second.backgroundColor = UIColor.blackColor;
        [overlay addSubview:second];
    }

    first.frame = topOrLeft;
    second.frame = bottomOrRight;
}

#pragma mark - Apply Window

static void SC16ApplyWindow(UIWindow *window)
{
    if (!window)
        return;

    if (window.hidden || window.alpha <= 0.0)
        return;

    if (SC16IsKeyboardWindow(window))
        return;

    if (SC16IsSystemOverlayWindow(window))
        return;

    UIView *rootView = SC16RootViewForWindow(window);
    if (!rootView)
        return;

    /*
     * Scale nội dung trước.
     * Crop là overlay độc lập bên ngoài.
     */
    SC16ApplyScale(rootView);
    SC16ApplyCrop(window);
}

#pragma mark - Find Window

static UIWindow *SC16FindSpringBoardWindow(void)
{
    UIApplication *application = UIApplication.sharedApplication;
    if (!application)
        return nil;

    UIWindow *fallback = nil;

    for (UIScene *scene in application.connectedScenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;

        if (windowScene.activationState ==
            UISceneActivationStateUnattached)
        {
            continue;
        }

        for (UIWindow *window in windowScene.windows)
        {
            if (!window || window.hidden || window.alpha <= 0.0)
                continue;

            if (SC16IsKeyboardWindow(window) ||
                SC16IsSystemOverlayWindow(window))
            {
                continue;
            }

            if (SC16IsRootSceneWindow(window))
                return window;

            if (!fallback && window.rootViewController)
                fallback = window;
        }
    }

    return fallback;
}

static UIWindow *SC16FindApplicationWindow(UIWindowScene *scene)
{
    if (!scene)
        return nil;

    UIWindow *fallback = nil;

    for (UIWindow *window in scene.windows)
    {
        if (!window || window.hidden || window.alpha <= 0.0)
            continue;

        if (SC16IsKeyboardWindow(window) ||
            SC16IsSystemOverlayWindow(window))
        {
            continue;
        }

        if (!window.rootViewController)
            continue;

        if (window.isKeyWindow)
            return window;

        if (!fallback)
            fallback = window;
    }

    return fallback;
}

#pragma mark - Apply All

static void SC16ApplyAll(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *application = UIApplication.sharedApplication;
    if (!application)
        return;

    if (SC16IsSpringBoard())
    {
        UIWindow *window = SC16FindSpringBoardWindow();
        if (window)
            SC16ApplyWindow(window);
        return;
    }

    for (UIScene *scene in application.connectedScenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;

        if (windowScene.activationState ==
            UISceneActivationStateUnattached)
        {
            continue;
        }

        UIWindow *window =
            SC16FindApplicationWindow(windowScene);

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

    dispatch_async(dispatch_get_main_queue(), ^{
        scheduled = NO;
        SC16ApplyAll();
    });
}

static void SC16ScheduleApplyAfter(NSTimeInterval delay)
{
    if (!SC16Enabled())
        return;

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(delay * NSEC_PER_SEC)
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
    SC16ScheduleApplyAfter(0.15);
}

- (void)setRootViewController:(UIViewController *)rootViewController
{
    %orig(rootViewController);

    SC16ScheduleApply();
    SC16ScheduleApplyAfter(0.15);
}

- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!hidden)
        SC16ScheduleApply();
}

%end

#pragma mark - UIViewController Hooks

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated
{
    %orig(animated);

    if (SC16Enabled())
    {
        SC16ScheduleApply();
        SC16ScheduleApplyAfter(0.10);
    }
}

- (void)viewDidLayoutSubviews
{
    %orig;

    if (!SC16Enabled())
        return;

    UIWindow *window = self.view.window;

    if (!window || window.rootViewController != self)
        return;

    if (SC16IsKeyboardWindow(window) ||
        SC16IsSystemOverlayWindow(window))
    {
        return;
    }

    /*
     * UIKit có thể reset transform trong quá trình layout.
     * Re-apply chỉ cho root view của window mục tiêu.
     */
    if (!CGAffineTransformEqualToTransform(
            self.view.transform,
            CGAffineTransformMakeScale(
                SC16_SCALE,
                SC16_SCALE)))
    {
        SC16ApplyScale(self.view);
    }
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:
           (id<UIViewControllerTransitionCoordinator>)coordinator
{
    %orig(size, coordinator);

    if (SC16Enabled())
    {
        SC16ScheduleApply();

        [coordinator animateAlongsideTransition:nil
                                      completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            SC16ScheduleApply();
        }];
    }
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        if (!SC16Enabled())
            return;

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(0.50 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAll();
            }
        );
    }
}
