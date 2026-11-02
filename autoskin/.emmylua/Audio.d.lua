---@meta

--- Auto-generated from Audio/Audio

---@class Audio : Object
---@field sampleSize integer Bytes per mixed output frame.
---@field mixRate integer Actual output mix rate in Hz.
---@field interpolation boolean Whether source sample interpolation is enabled.
---@field stereo boolean Whether the output device is stereo.
---@field playing boolean Whether the output device is currently mixing.
---@field initialized boolean Whether an output device is initialized.
---@field listener SoundListener Listener used for SoundSource3D attenuation; SoundSource does not use it.
Audio = {}

--- Initialize the output device and start playback.
---@param bufferLengthMSec integer Requested output buffer length in milliseconds; values below 20 are clamped.
---@param mixRate integer Requested mix rate in Hz; the backend clamps it to its supported range.
---@param stereo boolean Whether to request stereo output.
---@param interpolation? boolean Whether sound samples use interpolation during mixing.
---@return boolean # true when the device was initialized and playback started.
function Audio:SetMode(bufferLengthMSec, mixRate, stereo, interpolation) end

--- Start mixing to an initialized output device. Calling this repeatedly is harmless.
---@return boolean # false when SetMode has not initialized an output device.
function Audio:Play() end

--- Stop mixing without releasing the initialized output device.
---@return nil
function Audio:Stop() end

--- Set the linear master gain for a sound type. Values are clamped to [0, 1].
--- Use SOUND_MASTER, SOUND_EFFECT, SOUND_AMBIENT, SOUND_VOICE, or SOUND_MUSIC.
---@param type string
---@param gain number
---@return nil
function Audio:SetMasterGain(type, gain) end

--- Pause all sound sources whose sound type matches type. This does not stop the output device.
---@param type string
---@return nil
function Audio:PauseSoundType(type) end

--- Resume sound sources whose sound type matches type.
---@param type string
---@return nil
function Audio:ResumeSoundType(type) end

--- Clear all sound-type pauses. This does not unlock a browser AudioContext or start a stopped device.
---@return nil
function Audio:ResumeAll() end

--- Set the listener used by SoundSource3D. SoundSource is non-positional and does not use the listener.
--- The listener must be sceneless or belong to the same scene as a SoundSource3D to avoid full attenuation.
---@param listener SoundListener
---@return nil
function Audio:SetListener(listener) end

--- Stop every registered source currently playing the specified sound resource.
---@param sound Sound
---@return nil
function Audio:StopSound(sound) end

--- Return bytes per mixed output frame (typically 2 for mono or 4 for stereo 16-bit output).
---@return integer
function Audio:GetSampleSize() end

--- Return the actual output mix rate selected by the backend, in Hz.
---@return integer
function Audio:GetMixRate() end

--- Return whether sample interpolation is enabled for source mixing.
---@return boolean
function Audio:GetInterpolation() end

--- Return whether the initialized output device has two channels.
---@return boolean
function Audio:IsStereo() end

--- Return whether the output device is currently mixing. This is not a browser AudioContext state query.
---@return boolean
function Audio:IsPlaying() end

--- Return whether an output device is initialized. An initialized device may still be stopped or suspended by the host.
---@return boolean
function Audio:IsInitialized() end

--- Return whether an explicit master gain entry exists for the sound type.
---@param type string
---@return boolean
function Audio:HasMasterGain(type) end

--- Return the explicit gain for a sound type. Unknown types return 1; source mixing separately applies SOUND_MASTER.
---@param type string
---@return number
function Audio:GetMasterGain(type) end

--- Return whether the sound type is currently paused.
---@param type string
---@return boolean
function Audio:IsSoundTypePaused(type) end

--- Return the listener used by SoundSource3D, or nil when none is assigned.
---@return SoundListener
function Audio:GetListener() end

--- Return all sound sources registered with this audio subsystem.
---@return SoundSource[]
function Audio:GetSoundSources() end

-- Method MixOutput is not supported (uses void* pointer)


-- Global functions
---@return Audio
function GetAudio() end

-- Global variables
---@type string
SOUND_MASTER = nil
---@type string
SOUND_EFFECT = nil
---@type string
SOUND_AMBIENT = nil
---@type string
SOUND_VOICE = nil
---@type string
SOUND_MUSIC = nil
---@type Audio
audio = nil
