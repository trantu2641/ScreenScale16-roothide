#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <math.h>

#pragma mark - Configuration

/*
 * ============================
 * SCALE — ĐỘC LẬP
 * ============================
 *
 * 0.96 = 96%
 */
static const CGFloat SC16_SCALE = 0.96;


/*
 * ============================
 * CROP — ĐỘC LẬP
 * ============================
 *
 * Portrait:
 *     34px trên
 *     34px dưới
 *
 * Landscape:
 *     34px trái
 *     34px phải
 *
 * Giá trị này KHÔNG phải scale.
 */
static const CGFloat SC16_CROP = 34.0;


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


static BOOL SC16IsAssistiveTouchWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name =
        NSStringFromClass(window.class);

    if ([name rangeOfString:@"AssistiveTouch"
                    options:NSCaseInsensitiveSearch].location != NSNotFound)
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


static BOOL SC16ShouldIgnoreWindow(UIWindow *window)
{
    if (!window)
        return YES;

    if (SC16IsKeyboardWindow(window))
        return YES;

    if (SC16IsStatusBarWindow(window))
        return YES;

    if (SC16IsAssistiveTouchWindow(window))
        return YES;

    return NO;
}


#pragma mark - Internal Windows

static NSArray<UIWindow *> *SC16GetInternalWindows(void)
{
    Class windowClass =
        objc_getClass("UIWindow");

    if (!windowClass)
        return @[];

    SEL selector =
        sel_registerName(
            "allWindowsIncludingInternalWindows:onlyVisibleWindows:"
        );

    if (![windowClass respondsToSelector:selector])
        return @[];

    NSArray *windows =
        ((NSArray *(*)(id, SEL, BOOL, BOOL))objc_msgSend)(
            windowClass,
            selector,
            YES,
            YES
        );

    if (![windows isKindOfClass:[NSArray class]])
        return @[];

    return windows;
}


#pragma mark - Geometry

/*
 * Scale quanh tâm WINDOW.
 *
 * SCALE hoàn toàn độc lập với CROP.
 */
static CGAffineTransform SC16ScaleTransform(
    CGRect bounds,
    CGFloat scale
)
{
    CGFloat centerX =
        CGRectGetMidX(bounds);

    CGFloat centerY =
        CGRectGetMidY(bounds);

    CGFloat tx =
        centerX * (1.0 - scale);

    CGFloat ty =
        centerY * (1.0 - scale);

    return CGAffineTransformMake(
        scale,
        0.0,
        0.0,
        scale,
        tx,
        ty
    );
}


#pragma mark - Crop Geometry

/*
 * CROP được định nghĩa độc lập là 34px.
 *
 * Lưu ý:
 * mask nằm trong local coordinate của window,
 * trong khi window đã scale.
 *
 * Vì vậy cần quy đổi hình học nội bộ để phần bị cắt
 * trên MÀN HÌNH vẫn tương ứng với SC16_CROP.
 *
 * Điều này KHÔNG thay đổi SC16_CROP và KHÔNG biến crop
 * thành một phần của scale.
 */
static CGRect SC16CropRect(
    CGRect bounds
)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0)
        scale = 1.0;

    CGFloat sourceCrop =
        SC16_CROP / scale;

    BOOL portrait =
        height >= width;

    if (portrait)
    {
        CGFloat available =
            height - 2.0 * sourceCrop;

        if (available <= 1.0)
            return CGRectZero;

        return CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMinY(bounds) + sourceCrop,
            width,
            available
        );
    }

    CGFloat available =
        width - 2.0 * sourceCrop;

    if (available <= 1.0)
        return CGRectZero;

    return CGRectMake(
        CGRectGetMinX(bounds) + sourceCrop,
        CGRectGetMinY(bounds),
        available,
        height
    );
}


#pragma mark - Crop Mask

static void SC16ApplyCropMask(
    UIWindow *window
)
{
    if (!window)
        return;

    CALayer *layer =
        window.layer;

    if (!layer)
        return;

    CGRect bounds =
        layer.bounds;

    if (CGRectGetWidth(bounds) <= 0.0 ||
        CGRectGetHeight(bounds) <= 0.0)
    {
        return;
    }

    /*
     * Nếu layer đã có mask không phải của chúng ta,
     * không phá mask hệ thống.
     */
    if (layer.mask &&
        ![layer.mask
          isKindOfClass:
              [CAShapeLayer class]])
    {
        return;
    }

    CAShapeLayer *mask = nil;

    if ([layer.mask
         isKindOfClass:
             [CAShapeLayer class]])
    {
        mask =
            (CAShapeLayer *)layer.mask;
    }
    else
    {
        mask =
            [CAShapeLayer layer];

        layer.mask =
            mask;
    }

    CGRect cropRect =
        SC16CropRect(bounds);

    if (CGRectIsEmpty(cropRect))
        return;

    mask.frame =
        bounds;

    CGPathRef path =
        CGPathCreateWithRect(
            cropRect,
            NULL
        );

    mask.path =
        path;

    CGPathRelease(path);
}


