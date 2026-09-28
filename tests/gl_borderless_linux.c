#include <GL/glx.h>
#include <X11/Xatom.h>
#include <X11/extensions/Xrandr.h>

int test_gl_borderless_covers_screen(void){
 Display *display=glXGetCurrentDisplay();Window window=glXGetCurrentDrawable(),root,child;
 int x,y,format,count=0,covered=0,fullscreen=0;unsigned int width,height,border,depth;
 Atom type;unsigned long items,left;unsigned char *data=0;
 if(!display || !window || !XGetGeometry(display,window,&root,&x,&y,&width,&height,&border,&depth))return 0;
 XTranslateCoordinates(display,window,root,0,0,&x,&y,&child);
 Atom state=XInternAtom(display,"_NET_WM_STATE",False),full=XInternAtom(display,"_NET_WM_STATE_FULLSCREEN",False);
 if(XGetWindowProperty(display,window,state,0,1024,False,XA_ATOM,&type,&format,&items,&left,&data)==Success && type==XA_ATOM && format==32){
  for(unsigned long i=0;i<items;i++)if(((Atom*)data)[i]==full)fullscreen=1;
 }
 if(data)XFree(data);
 XRRMonitorInfo *monitors=XRRGetMonitors(display,root,True,&count);
 for(int i=0;i<count;i++)if(x==monitors[i].x && y==monitors[i].y && width==monitors[i].width && height==monitors[i].height)covered=1;
 if(monitors)XRRFreeMonitors(monitors);
 return fullscreen && covered;
}

static XSizeHints savedHints;
void test_gl_capture_hints(void){
 long supplied;
 XGetWMNormalHints(glXGetCurrentDisplay(),glXGetCurrentDrawable(),&savedHints,&supplied);
}
int test_gl_hints_restored(void){
 XSizeHints hints;long supplied;
 if(!XGetWMNormalHints(glXGetCurrentDisplay(),glXGetCurrentDrawable(),&hints,&supplied))return 0;
 return hints.flags==savedHints.flags && hints.min_width==savedHints.min_width &&
  hints.min_height==savedHints.min_height && hints.max_width==savedHints.max_width &&
  hints.max_height==savedHints.max_height && hints.win_gravity==savedHints.win_gravity;
}
