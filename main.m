#import <Cocoa/Cocoa.h>
#import <mach/mach_host.h>
#import <mach/processor_info.h>
#import <mach/vm_map.h>

// ============================================================================
// Constants
// ============================================================================

#define MAX_CPUS     128
#define HISTORY_LEN  64
#define ICON_PTS     128
#define ICON_PX      256
#define UPDATE_SEC   1.0

typedef enum { DisplayModeAggregate, DisplayModePerCore } DisplayMode;

// ============================================================================
// CPU State
// ============================================================================

typedef struct {
    natural_t user;
    natural_t system;
    natural_t idle;
    natural_t nice;
} CPUTicks;

typedef struct {
    unsigned int num_cpus;
    CPUTicks prev[MAX_CPUS];
    CPUTicks curr[MAX_CPUS];
    float    usage[MAX_CPUS]; // per-core 0.0–1.0
    float    aggregate;       // overall  0.0–1.0
} CPUState;

static void sample_cpu(CPUState *state) {
    processor_info_array_t cpuInfo;
    mach_msg_type_number_t numCpuInfo;
    natural_t numCPUs = 0;

    kern_return_t err = host_processor_info(
        mach_host_self(),
        PROCESSOR_CPU_LOAD_INFO,
        &numCPUs,
        &cpuInfo,
        &numCpuInfo
    );
    if (err != KERN_SUCCESS) return;

    if (numCPUs > MAX_CPUS) numCPUs = MAX_CPUS;
    state->num_cpus = numCPUs;

    memcpy(state->prev, state->curr, sizeof(CPUTicks) * numCPUs);

    float total_in_use = 0.0f, total_all = 0.0f;

    for (unsigned i = 0; i < numCPUs; i++) {
        state->curr[i].user   = cpuInfo[CPU_STATE_MAX * i + CPU_STATE_USER];
        state->curr[i].system = cpuInfo[CPU_STATE_MAX * i + CPU_STATE_SYSTEM];
        state->curr[i].idle   = cpuInfo[CPU_STATE_MAX * i + CPU_STATE_IDLE];
        state->curr[i].nice   = cpuInfo[CPU_STATE_MAX * i + CPU_STATE_NICE];

        natural_t du = state->curr[i].user   - state->prev[i].user;
        natural_t ds = state->curr[i].system - state->prev[i].system;
        natural_t di = state->curr[i].idle   - state->prev[i].idle;
        natural_t dn = state->curr[i].nice   - state->prev[i].nice;

        float in_use = (float)(du + ds + dn);
        float total  = in_use + (float)di;

        state->usage[i] = (total > 0) ? (in_use / total) : 0.0f;
        total_in_use += in_use;
        total_all    += total;
    }

    state->aggregate = (total_all > 0) ? (total_in_use / total_all) : 0.0f;

    vm_deallocate(mach_task_self(), (vm_address_t)cpuInfo,
                  sizeof(integer_t) * numCpuInfo);
}

// ============================================================================
// Color helpers
// ============================================================================

static void usage_color(float u, CGFloat *r, CGFloat *g, CGFloat *b) {
    // green → yellow → red
    if (u < 0.5f) {
        *r = u * 2.0f;
        *g = 1.0f;
    } else {
        *r = 1.0f;
        *g = 1.0f - (u - 0.5f) * 2.0f;
    }
    *b = 0.0f;
}

// ============================================================================
// Rendering
// ============================================================================

static void draw_rounded_bg(CGContextRef ctx, int w, int h) {
    CGFloat radius = w * 0.12f;
    CGRect rect = CGRectMake(0, 0, w, h);
    CGPathRef path = CGPathCreateWithRoundedRect(rect, radius, radius, NULL);
    CGContextAddPath(ctx, path);
    CGContextClip(ctx);
    CGContextSetRGBFillColor(ctx, 0.1f, 0.1f, 0.1f, 1.0f);
    CGContextFillRect(ctx, rect);
    CGPathRelease(path);
}

static void draw_gridlines(CGContextRef ctx, int w, float pad_bottom, float graph_h) {
    CGContextSetRGBStrokeColor(ctx, 0.3f, 0.3f, 0.3f, 0.4f);
    CGContextSetLineWidth(ctx, 1.0f);
    for (int i = 1; i <= 3; i++) {
        float y = pad_bottom + graph_h * (i / 4.0f);
        CGContextMoveToPoint(ctx, 0, y);
        CGContextAddLineToPoint(ctx, w, y);
        CGContextStrokePath(ctx);
    }
}

static NSImage *render_aggregate(float *history) {
    int w = ICON_PX, h = ICON_PX;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(
        NULL, w, h, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);

    draw_rounded_bg(ctx, w, h);

    float pad = w * 0.08f;
    float graph_w = w - pad * 2;
    float graph_h = h - pad * 2;

    draw_gridlines(ctx, w, pad, graph_h);

    // filled area
    CGContextSetRGBFillColor(ctx, 0.0f, 1.0f, 0.0f, 0.3f);
    CGContextMoveToPoint(ctx, pad, pad);
    for (int i = 0; i < HISTORY_LEN; i++) {
        float x = pad + (graph_w * i) / (HISTORY_LEN - 1);
        float y = pad + graph_h * history[i];
        CGContextAddLineToPoint(ctx, x, y);
    }
    CGContextAddLineToPoint(ctx, pad + graph_w, pad);
    CGContextClosePath(ctx);
    CGContextFillPath(ctx);

    // stroke line
    CGContextSetRGBStrokeColor(ctx, 0.0f, 1.0f, 0.0f, 1.0f);
    CGContextSetLineWidth(ctx, 3.0f);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    for (int i = 0; i < HISTORY_LEN; i++) {
        float x = pad + (graph_w * i) / (HISTORY_LEN - 1);
        float y = pad + graph_h * history[i];
        if (i == 0) CGContextMoveToPoint(ctx, x, y);
        else        CGContextAddLineToPoint(ctx, x, y);
    }
    CGContextStrokePath(ctx);

    CGImageRef cgImg = CGBitmapContextCreateImage(ctx);
    NSImage *img = [[NSImage alloc] initWithCGImage:cgImg
                                               size:NSMakeSize(ICON_PTS, ICON_PTS)];
    CGImageRelease(cgImg);
    CGContextRelease(ctx);
    return img;
}

