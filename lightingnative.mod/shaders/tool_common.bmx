
' Tiles retain the source alpha representation so filtered straight-alpha
' patterns interpolate colour and coverage before multiplying them.
Const COLOUR_BODY:String="""
float4 basisX=p[0], basisY=p[1], material=p[2];
float2 position=float2(dot(basisX.xy,uv)+basisX.z,dot(basisY.xy,uv)+basisY.z);
float3 n=float3(0.0,0.0,1.0);
if(material.x>=0.0) { n=m.rgb*2.0-1.0; n.xy*=material.x; }
float a=basisX.x*basisX.w, b=basisX.y*basisY.w;
float d=basisY.x*basisX.w, e=basisY.y*basisY.w;
if(p[@SX@].w>0.5) {
 position=float2(dot(p[@SX@].xy,pixel)+p[@SX@].z,dot(p[@SY@].xy,pixel)+p[@SY@].z);
 float2 ux=@DX@(uv), uy=@DY@(uv), qx=@DX@(pixel), qy=@DY@(pixel);
 float2 px=float2(dot(p[@SX@].xy,qx),dot(p[@SY@].xy,qx));
 float2 py=float2(dot(p[@SX@].xy,qy),dot(p[@SY@].xy,qy));
 float det=ux.x*uy.y-ux.y*uy.x;
 if(abs(det)>1.0e-20) {
 a=(px.x*uy.y-py.x*ux.y)/det*basisX.w;
 b=(py.x*ux.x-px.x*uy.x)/det*basisY.w;
 d=(px.y*uy.y-py.y*ux.y)/det*basisX.w;
 e=(py.y*ux.x-px.y*uy.x)/det*basisY.w;
 } else { a=0.0;b=0.0;d=0.0;e=0.0; }
}
float determinant=a*e-b*d;
if(abs(determinant)>0.000001) n=float3((e*n.x-d*n.y)/determinant,(-b*n.x+a*n.y)/determinant,n.z);
else n=float3(0.0,0.0,1.0);
n=n/max(length(n),0.000001);
float3 sum=float3(0.0,0.0,0.0);
if(p[52].w>0.5) {
 sum=c.rgb*p[52].rgb;
 if(p[@EMISSION@].w>0.0) {
  float4 emission=@EMISSION_SAMPLE@;
  if(p[@EMISSION_MODE@].x!=0.0) emission=float4(1.0,1.0,1.0,emission.@ALPHA@);
  if(p[@EMISSION_MODE@].y!=0.0) emission.rgb=emission.a>0.0?emission.rgb/emission.a:float3(0.0,0.0,0.0);
  sum+=c.rgb*emission.rgb*emission.a*p[@EMISSION@].rgb*p[@EMISSION@].w;
 }
@AMBIENT_CLAMP@
}
@LOOP@
for(int i=0;i<8;++i) {
 if(float(i)>=p[3].x) break;
 float4 light=p[4+i*6], colour=p[5+i*6], shape=p[6+i*6];
 float3 delta=float3(light.xy-position,light.w);
 float attenuation=1.0;
 if(shape.x<0.0) delta=light.xyz;
 else attenuation=pow(max(0.0,1.0-length(delta.xy)/light.z),shape.x);
 float diffuse=1.0, specular=0.0;
 if(material.x>-1.5) {
  float3 direction=delta/max(length(delta),0.000001);
  diffuse=max(0.0,dot(n,direction));
  if(diffuse>0.0 && material.y>0.0) {
   float3 halfway=direction+float3(0.0,0.0,1.0);
   halfway=halfway/max(length(halfway),0.000001);
   specular=material.y*pow(max(0.0,dot(n,halfway)),material.z);
   if(material.w>0.5) specular*=clamp(m.a,0.0,1.0);
  }
 }
 float3 contribution=(c.rgb*diffuse+float3(specular,specular,specular))*colour.rgb*colour.a*attenuation;
 if(shape.y>0.5) {
  float4 mapX=p[7+i*6], mapY=p[8+i*6], tile=p[9+i*6];
  float2 mapUV=float2(dot(mapX.xy,position)+mapX.z,dot(mapY.xy,position)+mapY.z);
  float4 visibility=@SAMPLE@;
  if(mapX.w<0.5) visibility.rgb*=visibility.a;
  contribution*=visibility.rgb;
 }
 if(p[3].y>0.5) contribution=clamp(contribution,0.0,1.0);
 sum+=contribution;
}
return float4(sum*clamp(c.a,0.0,1.0),p[52].w>0.5?clamp(c.a,0.0,1.0):1.0);
"""

