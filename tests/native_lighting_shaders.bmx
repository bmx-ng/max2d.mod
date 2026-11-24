SuperStrict
Framework BRL.StandardIO
Import BRL.FileSystem
Import BRL.BankStream
Include "../lightingnative.mod/shaders/tool_common.bmx"

Try
 ChangeDir(LaunchDir)
 If AppArgs.Length<>3 Then Throw "Usage: native_lighting_shaders module-directory scratch-directory"
 Local root:String=RealPath(AppArgs[1]),scratch:String=RealPath(AppArgs[2])
 If FileType(scratch) Then Throw "Scratch directory already exists"
 Generate(root,scratch)
 Local checked:String=root+"/lightingnative.mod/shaders"
 For Local name:String=EachIn ["lightgroup","lightgroup16","lightmaterial","lightmaterial16","lightspecular","lightspecular16"]
  For Local ext:String=EachIn ["metal","frag","glsl","hlsl","d3d11.hlsl","d3d9.hlsl"]
   If name.EndsWith("16") And ext="d3d9.hlsl" Then Continue
   If LoadText(scratch+"/"+name+"."+ext)<>LoadText(checked+"/"+name+"."+ext) Then Throw "Shader source differs: "+ext
  Next
  For Local ext:String=EachIn ["frag.spv","dxbc","d3d11.dxbc","d3d9.bin"]
   If name.EndsWith("16") And ext="d3d9.bin" Then Continue
   If Not CopyFile(checked+"/"+name+"."+ext,scratch+"/"+name+"."+ext) Then Throw "Cannot copy compiled shader"
  Next
 Next
 Embed(scratch)
 For Local name:String=EachIn ["lightgroup","lightgroup16","lightmaterial","lightmaterial16","lightspecular","lightspecular16"]
  If LoadText(scratch+"/"+name+"_assets.c")<>LoadText(checked+"/"+name+"_assets.c") Then Throw "Embedded shader assets differ: "+name
 Next
 Print "native_lighting_shaders passed"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndWithCode(1)
End Try
