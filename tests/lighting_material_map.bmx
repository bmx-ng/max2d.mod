SuperStrict
Framework BRL.StandardIO
Import Max2D.Lighting
Global checks:Int
Function Check(value:Int,message:String)
 If Not value Then Throw message
 checks:+1
End Function
Function Pixel:Int(image:TImage,x:Int=0,y:Int=0)
 Local pixels:TPixmap=image.Lock(0,True,False)
 Local value:Int=pixels.ReadPixel(x,y)
 image.Unlock()
 Return value
End Function
Try
 Local pixels:TPixmap=CreatePixmap(4,2,PF_RGBA8888)
 pixels.ClearPixels($00ff8080)
 Local normal:TImage=TImage.FromPixmap(pixels,DYNAMICIMAGE)
 pixels.ClearPixels($00800000)
 Local gloss:TImage=TImage.FromPixmap(pixels,DYNAMICIMAGE)
 Local builder:TMax2DLightingMaterialMap=TMax2DLightingMaterialMap.Create(False)
 Local output:TImage=builder.Update(normal,gloss)
 Check(Pixel(output)=$80ff8080,"red gloss ignores alpha and preserves normal RGB")
 Check(output.flags=0,"explicit nearest output")
 Check(Pixel(normal)=$00ff8080 And Pixel(gloss)=$00800000,"source pixels remain unchanged")
 Local version:Long=output.sources[0].version
 Local retained:Int=True
 For Local i:Int=0 Until 1000
  retained=retained And builder.Update(normal,gloss)=output
 Next
 Check(retained,"unchanged inputs retain output")
 Check(output.sources[0].version=version,"warm updates do not mark pixels dirty")
 pixels.ClearPixels($ff400000);gloss.ReplacePixels(pixels)
 Check(builder.Update(normal,gloss)=output And Pixel(output)=$40ff8080,"gloss edit refreshes retained output")
 Check(output.sources[0].version>version,"changed pixels mark upload dirty")
 pixels=normal.Lock();pixels.ClearPixels($ff123456);normal.Unlock()
 Check(builder.Update(normal,gloss)=output And Pixel(output)=$40123456,"normal write lock refreshes output")
 Check(builder.Update(Null,gloss)=output And Pixel(output)=$40ff8080,"gloss-only supplies flat normal")
 Check(builder.Update(normal,Null)=output And Pixel(output)=$ff123456,"normal-only supplies full gloss")
 Check(builder.Update(normal,normal)=output And Pixel(output)=$12123456,"same source can supply both channels")
 Local alpha:TPixmap=CreatePixmap(4,2,PF_A8)
 alpha.ClearPixels($60000000)
 Local a8:TImage=TImage.FromPixmap(alpha,0,PF_A8)
 Check(builder.Update(Null,a8)=output And Pixel(output)=$60ff8080,"A8 gloss reads alpha byte")
 Local atlasPixels:TPixmap=CreatePixmap(8,2,PF_RGBA8888)
 atlasPixels.ClearPixels($ff200000)
 For Local y:Int=0 Until 2
  For Local x:Int=4 Until 8
   atlasPixels.WritePixel(x,y,$ffe00000)
  Next
 Next
 Local atlas:TImage=TImage.FromPixmap(atlasPixels)
 Local view:TImage=TImage.View(atlas,4,0,4,2)
 Check(builder.Update(normal,view)=output And Pixel(output)=$e0123456,"atlas frame offset is respected")
 Local rejected:Int
 For Local variant:Int=0 Until 7
  rejected=False;version=output.sources[0].version
  Try
   Select variant
    Case 0;builder.Update(Null,Null)
    Case 1;builder.Update(normal,gloss,0,9)
    Case 2;builder.Update(normal,atlas)
    Case 3;builder.Update(a8,gloss)
    Case 4;builder.Update(Null,gloss,1)
    Case 5;builder.Update(output,gloss)
    Case 6
     normal.Lock()
     Try
      builder.Update(normal,gloss)
     Finally
      normal.Unlock()
     End Try
   End Select
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And output.sources[0].version=version,"invalid update preserves output "+variant)
 Next
 Local trimmed:TImage=TImage.View(atlas,0,0,4,2)
 trimmed.SetTrim(0,1,0,2,2)
 rejected=False
 Try
  builder.Update(trimmed,gloss)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"trimmed material data rejected")
 Local bigger:TImage=builder.Update(Null,atlas)
 Check(bigger<>output And bigger.width=8 And Pixel(bigger,7)=$e0ff8080,"resize replaces output")
 builder.Release();builder.Release()
 Check(builder.Update(normal,gloss)<>bigger,"released builder can rebuild")
 Check(Pixel(normal)=$ff123456,"release does not affect inputs")
 builder.Release()
 Print "PASS: "+checks+" material-map checks"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