#pragma mark - Remove Our Crop

static void SC16RemoveCropMask(
    UIWindow *window
)
{
    if (!window)
        return;

    CALayer *layer =
        window.layer;

    if (!layer)
        return;

    if ([layer.mask
         isKindOfClass:
             [CAShapeLayer class]])
    {
        layer.mask = nil;
    }
}


#pragma mark - Apply Root Window

static void SC16ApplyRootWindow(
    UIWindow *window
)
{
    if (!window)
        return;

    if (window.hidden)
        return;

    if (window.alpha <= 0.0)
        return;

    if (SC16ShouldIgnoreWindow(window))
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
     * ============================
     * RESET
     * ============================
     *
     * Tránh transform chồng:
     *
     * 0.96
     * 0.9216
     * 0.884736
     * ...
     */
    window.transform =
        CGAffineTransformIdentity;


    /*
     * ============================
     * CROP
     * ============================
     *
     * Crop là thao tác riêng.
     */
    SC16ApplyCropMask(window);


    /*
     * ============================
     * SCALE
     * ============================
     *
     * Scale là thao tác riêng.
     *
     * Không thay frame.
     * Không thay bounds.
     * Không thay center.
     */
    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        scale = 1.0;
    }

    if (fabs(scale - 1.0) > 0.0001)
    {
        window.transform =
            SC16ScaleTransform(
                bounds,
                scale
            );
    }
}


#pragma mark - Find SpringBoard Root

static UIWindow *SC16FindRootWindow(void)
{
    if (!SC16IsSpringBoard())
        return nil;

    /*
     * Ưu tiên internal window.
     */
    NSArray<UIWindow *> *windows =
        SC16GetInternalWindows();

    UIWindow *fallback =
        nil;

    for (UIWindow *window in windows)
    {
        if (!window)
            continue;

        if (window.hidden)
            continue;

        if (window.alpha <= 0.0)
            continue;

        if (SC16ShouldIgnoreWindow(window))
            continue;

        if (SC16IsRootSceneWindow(window))
            return window;
    }


    /*
     * Fallback qua scene.
     */
    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return nil;

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

            if (SC16ShouldIgnoreWindow(window))
                continue;

            if (!window.rootViewController)
                continue;

            if (!fallback)
                fallback = window;
        }
    }

    return fallback;
}


#pragma mark - SpringBoard Apply

static void SC16ApplySpringBoard(void)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    UIWindow *rootWindow =
        SC16FindRootWindow();

    if (!rootWindow)
        return;

    /*
     * Chỉ scale ROOT WINDOW.
     *
     * Wallpaper/UI/overlay nằm trong cùng hierarchy
     * sẽ cùng di chuyển và cùng scale.
     */
    SC16ApplyRootWindow(
        rootWindow
    );
}


#pragma mark - Application Window

static UIWindow *SC16FindApplicationWindow(
    UIWindowScene *scene
)
{
    if (!scene)
        return nil;

    UIWindow *fallback =
        nil;

    for (UIWindow *window in
         scene.windows)
    {
        if (!window)
            continue;

        if (window.hidden)
            continue;

        if (window.alpha <= 0.0)
            continue;

        if (SC16ShouldIgnoreWindow(window))
            continue;

        if (!window.rootViewController)
            continue;

        if (window.isKeyWindow)
            return window;

        if (!fallback)
            fallback = window;
    }

    return fallback;
}


static void SC16ApplyApplicationScene(
    UIWindowScene *scene
)
{
    if (!scene)
        return;

    UIWindow *window =
        SC16FindApplicationWindow(scene);

    if (!window)
        return;

    SC16ApplyRootWindow(window);
}


#pragma mark - Scene

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

    if (SC16IsSpringBoard())
    {
        SC16ApplySpringBoard();
        return;
    }

    SC16ApplyApplicationScene(scene);
}


#pragma mark - Apply All

static void SC16ApplyAllScenes(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return;


    /*
     * SpringBoard chỉ xử lý root window một lần.
     */
    if (SC16IsSpringBoard())
    {
        SC16ApplySpringBoard();
        return;
    }


    /*
     * App bình thường.
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


- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!SC16Enabled())
        return;

    if (!hidden)
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


%end


#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        if (!SC16Enabled())
            return;

        /*
         * Chỉ chạy trong SpringBoard.
         */
        if (!SC16IsSpringBoard())
            return;


        /*
         * UIKit/SpringBoard cần thời gian tạo root window.
         */
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
                SC16ApplySpringBoard();
            }
        );


        /*
         * Re-apply sau khi SpringBoard hoàn tất layout.
         *
         * Mỗi lần đều reset transform trước,
         * nên không bị scale chồng.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    1.5 *
                    NSEC_PER_SEC
                )
            ),
            dispatch_get_main_queue(),
            ^{
                SC16ApplySpringBoard();
            }
        );


        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    3.0 *
                    NSEC_PER_SEC
                )
            ),
            dispatch_get_main_queue(),
            ^{
                SC16ApplySpringBoard();
            }
        );
    }
}
