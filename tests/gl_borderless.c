#include <windows.h>
#include <GL/gl.h>
int test_gl_borderless_covers_screen(void){
 HWND window=WindowFromDC(wglGetCurrentDC());
 RECT bounds;MONITORINFO monitor={0};monitor.cbSize=sizeof(monitor);
 if(!window || !GetWindowRect(window,&bounds) ||
  !GetMonitorInfo(MonitorFromWindow(window,MONITOR_DEFAULTTONEAREST),&monitor))return 0;
 return !(GetWindowLongPtr(window,GWL_STYLE)&WS_OVERLAPPEDWINDOW) &&
  EqualRect(&bounds,&monitor.rcMonitor);
}