static NSImage *render_per_core(CPUState *state) {
    int w = ICON_PX, h = ICON_PX;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(
        NULL, w, h, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);

    draw_rounded_bg(ctx, w, h);

    float pad = w * 0.08f;
    float area_w = w - pad * 2;
    float area_h = h - pad * 2;
    unsigned n = state->num_cpus;
    if (n == 0) n = 1;

    float gap = (n <= 16) ? 2.0f : 1.0f;
    float bar_w = (area_w - gap * (n - 1)) / n;
    if (bar_w < 1.0f) bar_w = 1.0f;

    for (unsigned i = 0; i < n; i++) {
        float x = pad + i * (bar_w + gap);
        float bar_h = area_h * state->usage[i];
        if (bar_h < 1.0f && state->usage[i] > 0.01f) bar_h = 1.0f;

        CGFloat r, g, b;
        usage_color(state->usage[i], &r, &g, &b);
        CGContextSetRGBFillColor(ctx, r, g, b, 0.9f);
        CGContextFillRect(ctx, CGRectMake(x, pad, bar_w, bar_h));
    }

    CGImageRef cgImg = CGBitmapContextCreateImage(ctx);
    NSImage *img = [[NSImage alloc] initWithCGImage:cgImg
                                               size:NSMakeSize(ICON_PTS, ICON_PTS)];
    CGImageRelease(cgImg);
    CGContextRelease(ctx);
    return img;
}

// ============================================================================
// App Delegate
// ============================================================================

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    CPUState    _cpuState;
    float       _history[HISTORY_LEN];
    DisplayMode _mode;
    NSTimer    *_timer;
}
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    (void)note;
    memset(&_cpuState, 0, sizeof(_cpuState));
    memset(_history,   0, sizeof(_history));
    _mode = DisplayModeAggregate;

    // Two samples so deltas are valid on first render
    sample_cpu(&_cpuState);
    usleep(100000); // 100ms
    sample_cpu(&_cpuState);
    _history[HISTORY_LEN - 1] = _cpuState.aggregate;

    [self updateIcon];

    _timer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_SEC
                                              target:self
                                            selector:@selector(tick:)
                                            userInfo:nil
                                             repeats:YES];
    // Keep timer firing during event tracking (e.g. while dock menu is open)
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)tick:(NSTimer *)t {
    (void)t;
    sample_cpu(&_cpuState);
    memmove(_history, _history + 1, sizeof(float) * (HISTORY_LEN - 1));
    _history[HISTORY_LEN - 1] = _cpuState.aggregate;
    [self updateIcon];
}

- (void)updateIcon {
    NSImage *icon;
    if (_mode == DisplayModeAggregate) {
        icon = render_aggregate(_history);
    } else {
        icon = render_per_core(&_cpuState);
    }
    [NSApp setApplicationIconImage:icon];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)app
                    hasVisibleWindows:(BOOL)flag {
    (void)app; (void)flag;
    _mode = (_mode == DisplayModeAggregate) ? DisplayModePerCore
                                           : DisplayModeAggregate;
    [self updateIcon];
    return NO;
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
    (void)sender;
    NSMenu *menu = [[NSMenu alloc] init];

    // CPU info (disabled)
    NSString *info = [NSString stringWithFormat:@"CPU: %.0f%% (%u cores)",
                      _cpuState.aggregate * 100.0f, _cpuState.num_cpus];
    NSMenuItem *infoItem = [[NSMenuItem alloc] initWithTitle:info
                                                      action:nil
                                               keyEquivalent:@""];
    [infoItem setEnabled:NO];
    [menu addItem:infoItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // Toggle
    NSString *toggleTitle = (_mode == DisplayModeAggregate)
        ? @"Show Per-Core" : @"Show Aggregate";
    NSMenuItem *toggleItem = [[NSMenuItem alloc] initWithTitle:toggleTitle
                                                        action:@selector(toggleMode:)
                                                 keyEquivalent:@""];
    [toggleItem setTarget:self];
    [menu addItem:toggleItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // Exit
    NSMenuItem *exitItem = [[NSMenuItem alloc] initWithTitle:@"Exit"
                                                      action:@selector(terminate:)
                                               keyEquivalent:@""];
    [menu addItem:exitItem];

    return menu;
}

- (void)toggleMode:(id)sender {
    (void)sender;
    _mode = (_mode == DisplayModeAggregate) ? DisplayModePerCore
                                           : DisplayModeAggregate;
    [self updateIcon];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    (void)sender;
    return NSTerminateNow;
}

@end

// ============================================================================
// Main
// ============================================================================

int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        AppDelegate *delegate = [[AppDelegate alloc] init];
        [NSApp setDelegate:delegate];
        [NSApp run];
    }
    return 0;
}
