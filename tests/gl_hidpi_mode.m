#import <AppKit/AppKit.h>
/* Test only: exercise the documented one-pixel-per-point surface mode. */
void max2d_test_gl_lowdpi(void) {
    NSOpenGLContext *context = [NSOpenGLContext currentContext];
    [[context view] setWantsBestResolutionOpenGLSurface:NO];
    [context update];
}
