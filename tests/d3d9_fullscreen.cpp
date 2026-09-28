// Automated UI test only: synchronize with the foreground input queue while
// activating this test window. Production fullscreen code never steals focus.
#include <windows.h>
extern "C" int m2d9_test_focus(HWND window){
 DWORD current=GetCurrentThreadId();
 DWORD foreground=GetWindowThreadProcessId(GetForegroundWindow(),nullptr);
 bool attached=foreground&&foreground!=current&&AttachThreadInput(current,foreground,TRUE);
 SetForegroundWindow(window);
 if(attached)AttachThreadInput(current,foreground,FALSE);
 if(GetForegroundWindow()!=window){
  // The VM console can retain the foreground lock after exclusive exit.
  // Simulate an activation gesture only in this explicitly interactive test.
  INPUT input={};input.type=INPUT_KEYBOARD;input.ki.wVk=VK_MENU;
  SendInput(1,&input,sizeof(input));SetForegroundWindow(window);
  input.ki.dwFlags=KEYEVENTF_KEYUP;SendInput(1,&input,sizeof(input));
 }
 return GetForegroundWindow()==window;
}
#include <cstdio>
extern "C" void m2d9_test_size(HWND window,int *width,int *height){
 auto user=GetModuleHandleW(L"user32.dll");
 auto dpi=(UINT(WINAPI *)(HWND))GetProcAddress(user,"GetDpiForWindow");
 auto getThread=(HANDLE(WINAPI *)())GetProcAddress(user,"GetThreadDpiAwarenessContext");
 auto getWindow=(HANDLE(WINAPI *)(HWND))GetProcAddress(user,"GetWindowDpiAwarenessContext");
 auto physical=(BOOL(WINAPI *)(HWND,POINT *))GetProcAddress(user,"LogicalToPhysicalPointForPerMonitorDPI");
 RECT r;GetClientRect(window,&r);POINT points[2]={{0,0},{r.right,r.bottom}};
 MapWindowPoints(window,nullptr,points,2);
 if(physical){physical(window,&points[0]);physical(window,&points[1]);}
 *width=points[1].x-points[0].x;*height=points[1].y-points[0].y;
 printf("DPI %u, process aware %d, thread %p, window %p, client %ldx%ld, physical %dx%d\n",dpi?dpi(window):0,IsProcessDPIAware(),getThread?getThread():nullptr,getWindow?getWindow(window):nullptr,r.right,r.bottom,*width,*height);
}

extern "C" int m2d9_test_borderless(HWND window){
 MONITORINFOEXW monitor={};monitor.cbSize=sizeof(monitor);
 if(!GetMonitorInfoW(MonitorFromWindow(window,MONITOR_DEFAULTTONEAREST),&monitor))return 0;
 RECT r;GetWindowRect(window,&r);
 return EqualRect(&r,&monitor.rcMonitor)&&!(GetWindowLongPtrW(window,GWL_STYLE)&WS_OVERLAPPEDWINDOW);
}
extern "C" int m2d9_test_desktop(HWND window,int *width,int *height,int *hertz){
 MONITORINFOEXW monitor={};monitor.cbSize=sizeof(monitor);
 if(!GetMonitorInfoW(MonitorFromWindow(window,MONITOR_DEFAULTTONEAREST),&monitor))return 0;
 DEVMODEW mode={};mode.dmSize=sizeof(mode);
 if(!EnumDisplaySettingsW(monitor.szDevice,ENUM_CURRENT_SETTINGS,&mode))return 0;
 *width=mode.dmPelsWidth;*height=mode.dmPelsHeight;*hertz=mode.dmDisplayFrequency;return 1;
}

extern "C" int m2d9_test_dpi_aware(){return SetProcessDPIAware()!=FALSE;}

extern "C" void m2d9_test_position(HWND window,int *x,int *y){
 POINT pt={0,0};ClientToScreen(window,&pt);
 auto physical=(BOOL(WINAPI *)(HWND,POINT *))GetProcAddress(GetModuleHandleW(L"user32.dll"),"LogicalToPhysicalPointForPerMonitorDPI");
 if(physical)physical(window,&pt);
 *x=pt.x;*y=pt.y;
}
