---@meta

--- Auto-generated from Audio/Sound

---@class Sound : ResourceWithMetadata
---@overload fun(): Sound
---@field length number Length in seconds.
---@field dataSize integer Raw data size in bytes.
---@field sampleSize integer Bytes per interleaved sample frame.
---@field frequency number Default sample rate in Hz as a float.
---@field intFrequency integer Default sample rate in Hz as an integer.
---@field looped boolean Whether playback loops.
---@field sixteenBit boolean Whether samples use 16-bit encoding.
---@field stereo boolean Whether samples have two interleaved channels.
---@field compressed boolean Whether the resource is compressed.
Sound = {}

---@return Sound
function Sound.new() end

--- Load raw bytes. Raw data keeps the Sound object's current format; call SetFormat explicitly because raw bytes do not carry format metadata.
---@param source Deserializer
---@return boolean
function Sound:LoadRaw(source) end

--- Load raw bytes from a file path using the Sound object's current format; call SetFormat explicitly.
---@param fileName string
---@return boolean
function Sound:LoadRaw(fileName) end

--- Load an uncompressed WAV resource and read its format from the file header.
---@param source Deserializer
---@return boolean
function Sound:LoadWav(source) end

--- Load WAV data from a file path.
---@param fileName string
---@return boolean
function Sound:LoadWav(fileName) end

--- Load Ogg Vorbis data. Decoding is performed while the sound is played.
---@param source Deserializer
---@return boolean
function Sound:LoadOggVorbis(source) end

--- Load Ogg Vorbis data from a file path.
---@param fileName string
---@return boolean
function Sound:LoadOggVorbis(fileName) end

--- Load MP3 data. Decoding is performed while the sound is played.
---@param source Deserializer
---@return boolean
function Sound:LoadMp3(source) end

--- Load MP3 data from a file path.
---@param fileName string
---@return boolean
function Sound:LoadMp3(fileName) end

--- Allocate uncompressed sound data. This resets the sound to one-shot raw data.
---@param dataSize integer
---@return nil
function Sound:SetSize(dataSize) end

-- Method SetData is not supported (uses void* pointer)

--- Set uncompressed sound data format.
---@param frequency integer Sample rate in Hz
---@param sixteenBit boolean Whether samples use 16-bit encoding
---@param stereo boolean Whether samples have two channels
---@return nil
function Sound:SetFormat(frequency, sixteenBit, stereo) end

--- Enable or disable looping. Enabling uses the entire sound as the loop range.
---@param enable boolean
---@return nil
function Sound:SetLooped(enable) end

--- Set the loop range for uncompressed data. Offsets are bytes and are aligned to sample boundaries.
--- For compressed data, the range is not used; the decoded stream is either looped or not.
---@param repeatOffset integer
---@param endOffset integer
---@return nil
function Sound:SetLoop(repeatOffset, endOffset) end

--- Rebuild interpolation safety samples after modifying raw data or loop boundaries.
---@return nil
function Sound:FixInterpolation() end

--- Return the sound length in seconds.
---@return number
function Sound:GetLength() end

--- Return the raw data size in bytes.
---@return integer
function Sound:GetDataSize() end

--- Return bytes per interleaved sample frame (1 or 2 bytes per channel sample, multiplied by channel count).
---@return integer
function Sound:GetSampleSize() end

--- Return the sound resource's default sample rate without changing it.
---@return number # sample rate in Hz
function Sound:GetFrequency() end

--- Return the sound resource's default sample rate as an integer without changing it.
---@return integer # sample rate in Hz
function Sound:GetIntFrequency() end

--- Return whether playback loops.
---@return boolean
function Sound:IsLooped() end

--- Return whether samples use 16-bit encoding.
---@return boolean
function Sound:IsSixteenBit() end

--- Return whether samples have two interleaved channels.
---@return boolean
function Sound:IsStereo() end

--- Return whether the resource is compressed and decoded through a streaming decoder.
---@return boolean
function Sound:IsCompressed() end

