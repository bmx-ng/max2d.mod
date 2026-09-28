#include "d3d9_fullscreen.cpp"
#include <GL/gl.h>
static int originalW,originalH,originalHz;
static HWND window(){return WindowFromDC(wglGetCurrentDC());}
extern "C" int test_gl_focus(){return m2d9_test_focus(window());}
extern "C" int test_gl_desktop(int *w,int *h,int *hz){return m2d9_test_desktop(window(),w,h,hz);}
extern "C" void test_gl_save_desktop(){test_gl_desktop(&originalW,&originalH,&originalHz);}
extern "C" int test_gl_restored(){int w,h,hz;return test_gl_desktop(&w,&h,&hz)&&w==originalW&&h==originalH&&hz==originalHz;}
extern "C" void test_gl_minimize(){ShowWindow(window(),SW_MINIMIZE);}
extern "C" void test_gl_restore(){ShowWindow(window(),SW_RESTORE);}
