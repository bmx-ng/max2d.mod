SuperStrict
Rem
bbdoc: Optional desktop OpenGL elapsed-GPU timer provider.
about: Import alongside Max2D.GLMax2D and use TMax2DGpuTimer.Create. Requires ARB_timer_query or EXT_timer_query with a nonzero elapsed counter. Uses a retained ring of query objects and availability polling; never calls glFinish or waits for results. Does not support SDL GPU, SDL renderer or Direct3D contexts.
End Rem
Module Max2D.GLProfiling
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
Import Max2D.Profiling
Import Max2D.GLMax2D
Import Pub.GLEW
Private
Type TGLGpuTimer Extends TMax2DGpuTimer
 Field context:TMax2DContext
 Field queries:Int[],ids:Long[]
 Field head:Int,tail:Int,count:Int,active:Int,core:Int
 Method Check()
  If Not context Then Throw "Max2D Profiling: timer released"
  context.CheckOpen()
  If TMax2DGraphics.Current().context<>context Then Throw "Max2D Profiling: wrong graphics context"
  context.Activate()
 End Method
 Method Begin:Int(sampleId:Long) Override
  Check()
  If active Then Throw "Max2D Profiling: sample already active"
  Local current:Int
  glGetQueryiv(GL_TIME_ELAPSED,GL_CURRENT_QUERY,Varptr current)
  If current Then Throw "Max2D Profiling: overlapping GPU sample"
  If count=queries.Length Then Return False
  context.Flush()
  glBeginQuery(GL_TIME_ELAPSED,queries[tail])
  ids[tail]=sampleId;active=True
  Return True
 End Method
 Method EndSample() Override
  Check()
  If Not active Then Throw "Max2D Profiling: no active sample"
  context.Flush()
  glEndQuery(GL_TIME_ELAPSED)
  active=False;tail=(tail+1) Mod queries.Length;count:+1
  glFlush()
 End Method
 Method Poll:Int(sampleId:Long Var,nanoseconds:Long Var) Override
  Check()
  If count=0 Then Return False
  Local available:Int
  glGetQueryObjectiv(queries[head],GL_QUERY_RESULT_AVAILABLE,Varptr available)
  If Not available Then Return False
  Local elapsed:Long
  If core Then glGetQueryObjectui64v(queries[head],GL_QUERY_RESULT,Varptr elapsed) Else glGetQueryObjectui64vEXT(queries[head],GL_QUERY_RESULT,Varptr elapsed)
  sampleId=ids[head];nanoseconds=elapsed
  head=(head+1) Mod queries.Length;count:-1
  Return True
 End Method
 Method Pending:Int() Override
  Return count
 End Method
 Method Release() Override
  If Not context Then Return
  If Not context.closed Then
   Check()
   If active Then EndSample()
   Local current:Int
   glGetQueryiv(GL_TIME_ELAPSED,GL_CURRENT_QUERY,Varptr current)
   If current Then Throw "Max2D Profiling: cannot release during another GPU sample"
   glDeleteQueries(queries.Length,queries)
  End If
  context=Null;queries=Null;ids=Null;count=0;active=False
 End Method
End Type
Type TGLGpuTimerProvider Extends TMax2DGpuTimerProvider
 Method CreateTimer:TMax2DGpuTimer(context:TMax2DContext,capacity:Int) Override
  If Not TGLMax2DContext(context) Then Return Null
  context.Activate()
  Local extensions:String=String.FromCString(Byte Ptr(glGetString(GL_EXTENSIONS)))
  Local core:Int=(" "+extensions+" ").Contains(" GL_ARB_timer_query ")
  If Not core And Not (" "+extensions+" ").Contains(" GL_EXT_timer_query ") Then Return Null
  Local bits:Int
  glGetQueryiv(GL_TIME_ELAPSED,GL_QUERY_COUNTER_BITS,Varptr bits)
  If bits=0 Then Return Null
  Local current:Int
  glGetQueryiv(GL_TIME_ELAPSED,GL_CURRENT_QUERY,Varptr current)
  If current Then Throw "Max2D Profiling: cannot create during an active GPU sample"
  Local timer:TGLGpuTimer=New TGLGpuTimer
  timer.context=context;timer.core=core
  timer.queries=New Int[capacity];timer.ids=New Long[capacity]
  glGenQueries(capacity,timer.queries)
  Return timer
 End Method
End Type
RegisterMax2DGpuTimerProvider(New TGLGpuTimerProvider)
