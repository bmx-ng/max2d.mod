' Short synthesized cues: no external assets, music or per-frame sample generation.
Type TPinSound
 Field ready:Int,muted:Int,voices:TChannel[12],sounds:TSound[8],nextVoice:Int
 Method New()
  ready=SetAudioDriver("SDL3")
  If Not ready Then Return
  sounds[0]=Tone(740,320,0.13,0)
  sounds[1]=Tone(210,80,0.09,1)
  sounds[2]=Tone(130,65,0.045,1)
  sounds[3]=Tone(180,1100,0.32,0)
  sounds[4]=Tone(330,880,0.5,2)
  sounds[5]=Tone(660,990,0.65,2)
  sounds[6]=Tone(240,55,0.4,0)
  sounds[7]=Tone(1200,1500,0.12,0)
 End Method
 Method Tone:TSound(start:Float,finish:Float,duration:Float,kind:Int)
  Local sample:TAudioSample=CreateAudioSample(Int(duration*44100),44100,SF_MONO16LE)
  Local phase:Float
  For Local i:Int=0 Until sample.length
   Local t:Float=Float(i)/sample.length,frequency:Float=start+(finish-start)*t
   phase:+frequency*360/44100
   Local wave:Float=Float(Sin(phase)*0.7+Sin(phase*2)*0.2)
   If kind=1 Then wave=Float(wave*0.4+Sin(i*137.51)*0.4*(1-t))
   If kind=2 Then wave=Float(Sin(phase)*0.4+Sin(phase*1.25)*0.25+Sin(phase*1.5)*0.25)
   Local envelope:Float=Min(1,Float(i)/180)*(1-t)*(1-t)
   Local value:Int=Int(wave*envelope*16000)
   sample.samples[i*2]=Byte(value & 255); sample.samples[i*2+1]=Byte((value Shr 8) & 255)
  Next
  Return LoadSound(sample)
 End Method
 Method Play(index:Int,x:Float=5.6,rate:Float=1)
  If Not ready Or muted Or Not sounds[index] Then Return
  Local slot:Int=nextVoice Mod voices.Length; nextVoice:+1
  If voices[slot] Then voices[slot].Stop()
  Local channel:TChannel=sounds[index].Cue()
  If Not channel Then Return
  voices[slot]=channel
  channel.SetVolume(0.32); channel.SetPan(Float(Max(-0.7,Min(0.7,(x-5.6)/7))))
  channel.SetRate(rate); channel.SetPaused(False)
 End Method
 Method Silence()
  For Local channel:TChannel=EachIn voices
   If channel Then channel.Stop()
  Next
 End Method
 Method Toggle()
  muted=Not muted
  If muted Then Silence()
 End Method
End Type
