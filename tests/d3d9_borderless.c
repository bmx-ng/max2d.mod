#include <windows.h>
int test_d9_covers(HWND window){
 RECT bounds;MONITORINFO monitor={0};monitor.cbSize=sizeof(monitor);
 return GetWindowRect(window,&bounds) && GetMonitorInfo(MonitorFromWindow(window,MONITOR_DEFAULTTONEAREST),&monitor) &&
 !(GetWindowLongPtr(window,GWL_STYLE)&WS_OVERLAPPEDWINDOW) && EqualRect(&bounds,&monitor.rcMonitor);
}
