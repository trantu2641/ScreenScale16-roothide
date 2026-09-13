#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <math.h>

#pragma mark - Configuration

/*
 * Scale toàn bộ màn hình.
 *
 * 0.90 = 90%
 */
static const CGFloat SC16_SCALE = 0.90;

/*
 * Crop thực tế ở mép màn hình.
 *
 * Portrait:
 *     8px trên
 *     8px dưới
 *
 * Landscape:
 *     8px trái
 *     8px phải
 */
static const CGFloat SC16_CROP = 8.0;


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


#pragma mark - Internal UIWindow Enumeration

/*
 * Lấy các UIWindow nội bộ của UIKit/SpringBoard.
 *
 * Không dùng connectedScenes làm nguồn duy nhất vì SpringBoard
 * có các window nội bộ không luôn xuất hiện theo cách thông thường.
 */
static NSArray<UIWindow *> *SC16InternalWindows(void)
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
 * Scale quanh đúng tâm của WINDOW.
 *
 * Không sử dụng frame.
 * Không thay bounds.
 * Không thay center.
 *
 * Công thức:
 *
 *     x' = center + scale * (x - center)
 *     y' = center + scale * (y - center)
 */
static CGAffineTransform SC16CenteredTransform(
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


#pragma mark - Crop

/*
 * Tạo vùng hiển thị trong tọa độ BEFORE transform.
 *
 * Vì scale = 0.90 nên:
 *
 *     sourceCrop = 8 / 0.90
 *
 * Sau khi transform:
 *
 *     sourceCrop * 0.90 = 8px
 */
static CGRect SC16CropRect(
    CGRect bounds,
    CGFloat scale
)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    CGFloat crop =
        SC16_CROP / scale;

    if (height >= width)
    {
        CGFloat maxCrop =
            MAX(0.0, (height - 1.0) * 0.5);

        crop =
            MIN(crop, maxCrop);

        return CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMinY(bounds) + crop,
            width,
            height - (crop * 2.0)
        );
    }

    CGFloat maxCrop =
        MAX(0.0, (width - 1.0) * 0.5);

    crop =
        MIN(crop, maxCrop);

    return CGRectMake(
        CGRectGetMinX(bounds) + crop,
        CGRectGetMinY(bounds),
        width - (crop * 2.0),
        height
    );
}


#pragma mark - Crop Mask

/*
 * Crop trên ROOT WINDOW.
 *
 * Không tạo mask cho từng subview/layer.
 * Không crop wallpaper riêng.
 */
static void SC16ApplyCrop(
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

    CGRect visible =
        SC16CropRect(
            bounds,
            scale
        );

    CAShapeLayer *mask =
        nil;

    if ([layer.mask
         isKindOfClass:
             [CAShapeLayer class]])
    {
        mask =
            (CAShapeLayer *)layer.mask;
    }
    else if (!layer.mask)
    {
        mask =
            [CAShapeLayer layer];

        layer.mask =
            mask;
    }
    else
    {
        /*
         * Nếu SpringBoard đã có mask riêng,
         * tuyệt đối không phá mask đó.
         */
        return;
    }

    mask.frame =
        bounds;

    CGPathRef path =
        CGPathCreateWithRect(
            visible,
            NULL
        );

    mask.path =
        path;

    CGPathRelease(path);
}


#pragma mark - Window State

/*
 * Lưu transform gốc của window để có thể phục hồi.
 */
static NSMutableDictionary *SC16OriginalTransforms(void)
{
    static NSMutableDictionary *dictionary = nil;

    static dispatch_once_t onceToken;

    dispatch_once(
        &onceToken,
        ^{
            dictionary =
                [NSMutableDictionary dictionary];
        }
    );

    return dictionary;
}


static NSString *SC16WindowKey(UIWindow *window)
{
    if (!window)
        return nil;

    return [NSString stringWithFormat:
                @"%p",
                window];
}


static void SC16RememberTransform(UIWindow *window)
{
    if (!window)
        return;

    NSString *key =
        SC16WindowKey(window);

    if (!key)
        return;

    NSMutableDictionary *dictionary =
        SC16OriginalTransforms();

    if (!dictionary[key])
    {
        dictionary[key] =
            [NSValue valueWithCGAffineTransform:
                window.transform];
    }
}


#pragma mark - Apply Root

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

    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        scale = 1.0;
    }

    /*
     * Chỉ lưu transform ban đầu một lần.
     */
    SC16RememberTransform(window);

    /*
     * QUAN TRỌNG:
     *
     * Reset trước khi tính transform.
     *
     * Không để:
     *
     *     0.90 -> 0.81 -> 0.729 ...
     */
    window.transform =
        CGAffineTransformIdentity;

    /*
     * Crop được thực hiện trong cùng hierarchy
     * với root window.
     */
    SC16ApplyCrop(window);

    /*
     * Scale quanh tâm thật của root window.
     */
    if (fabs(scale - 1.0) > 0.0001)
    {
        window.transform =
            SC16CenteredTransform(
                bounds,
                scale
            );
    }
}


#pragma mark - Find Root Window

static UIWindow *SC16FindRootWindow(void)
{
    if (!SC16IsSpringBoard())
        return nil;

    NSArray<UIWindow *> *windows =
        SC16InternalWindows();

    UIWindow *fallback =
        nil;

    /*
     * PASS 1:
     *
     * Tìm đúng UIRootSceneWindow.
     */
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
        {
            return window;
        }
    }

    /*
     * PASS 2:
     *
     * Fallback qua connectedScenes.
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


#pragma mark - Apply SpringBoard

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
     * CHỈ SCALE ROOT WINDOW.
     *
     * Không scale wallpaper window riêng.
     * Không scale status bar.
     * Không scale keyboard.
     * Không scale từng overlay.
     *
     * Như vậy toàn bộ hierarchy con vẫn nằm cùng
     * một hệ tọa độ.
     */
    SC16ApplyRootWindow(
        rootWindow
    );
}


#pragma mark - Application

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

        /*
         * Ưu tiên key window.
         */
        if (window.isKeyWindow)
        {
            return window;
        }

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

    SC16ApplyRootWindow(
        window
    );
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

    SC16ApplyApplicationScene(
        scene
    );
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
     * SpringBoard:
     *
     * Không chạy từng scene.
     * Chỉ tìm một root window duy nhất.
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
         * Chỉ chạy logic chính trong SpringBoard.
         */
        if (!SC16IsSpringBoard())
            return;

        /*
         * SpringBoard tạo window/scene theo nhiều giai đoạn.
         *
         * Chạy lại vài lần nhưng mỗi lần đều RESET transform
         * trước khi áp dụng nên không bị scale chồng.
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
