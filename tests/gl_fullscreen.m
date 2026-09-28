#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
static CGDirectDisplayID display;
static int originalMode;
static NSApplicationPresentationOptions originalOptions;
static NSWindow *window(void){return [[[NSOpenGLContext currentContext] view] window];}
int test_gl_focus(void){[NSApp activateIgnoringOtherApps:YES];[window() makeKeyAndOrderFront:nil];return [NSApp isActive] && [window() isKeyWindow];}
int test_gl_desktop(int *w,int *h,int *hz){
 if(!display)display=[[[[window() screen] deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
 CGDisplayModeRef mode=CGDisplayCopyDisplayMode(display);if(!mode)return 0;
 *w=CGDisplayModeGetPixelWidth(mode);*h=CGDisplayModeGetPixelHeight(mode);*hz=(int)(CGDisplayModeGetRefreshRate(mode)+0.5);
 CFRelease(mode);return 1;
}
void test_gl_save_desktop(void){
 int w,h,hz;test_gl_desktop(&w,&h,&hz);
 CGDisplayModeRef mode=CGDisplayCopyDisplayMode(display);originalMode=CGDisplayModeGetIODisplayModeID(mode);CFRelease(mode);
 originalOptions=[NSApp presentationOptions];
}
int test_gl_restored(void){
 CGDisplayModeRef mode=CGDisplayCopyDisplayMode(display);if(!mode)return 0;
 int ok=CGDisplayModeGetIODisplayModeID(mode)==originalMode && !CGDisplayIsCaptured(display) && [NSApp presentationOptions]==originalOptions;
 CFRelease(mode);return ok;
}
void test_gl_minimize(void){[NSApp hide:nil];}
void test_gl_restore(void){[NSApp unhide:nil];}
