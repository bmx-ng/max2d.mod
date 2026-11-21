' Short synthesized cues: no external assets, music or per-frame sample generation.
Type TPinSound
    Field overdriveSound:TSound, overdriveVoice:TChannel
    Field ready:Int, muted:Int, voices:TChannel[12], sounds:TSound[8], nextVoice:Int
    Method New()
        ready = SetAudioDriver("SDL3")
        If Not ready Then
            Return
        End If

        sounds[0] = Tone(740, 320, 0.13, 0)
        sounds[1] = Tone(210, 80, 0.09, 1)
        sounds[2] = Tone(130, 65, 0.045, 1)
        sounds[3] = Tone(180, 1100, 0.32, 0)
        sounds[4] = Tone(330, 880, 0.5, 2)
        sounds[5] = Tone(660, 990, 0.65, 2)
        sounds[6] = Tone(240, 55, 0.4, 0)
        sounds[7] = Tone(1200, 1500, 0.12, 0)
        overdriveSound = OverdrivePulse()
    End Method

    Method Tone:TSound(start:Float, finish:Float, duration:Float, kind:Int)
        Local sample:TAudioSample = CreateAudioSample(Int(duration * 44100), 44100, SF_MONO16LE)
        Local phase:Float
        For Local i:Int = 0 Until sample.length
            Local t:Float = Float(i) / sample.length, frequency:Float = start + (finish - start) * t
            phase :+ frequency * 360 / 44100
            Local wave:Float = Float(Sin(phase) * 0.7 + Sin(phase * 2) * 0.2)
            If kind = 1 Then
                wave = Float(wave * 0.4 + Sin(i * 137.51) * 0.4 * (1 - t))
            End If

            If kind = 2 Then
                wave = Float(Sin(phase) * 0.4 + Sin(phase * 1.25) * 0.25 + Sin(phase * 1.5) * 0.25)
            End If

            Local envelope:Float = Min(1, Float(i) / 180) * (1 - t) * (1 - t)
            Local value:Int = Int(wave * envelope * 16000)
            sample.samples[i * 2] = Byte(value & 255)
             sample.samples[i * 2 + 1] = Byte((value Shr 8) & 255)
        Next

        Return LoadSound(sample)
    End Method
    ' One seamless second of reactor pulses, synthesized once at startup.
    Method OverdrivePulse:TSound()
        Local sample:TAudioSample = CreateAudioSample(44100, 44100, SF_MONO16LE)
        For Local i:Int = 0 Until sample.length
            Local seconds:Float = Float(i) / 44100
            Local pulse:Float = Float(Sin(seconds * 360))
            Local envelope:Float = pulse * pulse
            Local wave:Float = Float(Sin(seconds * 110 * 360) * 0.55 + Sin(seconds * 220 * 360) * 0.25 + Sin(seconds * 330 * 360) * 0.15)
            Local value:Int = Int(wave * envelope * 14000)
            sample.samples[i * 2] = Byte(value & 255)
             sample.samples[i * 2 + 1] = Byte((value Shr 8) & 255)
        Next

        Return LoadSound(sample, SOUND_LOOP)
    End Method

    Method UpdateOverdrive(remaining:Float, paused:Int)
        If Not ready Or muted Or paused Or remaining <= 0 Then
            If overdriveVoice Then overdriveVoice.Stop(); overdriveVoice = Null

            Return
        End If

        If Not overdriveSound Then
            Return
        End If

        If Not overdriveVoice Then
            overdriveVoice = overdriveSound.Cue()
            If Not overdriveVoice Then
                Return
            End If

            overdriveVoice.SetVolume(0.20)
            overdriveVoice.SetPaused(False)
        End If
        ' A little urgency for the final ten seconds, without drowning out impacts.
        overdriveVoice.SetRate(1 + Max(0, 10 - remaining) * 0.05)
    End Method

    Method Play(index:Int, x:Float = 5.6, rate:Float = 1)
        If Not ready Or muted Or Not sounds[index] Then
            Return
        End If

        Local slot:Int = nextVoice Mod voices.Length
         nextVoice :+ 1
        If voices[slot] Then
            voices[slot].Stop()
        End If

        Local channel:TChannel = sounds[index].Cue()
        If Not channel Then
            Return
        End If

        voices[slot] = channel
        channel.SetVolume(0.32)
         channel.SetPan(Float(Max(-0.7, Min(0.7, (x - 5.6) / 7))))
        channel.SetRate(rate)
         channel.SetPaused(False)
    End Method

    Method Silence()
        If overdriveVoice Then overdriveVoice.Stop(); overdriveVoice = Null

        For Local channel:TChannel = EachIn voices
            If channel Then
                channel.Stop()
            End If
        Next
    End Method

    Method Toggle()
        muted = Not muted
        If muted Then
            Silence()
        End If
    End Method
End Type
