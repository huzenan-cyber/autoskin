---@meta

--- Auto-generated from Audio/SoundSource


---@class SoundSource : Component
---@field sound Sound Resource currently assigned to the source.
---@field soundType string Sound type used for gain grouping.
---@field timePosition number Playback position in seconds; it advances only while mixing progresses.
---@field frequency number Current absolute playback frequency in Hz, not a pitch multiplier. Set 0 before Play(sound) to use the sound's sample rate.
---@field gain number Exact linear source gain. 0 is silence and 1 is full source gain.
---@field attenuation number Linear attenuation multiplier. 1 is unaltered and 0 is silence.
---@field panning number Stereo panning from -1 (left) to 1 (right); effective for mono sources mixed to stereo output.
---@field autoRemoveMode AutoRemoveMode Automatic removal mode after playback completes.
---@field playing boolean Whether the source is currently playing. This is source state, not device state.
---@field fadingIn boolean Whether a de-click fade-in is active.
---@field fadingOut boolean Whether a de-click fade-out is active.
---@field declickEnabled boolean Whether short de-click fades are enabled.
SoundSource = {}

--- Seek to a position in seconds. The position wraps modulo the full sound length for all sounds, looped or not.
--- For uncompressed sounds the result is then clamped to the current loop end; it is not wrapped into the SetLoop range.
---@param seekTime number
---@return nil
function SoundSource:Seek(seekTime) end

--- Play a sound. A zero source frequency is initialized from the sound's sample rate; a non-zero source frequency is retained.
---@param sound Sound Sound resource to play
---@return nil
function SoundSource:Play(sound) end

--- Play a sound at an absolute playback frequency.
---@param sound Sound Sound resource to play
---@param frequency number Playback frequency in Hz, not a pitch multiplier; pass 0 to use the sound's sample rate
---@return nil
function SoundSource:Play(sound, frequency) end

--- Play a sound at an absolute playback frequency and gain.
---@param sound Sound Sound resource to play
---@param frequency number Playback frequency in Hz, not a pitch multiplier; pass 0 to use the sound's sample rate
---@param gain number Linear gain where 0 is silence and 1 is full volume
---@return nil
function SoundSource:Play(sound, frequency, gain) end

--- Play a sound at an absolute playback frequency, gain and stereo panning.
---@param sound Sound Sound resource to play
---@param frequency number Playback frequency in Hz, not a pitch multiplier; pass 0 to use the sound's sample rate
---@param gain number Linear gain where 0 is silence and 1 is full volume
---@param panning number Stereo panning from -1 (left) to 1 (right); effective for mono sources mixed to stereo output
---@return nil
function SoundSource:Play(sound, frequency, gain, panning) end

--- Stop with the default short de-click fade. The source remains registered.
---@return nil
function SoundSource:Stop() end

--- Stop immediately without the de-click fade.
---@return nil
function SoundSource:StopImmediate() end

--- Enable or disable the short fade used by Stop and Play.
---@param enable boolean
---@return nil
function SoundSource:SetDeclickEnabled(enable) end

--- Return whether de-click fading is enabled.
---@return boolean
function SoundSource:GetDeclickEnabled() end

--- Set the sound type used for per-type and master gain control.
--- Use SOUND_EFFECT, SOUND_AMBIENT, SOUND_VOICE, or SOUND_MUSIC; SOUND_MASTER is reserved.
---@param type string
---@return nil
function SoundSource:SetSoundType(type) end

--- Set the absolute playback frequency. This changes the SoundSource, not the Sound resource.
---@param frequency number Playback frequency in Hz, not a pitch multiplier; 0 is resolved by the next Play(Sound*) call
---@return nil
function SoundSource:SetFrequency(frequency) end

--- Set the exact linear source gain. 0 is silence and 1 is full source gain.
---@param gain number
---@return nil
function SoundSource:SetGain(gain) end

--- Set a linear attenuation multiplier. 1 is unaltered and 0 is silence.
--- SoundSource is already non-positional; do not use 0 to disable 3D behavior.
---@param attenuation number
---@return nil
function SoundSource:SetAttenuation(attenuation) end

--- Set stereo panning: -1 is full left, 0 is center, and 1 is full right.
--- It affects mono sources mixed to stereo output; stereo sources and mono output ignore it.
---@param panning number
---@return nil
function SoundSource:SetPanning(panning) end

--- Set automatic removal after playback completes.
---@param mode AutoRemoveMode
---@return nil
function SoundSource:SetAutoRemoveMode(mode) end

--- Return the resource currently assigned to the source.
---@return Sound
function SoundSource:GetSound() end

--- Return the source sound type.
---@return string
function SoundSource:GetSoundType() end

--- Return the current playback position in seconds. It advances when the mixer processes the source.
---@return number
function SoundSource:GetTimePosition() end

--- Return the current absolute playback frequency of this SoundSource.
---@return number # playback frequency in Hz
function SoundSource:GetFrequency() end

--- Return the linear source gain.
---@return number
function SoundSource:GetGain() end

--- Return the linear attenuation multiplier.
---@return number
function SoundSource:GetAttenuation() end

--- Return stereo panning. It is effective only for mono sources mixed to stereo output.
---@return number
function SoundSource:GetPanning() end

--- Return the automatic removal mode.
---@return AutoRemoveMode
function SoundSource:GetAutoRemoveMode() end

--- Return whether is playing. Returns true during fade-in, false during fade-out.
---@return boolean
function SoundSource:IsPlaying() end

--- Return whether a fade-in is in progress.
---@return boolean
function SoundSource:IsFadingIn() end

--- Return whether a fade-out is in progress.
---@return boolean
function SoundSource:IsFadingOut() end