Function Generate(root:String,out:String)
 For Local capacity:Int=EachIn [8,16]
  GenerateVariant(root,out,capacity)
  GenerateVariant(root,out,capacity,True)
  GenerateVariant(root,out,capacity,2)
 Next
End Function

' Material layout: 0 = three textures, 1 = emission, 2 = emission and gloss.
Function GenerateVariant(root:String,out:String,capacity:Int,material:Int=False)
 Local USER_SLOTS:Int=8+capacity*6,TOTAL_SLOTS:Int=USER_SLOTS+8
 Local name:String="lightgroup"
 If material Then name="lightmaterial";TOTAL_SLOTS:+3
 If material=2 Then name="lightspecular";TOTAL_SLOTS:+3
 If capacity=16 Then name:+"16"
 If Not CreateDir(out,True) Then Throw "Cannot create output directory"
 For Local ext:String=EachIn ["metal","frag","glsl","hlsl","d3d11.hlsl","d3d9.hlsl"]
  If capacity=16 And ext="d3d9.hlsl" Then Continue
  Local source:String=LoadText(root+"/sdl3gpueffects.mod/packages/texturedlight/texturedlight."+ext)
  If source="" Then Throw "Missing textured-light sampling wrapper"
  source=source.Replace("p[15]","p["+TOTAL_SLOTS+"]")
  For Local slot:Int=14 To 7 Step -1
   Local mapped:Int=slot+USER_SLOTS-7
   ' Each extra material texture adds bounds/info before auxiliary modes.
   If material And slot>=13 Then mapped:+2*material
   source=source.Replace("p["+slot+"]","p["+mapped+"]")
  Next
  If ext="d3d9.hlsl" Then
   For Local slot:Int=19 To 17 Step -1
    source=source.Replace("register(c"+slot+")","register(c"+(TOTAL_SLOTS+slot-16)+")")
   Next
  End If
  Local vector:String="float4",pair:String="float2",body:String=COLOUR_BODY
  ' D3D11 ALPHABLEND uses straight fragment RGB and fixed-function SRC_ALPHA.
  ' Its normalized target clamps RGB before applying coverage, unlike the
  ' premultiplied ambient composition used by the other native paths.
  Local ambientClamp:String
  If ext="d3d11.hlsl" Then ambientClamp="if(p[3].y>0.5) sum=clamp(sum,0.0,1.0);"
  body=body.Replace("@AMBIENT_CLAMP@",ambientClamp)
  body=body.Replace("p[52]","p["+(USER_SLOTS-1)+"]").Replace("i<8;","i<"+capacity+";")
  If ext="frag" Or ext="glsl" Then
   vector="vec4";pair="vec2"
   body=body.Replace("float2","vec2").Replace("float3","vec3").Replace("float4","vec4")
  End If
  Local dx:String="ddx",dy:String="ddy",pixel:String="input.position.xy"
  If ext="metal" Then dx="dfdx";dy="dfdy"
  If ext="frag" Or ext="glsl" Then dx="dFdx";dy="dFdy";pixel="gl_FragCoord.xy"
  If ext="glsl" Then pixel="vec2(gl_FragCoord.x,p["+(USER_SLOTS-2)+"].w-gl_FragCoord.y)"
  If ext="d3d9.hlsl" Then pixel="pixel+float2(0.5,0.5)"
  body=body.Replace("@SX@",String(USER_SLOTS-3)).Replace("@SY@",String(USER_SLOTS-2)).Replace("@DX@",dx).Replace("@DY@",dy)
  Local loopHint:String
  If ext.EndsWith("hlsl") Then loopHint="[loop]"
  body=body.Replace("@LOOP@",loopHint)
  Local first:Int=source.Find(pair+" userEffect("),third:Int=source.Find(vector+" sampleThird("),following:Int=source.Find(vector+" sampleMap(")
  If first<0 Or third<0 Or following<0 Then Throw "Unexpected sampling wrapper layout"
  Local sampling:String=source[third..following]
  sampling=sampling.Replace(vector+" bounds=p["+(USER_SLOTS+4)+"], info=p["+(USER_SLOTS+5)+"];", "")
  Local signature:String=vector+" userColour("+vector+" c, "+pair+" uv, "+vector+" m, "+pair+" pixel"
  Local sample:String="sampleThird(mapUV,tile,"+vector+"(p[3].zw,shape.zw))"
  If ext="metal" Then
   sampling=sampling.Replace("constant float4 *p)","float4 bounds, float4 info)")
   signature:+", texture2d<float> thirdImage, sampler thirdState"
   If material Then signature:+", texture2d<float> fourthImage, sampler fourthState"
   If material=2 Then signature:+", texture2d<float> fifthImage, sampler fifthState"
   signature:+", constant float4 *p)"
   sample="sampleThird(mapUV,thirdImage,thirdState,tile,float4(p[3].zw,shape.zw))"
   source=source.Replace("m,t,p);","m,"+pixel+",thirdImage,thirdState,p);")
   source=source.Replace("sampleRegion(userEffect(localUV,m,t,p),","sampleRegion(localUV,")
  Else
   sampling=sampling.Replace(pair+" uv)",pair+" uv, "+vector+" bounds, "+vector+" info)")
   signature:+")"
   source=source.Replace("m,t);","m,"+pixel+");")
   source=source.Replace("sampleRegion(userEffect(localUV,m,t))","sampleRegion(localUV)")
  End If
  Local emissionSample:String="sampleThird(uv,p["+(USER_SLOTS+4)+"],p["+(USER_SLOTS+5)+"])"
  If ext="metal" Then emissionSample="sampleThird(uv,thirdImage,thirdState,p["+(USER_SLOTS+4)+"],p["+(USER_SLOTS+5)+"])"
  Local emissionMode:Int=USER_SLOTS+7
  Local fourthSampling:String
  If material Then
   emissionMode=USER_SLOTS+8+material*2
   emissionSample=emissionSample.Replace("Third","Fourth").Replace("third","fourth").Replace("p["+(USER_SLOTS+4)+"]","p["+(USER_SLOTS+6)+"]").Replace("p["+(USER_SLOTS+5)+"]","p["+(USER_SLOTS+7)+"]")
   fourthSampling=sampling.Replace("Third","Fourth").Replace("third","fourth")
  End If
  Local fifthSampling:String
  If material=2 Then
   fifthSampling=sampling.Replace("Third","Fifth").Replace("third","fifth")
   Local glossSample:String="sampleFifth(uv,p["+(USER_SLOTS+8)+"],p["+(USER_SLOTS+9)+"])"
   If ext="metal" Then glossSample="sampleFifth(uv,fifthImage,fifthState,p["+(USER_SLOTS+8)+"],p["+(USER_SLOTS+9)+"])"
   Local glossAlpha:String="r"
   If ext="glsl" Or ext="d3d9.hlsl" Then glossAlpha="a"
   Local materialLine:String=vector+" basisX=p[0], basisY=p[1], material=p[2];"
   body=body.Replace(materialLine, materialLine+"~n"+vector+" gloss="+glossSample+";~nmaterial.y*=clamp(material.w>2.5?gloss."+glossAlpha+":gloss.r,0.0,1.0);")
   body=body.Replace("if(material.w>0.5) specular*=clamp(m.a,0.0,1.0);", "/* Separate gloss already applied. */")
   ' Match the byte flat normal used by the compatibility packer.
   Local normalType:String="float3"
   If ext="frag" Or ext="glsl" Then normalType="vec3"
   body=body.Replace("if(material.x>=0.0)","if(material.x<0.0) n="+normalType+"(1.0/255.0,1.0/255.0,1.0);~nif(material.x>=0.0)")
  End If
  Local alpha:String="r"
  If ext="glsl" Then alpha="a"
  body=body.Replace("@SAMPLE@",sample).Replace("@EMISSION_SAMPLE@",emissionSample).Replace("@EMISSION@",String(USER_SLOTS-4)).Replace("@EMISSION_MODE@",String(emissionMode)).Replace("@ALPHA@",alpha)
  ' Remove the ordinary per-pixel third sample; each light samples its tile.
  Local entry:Int=source.Find(vector+" t=sampleThird("),normal:Int=source.Find(vector+" m=sampleMap(",entry)
  If entry<0 Or normal<0 Then Throw "Unexpected third-texture entry point"
  source=source[..entry]+source[normal..]
  ' Prefix edits above do not affect positions before the sampling functions.
  source=source[..first]+sampling+fourthSampling+fifthSampling+signature+" {~n"+body+"~n}~n"+source[following..]
  If material Then
   Select ext
    Case "glsl"
     Local begin:Int=source.Find("vec4 m2dThirdTexel("),finish:Int=source.Find("}",begin)+1
     Local helper:String=source[begin..finish].Replace("Third","Fourth").Replace("third","fourth")
     source=source[..begin]+"uniform sampler2D fourthImage;~nuniform int fourthTarget;~n"+helper+"~n"+source[begin..]
    Case "frag"
     source=source.Replace("layout(set=2,binding=2) uniform sampler2D thirdImage;","layout(set=2,binding=2) uniform sampler2D thirdImage;~nlayout(set=2,binding=3) uniform sampler2D fourthImage;")
    Case "metal"
     source=source.Replace("thirdImage,thirdState,p);","thirdImage,thirdState,fourthImage,fourthState,p);")
     source=source.Replace("constant float4 &mode [[buffer(0)]]","texture2d<float> fourthImage [[texture(3)]], sampler fourthState [[sampler(3)]], constant float4 &mode [[buffer(0)]]")
    Case "d3d9.hlsl"
     source="float4 fourthScale : register(c"+(TOTAL_SLOTS+4)+");~n"+source
     source=source.Replace("sampler2D thirdImage : register(s2);","sampler2D thirdImage : register(s2);~nsampler2D fourthImage : register(s3);")
    Default
     Local space:String
     If ext="hlsl" Then space=", space2"
     source=source.Replace("SamplerState thirdState : register(s2"+space+");","SamplerState thirdState : register(s2"+space+");~nTexture2D fourthImage : register(t3"+space+");~nSamplerState fourthState : register(s3"+space+");")
   End Select
  End If
  If material=2 Then
   Select ext
    Case "glsl"
     Local begin:Int=source.Find("vec4 m2dThirdTexel("),finish:Int=source.Find("}",begin)+1
     Local helper:String=source[begin..finish].Replace("Third","Fifth").Replace("third","fifth")
     source=source[..begin]+"uniform sampler2D fifthImage;~nuniform int fifthTarget;~n"+helper+"~n"+source[begin..]
    Case "frag"
     source=source.Replace("layout(set=2,binding=3) uniform sampler2D fourthImage;","layout(set=2,binding=3) uniform sampler2D fourthImage;~nlayout(set=2,binding=4) uniform sampler2D fifthImage;")
    Case "metal"
     source=source.Replace("fourthImage,fourthState,p);","fourthImage,fourthState,fifthImage,fifthState,p);")
     source=source.Replace("constant float4 &mode [[buffer(0)]]","texture2d<float> fifthImage [[texture(4)]], sampler fifthState [[sampler(4)]], constant float4 &mode [[buffer(0)]]")
    Case "d3d9.hlsl"
     source="float4 fifthScale : register(c"+(TOTAL_SLOTS+5)+");~n"+source
     source=source.Replace("sampler2D fourthImage : register(s3);","sampler2D fourthImage : register(s3);~nsampler2D fifthImage : register(s4);")
    Default
     Local space:String
     If ext="hlsl" Then space=", space2"
     source=source.Replace("SamplerState fourthState : register(s3"+space+");","SamplerState fourthState : register(s3"+space+");~nTexture2D fifthImage : register(t4"+space+");~nSamplerState fifthState : register(s4"+space+");")
   End Select
  End If
  If Not SaveText(source,out+"/"+name+"."+ext) Then Throw "Cannot write shader source"
 Next
