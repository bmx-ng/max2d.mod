SuperStrict
Framework Max2D.Core
Import Max2D.ScalableFont
Import BRL.StandardIO

Global checks:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Function CheckOrder(font:TImageFont,keys:String[])
 Check(font.layoutKeys.Count()=keys.Length,"cache count")
 Local forward:TLink=font.layoutKeys.FirstLink(),backward:TLink=font.layoutKeys.LastLink()
 For Local i:Int=0 Until keys.Length
  Check(forward And backward,"list terminates at expected length")
  Check(String(forward.Value())=keys[i],"forward LRU order")
  Check(String(backward.Value())=keys[keys.Length-1-i],"backward LRU order")
  forward=forward.NextLink();backward=backward.PrevLink()
 Next
 Check(Not forward And Not backward,"list ends are intact")
End Function
Function Allocated:Long(stats:SGCStats Var)
 Return Long(stats.allocedBytesBeforeGC)+Long(stats.bytesAllocedSinceGC)
End Function
Function Exercise(font:TImageFont,label:String)
 Check(font<>Null,"font loaded")
 font.ClearLayoutCache();font.SetLayoutCacheLimit(3)
 Local a:TTextLayout=font.Layout("a"),b:TTextLayout=font.Layout("b"),c:TTextLayout=font.Layout("c")
 Local link:TLink=font.layoutKeys.FirstLink()
 CheckOrder(font,["a","b","c"])
 Check(font.Layout("a")=a,"hit preserves layout identity")
 Check(font.layoutKeys.LastLink()=link,"hit reuses its list link")
 CheckOrder(font,["b","c","a"])
 font.Layout("c");CheckOrder(font,["b","a","c"])
 font.Layout("c");CheckOrder(font,["b","a","c"])
 font.Layout("d");CheckOrder(font,["a","c","d"])
 Check(Not font.FindCachedLayout("b"),"least recently used layout evicted")
 Check(b.glyphs.Length>0 And b.width>0,"held evicted layout remains usable")
 font.CacheLayout("a",b);CheckOrder(font,["c","d","a"])
 Check(font.FindCachedLayout("a")=b,"replacement updates cached value")
 font.SetLayoutCacheLimit(1);CheckOrder(font,["a"])
 Check(Not font.FindCachedLayout("c") And Not font.FindCachedLayout("d"),"shrinking removes oldest keys")
 font.Layout("");CheckOrder(font,[""])
 Local empty:TTextLayout=font.Layout("")
 Check(font.Layout("")=empty,"empty string is a cached key")
 font.SetLayoutCacheLimit(0);CheckOrder(font,New String[0])
 Check(font.Layout("a")<>font.Layout("a"),"disabled cache builds fresh layouts")
 font.CacheLayout("a",a);CheckOrder(font,New String[0])
 Local rejected:Int
 Try
  font.SetLayoutCacheLimit(-1)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And font.layoutCacheLimit=0,"invalid limit leaves capacity unchanged")
 ' Mix oldest, middle, newest and empty keys; a last-key-only shortcut cannot pass.
 Local keys:String[]=["","alpha","beta","gamma","delta","epsilon","zeta","eta"]
 font.SetLayoutCacheLimit(keys.Length)
 For Local cycle:Int=0 Until 20
  For Local i:Int=0 Until keys.Length
   font.Layout(keys[(i*3) Mod keys.Length])
  Next
 Next
 Local builds:Long=font.layoutBuilds
 Local before:SGCStats,after:SGCStats
 GCCollect();GCGetStats(before)
 For Local cycle:Int=0 Until 2000
  For Local i:Int=0 Until keys.Length
   font.Layout(keys[(i*3) Mod keys.Length])
  Next
 Next
 GCGetStats(after)
 Local bytes:Long=Allocated(after)-Allocated(before)
 Check(bytes=0,"warmed alternating layout hits allocate zero bytes")
 Check(font.layoutBuilds=builds,"warmed hits do not rebuild layouts")
 Check(font.layoutKeys.Count()=keys.Length,"hit loop preserves cache size")
 font.ClearLayoutCache();CheckOrder(font,New String[0])
 For Local key:String=EachIn keys
  Check(Not font.FindCachedLayout(key),"clear removes every key")
 Next
 font.Layout("a");font.Layout("b");font.Layout("a");CheckOrder(font,["b","a"])
 font.ClearLayoutCache();font.SetLayoutCacheLimit(128)
 Print label+": 16000 mixed warm hits, "+bytes+" allocated bytes"
End Function
Try
 Exercise(TImageFont.DefaultFont(),"bitmap")
 If AppArgs.Length>1 Then Exercise(LoadScalableImageFont(AppArgs[1],18),"scalable")
 Print "PASS: "+checks+" layout cache checks"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndWithCode(1)
End Try
