#import <Cocoa/Cocoa.h>
int test_gl_borderless_covers_screen(void){
 NSWindow *window=[[[NSOpenGLContext currentContext] view] window];
 return window && [window styleMask]==NSWindowStyleMaskBorderless &&
  NSEqualRects([window frame],[[window screen] frame]);
}

static NSApplicationPresentationOptions originalPresentation;
void test_gl_capture_presentation(void){originalPresentation=[NSApp presentationOptions];}
int test_gl_presentation_restored(void){return [NSApp presentationOptions]==originalPresentation;}