End Function

Function Embed(out:String)
 For Local capacity:Int=EachIn [8,16]
  EmbedVariant(out,capacity)
  EmbedVariant(out,capacity,True)
  EmbedVariant(out,capacity,2)
 Next
End Function

Function EmbedVariant(out:String,capacity:Int,material:Int=False)
 Local TOTAL_SLOTS:Int=16+capacity*6
 Local name:String="lightgroup",suffix:String
 If material Then name="lightmaterial";suffix="_material";TOTAL_SLOTS:+3
 If material=2 Then name="lightspecular";suffix="_specular";TOTAL_SLOTS:+3
 If capacity=16 Then name:+"16";suffix:+"_16"
 Local text:String="/* Generated built-in grouped lighting assets. */~n#include <max2d.mod/shadereffects.mod/package.h>~n"
 Local extensions:String[]=["metal","frag.spv","dxbc","glsl","d3d11.dxbc","d3d9.bin"]
 Local lengths:Int[6]
 For Local i:Int=0 Until extensions.Length
  If capacity=16 And i=5 Then Continue
  Local data:TBank=LoadBank(out+"/"+name+"."+extensions[i])
  If Not data Or data.Size()<1 Then Throw "Missing compiled shader: "+extensions[i]
  lengths[i]=Int(data.Size())
  text:+"static const unsigned char asset"+i+"[]={~n"
  For Local j:Int=0 Until lengths[i]
   text:+data.PeekByte(j)+","
   If (j+1) Mod 24=0 Then text:+"~n"
  Next
  text:+"0};~n"
 Next
 text:+"void *m2d_native_lighting_assets"+suffix+"(void) {~n static M2DPackage assets={~n"
 text:+" .metal=(unsigned char *)asset0,.spirv=(unsigned char *)asset1,.dxbc=(unsigned char *)asset2,~n"
 Local d3d9:String="(unsigned char *)asset5"
 If capacity=16 Then d3d9="NULL"
 text:+" .glsl=(unsigned char *)asset3,.d3d11=(unsigned char *)asset4,.d3d9="+d3d9+",~n"
 text:+" .metalSize="+lengths[0]+",.spirvSize="+lengths[1]+",.dxbcSize="+lengths[2]+",.d3d11Size="+lengths[4]+",.d3d9Size="+lengths[5]+",~n"
 Local samplers:Int=3,abi:String="M2D_NATIVE_LIGHTING_ABI",key:String="m2d-light-v7-"
 If material Then samplers=4;abi="M2D_NATIVE_MATERIAL_ABI";key="m2d-light-material-v8-"
 If material=2 Then samplers=5;key="m2d-light-specular-v8-"
 text:+" .slots="+TOTAL_SLOTS+",.samplers="+samplers+",.abi="+abi+",.key=~q"+key+capacity+"~q~n };~n return &assets;~n}~n"
 If Not SaveText(text,out+"/"+name+"_assets.c") Then Throw "Cannot write embedded assets"
End Function
