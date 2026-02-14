// Generates macmon app icon as an .icns file.
// Renders a stylized CPU graph matching the app's visual style.
#import <Cocoa/Cocoa.h>

static void render_icon(CGContextRef ctx, int size) {
    int w = size, h = size;

    // Rounded black background
    CGFloat radius = w * 0.18f;
    CGRect rect = CGRectMake(0, 0, w, h);
    CGPathRef path = CGPathCreateWithRoundedRect(rect, radius, radius, NULL);
    CGContextAddPath(ctx, path);
    CGContextClip(ctx);
    CGContextSetRGBFillColor(ctx, 0.0f, 0.0f, 0.0f, 1.0f);
    CGContextFillRect(ctx, rect);
    CGPathRelease(path);

    float pad = w * 0.12f;
    float area_w = w - pad * 2;
    float area_h = h - pad * 2;

    // A heartbeat / pulse waveform — clearly not real data
    // Flat baseline with two sharp spikes, like a vital signs monitor
    int n = 80;
    float lw = w * 0.02f;

    // Build the pulse shape
    float wave[80];
    for (int i = 0; i < n; i++) {
        float t = (float)i / (n - 1);
        wave[i] = 0.12f;  // baseline

        // First pulse: sharp spike at ~30%
        float d1 = (t - 0.28f);
        if (d1 > -0.06f && d1 < 0.0f)
            wave[i] = 0.12f + 0.75f * (1.0f + d1 / 0.06f);  // ramp up
        else if (d1 >= 0.0f && d1 < 0.03f)
            wave[i] = 0.87f - 1.1f * (d1 / 0.03f);  // sharp drop past baseline
        else if (d1 >= 0.03f && d1 < 0.06f)
            wave[i] = -0.23f + 0.35f * ((d1 - 0.03f) / 0.03f);  // bounce back

        // Second pulse: slightly smaller at ~60%
        float d2 = (t - 0.58f);
        if (d2 > -0.06f && d2 < 0.0f)
            wave[i] = 0.12f + 0.55f * (1.0f + d2 / 0.06f);
        else if (d2 >= 0.0f && d2 < 0.03f)
            wave[i] = 0.67f - 0.8f * (d2 / 0.03f);
        else if (d2 >= 0.03f && d2 < 0.06f)
            wave[i] = -0.13f + 0.25f * ((d2 - 0.03f) / 0.03f);

        // Clamp
        if (wave[i] < 0.0f) wave[i] = 0.0f;
        if (wave[i] > 1.0f) wave[i] = 1.0f;
    }

    // Soft glow: draw thick translucent line underneath
    CGContextSetRGBStrokeColor(ctx, 0.0f, 1.0f, 0.0f, 0.15f);
    CGContextSetLineWidth(ctx, lw * 5.0f);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    for (int i = 0; i < n; i++) {
        float x = pad + (area_w * i) / (n - 1);
        float y = pad + area_h * wave[i];
        if (i == 0) CGContextMoveToPoint(ctx, x, y);
        else        CGContextAddLineToPoint(ctx, x, y);
    }
    CGContextStrokePath(ctx);

    // Filled area under the curve
    CGContextSetRGBFillColor(ctx, 0.0f, 1.0f, 0.0f, 0.12f);
    CGContextMoveToPoint(ctx, pad, pad);
    for (int i = 0; i < n; i++) {
        float x = pad + (area_w * i) / (n - 1);
        float y = pad + area_h * wave[i];
        CGContextAddLineToPoint(ctx, x, y);
    }
    CGContextAddLineToPoint(ctx, pad + area_w, pad);
    CGContextClosePath(ctx);
    CGContextFillPath(ctx);

    // Main stroke
    CGContextSetRGBStrokeColor(ctx, 0.0f, 1.0f, 0.0f, 1.0f);
    CGContextSetLineWidth(ctx, lw);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    for (int i = 0; i < n; i++) {
        float x = pad + (area_w * i) / (n - 1);
        float y = pad + area_h * wave[i];
        if (i == 0) CGContextMoveToPoint(ctx, x, y);
        else        CGContextAddLineToPoint(ctx, x, y);
    }
    CGContextStrokePath(ctx);
}

static void write_png(int size, NSString *path) {
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(
        NULL, size, size, 8, size * 4, cs,
        (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);

    render_icon(ctx, size);

    CGImageRef img = CGBitmapContextCreateImage(ctx);
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:img];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [png writeToFile:path atomically:YES];
    CGImageRelease(img);
    CGContextRelease(ctx);
}

int main(void) {
    @autoreleasepool {
        // iconutil requires an .iconset directory with specific filenames
        NSString *iconset = @"macmon.iconset";
        [[NSFileManager defaultManager] createDirectoryAtPath:iconset
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        // Required sizes: 16,32,128,256,512 at 1x and 2x
        int sizes[] = { 16, 32, 128, 256, 512 };
        for (int i = 0; i < 5; i++) {
            int s = sizes[i];
            NSString *name1x = [NSString stringWithFormat:
                @"%@/icon_%dx%d.png", iconset, s, s];
            NSString *name2x = [NSString stringWithFormat:
                @"%@/icon_%dx%d@2x.png", iconset, s, s];
            write_png(s, name1x);
            write_png(s * 2, name2x);
        }

        NSLog(@"Generated %@", iconset);
    }
    return 0;
}
