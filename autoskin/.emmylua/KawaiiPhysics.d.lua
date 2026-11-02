---@meta

--- Auto-generated from Animation/KawaiiPhysics

---@alias KawaiiPhysicsBoneForwardAxis
---| integer # KawaiiPhysicsBoneForwardAxis enum values

---@type KawaiiPhysicsBoneForwardAxis
--- Serialized as "X_Positive".
KAWAII_PHYSICS_BONE_FORWARD_X_POSITIVE = KAWAII_PHYSICS_BONE_FORWARD_X_POSITIVE
---@type KawaiiPhysicsBoneForwardAxis
--- Serialized as "X_Negative".
KAWAII_PHYSICS_BONE_FORWARD_X_NEGATIVE = KAWAII_PHYSICS_BONE_FORWARD_X_NEGATIVE
---@type KawaiiPhysicsBoneForwardAxis
--- Serialized as "Y_Positive".
KAWAII_PHYSICS_BONE_FORWARD_Y_POSITIVE = KAWAII_PHYSICS_BONE_FORWARD_Y_POSITIVE
---@type KawaiiPhysicsBoneForwardAxis
--- Serialized as "Y_Negative".
KAWAII_PHYSICS_BONE_FORWARD_Y_NEGATIVE = KAWAII_PHYSICS_BONE_FORWARD_Y_NEGATIVE
---@type KawaiiPhysicsBoneForwardAxis
--- Serialized as "Z_Positive".
KAWAII_PHYSICS_BONE_FORWARD_Z_POSITIVE = KAWAII_PHYSICS_BONE_FORWARD_Z_POSITIVE
---@type KawaiiPhysicsBoneForwardAxis
--- Serialized as "Z_Negative".
KAWAII_PHYSICS_BONE_FORWARD_Z_NEGATIVE = KAWAII_PHYSICS_BONE_FORWARD_Z_NEGATIVE

---@alias KawaiiPhysicsPlanarConstraint
---| integer # KawaiiPhysicsPlanarConstraint enum values

---@type KawaiiPhysicsPlanarConstraint
--- Serialized as "None".
KAWAII_PHYSICS_PLANAR_CONSTRAINT_NONE = KAWAII_PHYSICS_PLANAR_CONSTRAINT_NONE
---@type KawaiiPhysicsPlanarConstraint
--- Serialized as "X".
KAWAII_PHYSICS_PLANAR_CONSTRAINT_X = KAWAII_PHYSICS_PLANAR_CONSTRAINT_X
---@type KawaiiPhysicsPlanarConstraint
--- Serialized as "Y".
KAWAII_PHYSICS_PLANAR_CONSTRAINT_Y = KAWAII_PHYSICS_PLANAR_CONSTRAINT_Y
---@type KawaiiPhysicsPlanarConstraint
--- Serialized as "Z".
KAWAII_PHYSICS_PLANAR_CONSTRAINT_Z = KAWAII_PHYSICS_PLANAR_CONSTRAINT_Z

---@alias KawaiiPhysicsSphericalLimitType
---| integer # KawaiiPhysicsSphericalLimitType enum values

---@type KawaiiPhysicsSphericalLimitType
--- Serialized as "Outer".
KAWAII_PHYSICS_SPHERICAL_LIMIT_OUTER = KAWAII_PHYSICS_SPHERICAL_LIMIT_OUTER
---@type KawaiiPhysicsSphericalLimitType
--- Serialized as "Inner".
KAWAII_PHYSICS_SPHERICAL_LIMIT_INNER = KAWAII_PHYSICS_SPHERICAL_LIMIT_INNER

---@alias KawaiiPhysicsSimulationSpace
---| integer # KawaiiPhysicsSimulationSpace enum values

---@type KawaiiPhysicsSimulationSpace
--- Serialized as "ComponentSpace".
KAWAII_PHYSICS_SIMULATION_COMPONENT_SPACE = KAWAII_PHYSICS_SIMULATION_COMPONENT_SPACE
---@type KawaiiPhysicsSimulationSpace
--- Serialized as "WorldSpace".
KAWAII_PHYSICS_SIMULATION_WORLD_SPACE = KAWAII_PHYSICS_SIMULATION_WORLD_SPACE
---@type KawaiiPhysicsSimulationSpace
--- Serialized as "BaseBoneSpace".
KAWAII_PHYSICS_SIMULATION_BASE_BONE_SPACE = KAWAII_PHYSICS_SIMULATION_BASE_BONE_SPACE

---@alias KawaiiPhysicsXPBDComplianceType
---| integer # KawaiiPhysicsXPBDComplianceType enum values

---@type KawaiiPhysicsXPBDComplianceType
--- Serialized as "Concrete".
KAWAII_PHYSICS_XPBD_COMPLIANCE_CONCRETE = KAWAII_PHYSICS_XPBD_COMPLIANCE_CONCRETE
---@type KawaiiPhysicsXPBDComplianceType
--- Serialized as "Wood".
KAWAII_PHYSICS_XPBD_COMPLIANCE_WOOD = KAWAII_PHYSICS_XPBD_COMPLIANCE_WOOD
---@type KawaiiPhysicsXPBDComplianceType
--- Serialized as "Leather".
KAWAII_PHYSICS_XPBD_COMPLIANCE_LEATHER = KAWAII_PHYSICS_XPBD_COMPLIANCE_LEATHER
---@type KawaiiPhysicsXPBDComplianceType
--- Serialized as "Tendon".
KAWAII_PHYSICS_XPBD_COMPLIANCE_TENDON = KAWAII_PHYSICS_XPBD_COMPLIANCE_TENDON
---@type KawaiiPhysicsXPBDComplianceType
--- Serialized as "Rubber".
KAWAII_PHYSICS_XPBD_COMPLIANCE_RUBBER = KAWAII_PHYSICS_XPBD_COMPLIANCE_RUBBER
---@type KawaiiPhysicsXPBDComplianceType
--- Serialized as "Muscle".
KAWAII_PHYSICS_XPBD_COMPLIANCE_MUSCLE = KAWAII_PHYSICS_XPBD_COMPLIANCE_MUSCLE
---@type KawaiiPhysicsXPBDComplianceType
--- Serialized as "Fat".
KAWAII_PHYSICS_XPBD_COMPLIANCE_FAT = KAWAII_PHYSICS_XPBD_COMPLIANCE_FAT

---@alias KawaiiPhysicsSyncBoneDirection
---| integer # KawaiiPhysicsSyncBoneDirection enum values

---@type KawaiiPhysicsSyncBoneDirection
--- Serialized as "Both".
KAWAII_PHYSICS_SYNC_BONE_DIRECTION_BOTH = KAWAII_PHYSICS_SYNC_BONE_DIRECTION_BOTH
---@type KawaiiPhysicsSyncBoneDirection
--- Serialized as "Positive".
KAWAII_PHYSICS_SYNC_BONE_DIRECTION_POSITIVE = KAWAII_PHYSICS_SYNC_BONE_DIRECTION_POSITIVE
---@type KawaiiPhysicsSyncBoneDirection
--- Serialized as "Negative".
KAWAII_PHYSICS_SYNC_BONE_DIRECTION_NEGATIVE = KAWAII_PHYSICS_SYNC_BONE_DIRECTION_NEGATIVE
---@type KawaiiPhysicsSyncBoneDirection
--- Serialized as "None".
KAWAII_PHYSICS_SYNC_BONE_DIRECTION_NONE = KAWAII_PHYSICS_SYNC_BONE_DIRECTION_NONE

---@class KawaiiPhysicsSettings
---@overload fun(): KawaiiPhysicsSettings
---@field damping number Serialized as "Damping".
---@field stiffness number Serialized as "Stiffness".
---@field worldDampingLocation number Serialized as "World Damping Location".
---@field worldDampingRotation number Serialized as "World Damping Rotation".
---@field radius number Serialized as "Radius".
---@field limitAngle number Serialized as "Limit Angle".
KawaiiPhysicsSettings = {}

---@return KawaiiPhysicsSettings
function KawaiiPhysicsSettings.new() end


---@class KawaiiPhysicsRootBoneSetting
---@overload fun(): KawaiiPhysicsRootBoneSetting
---@field rootBone string Serialized as "Root Bone".
---@field overrideExcludeBones string[] Serialized as "Override Exclude Bones".
---@field useOverrideExcludeBones boolean Serialized as "Use Override Exclude Bones".
KawaiiPhysicsRootBoneSetting = {}

---@return KawaiiPhysicsRootBoneSetting
function KawaiiPhysicsRootBoneSetting.new() end


---@class KawaiiPhysicsCollisionLimitBase
---@field drivingBone string Serialized as "Driving Bone".
---@field offsetLocation Vector3 Serialized as "Offset Location".
---@field offsetRotation Quaternion Serialized as "Offset Rotation".
KawaiiPhysicsCollisionLimitBase = {}


---@class KawaiiPhysicsSphericalLimit : KawaiiPhysicsCollisionLimitBase
---@overload fun(): KawaiiPhysicsSphericalLimit
---@field radius number Serialized as "Radius".
---@field limitType KawaiiPhysicsSphericalLimitType Serialized as "Limit Type".
KawaiiPhysicsSphericalLimit = {}

---@return KawaiiPhysicsSphericalLimit
function KawaiiPhysicsSphericalLimit.new() end


---@class KawaiiPhysicsCapsuleLimit : KawaiiPhysicsCollisionLimitBase
---@overload fun(): KawaiiPhysicsCapsuleLimit
---@field radius number Serialized as "Radius".
---@field length number Serialized as "Length".
KawaiiPhysicsCapsuleLimit = {}

---@return KawaiiPhysicsCapsuleLimit
function KawaiiPhysicsCapsuleLimit.new() end


---@class KawaiiPhysicsBoxLimit : KawaiiPhysicsCollisionLimitBase
---@overload fun(): KawaiiPhysicsBoxLimit
---@field extent Vector3 Half size of the box along its local axes. Serialized as "Extent".
KawaiiPhysicsBoxLimit = {}

---@return KawaiiPhysicsBoxLimit
function KawaiiPhysicsBoxLimit.new() end


---@class KawaiiPhysicsPlanarLimit : KawaiiPhysicsCollisionLimitBase
---@overload fun(): KawaiiPhysicsPlanarLimit
KawaiiPhysicsPlanarLimit = {}

---@return KawaiiPhysicsPlanarLimit
function KawaiiPhysicsPlanarLimit.new() end


---@class KawaiiPhysicsModifyBoneConstraint
---@overload fun(): KawaiiPhysicsModifyBoneConstraint
---@field bone1 string Serialized as "Bone 1".
---@field bone2 string Serialized as "Bone 2".
---@field overrideCompliance boolean Serialized as "Override Compliance".
---@field complianceType KawaiiPhysicsXPBDComplianceType Serialized as "Compliance Type".
---@field excludeFromSubdivision boolean Serialized as "Exclude From Subdivision".
KawaiiPhysicsModifyBoneConstraint = {}

---@return KawaiiPhysicsModifyBoneConstraint
function KawaiiPhysicsModifyBoneConstraint.new() end


---@class KawaiiPhysicsSyncTargetRoot
---@overload fun(): KawaiiPhysicsSyncTargetRoot
---@field bone string Serialized as "Bone".
---@field includeChildBones boolean Serialized as "Include Child Bones".
---@field scaleCurveByBoneLengthRate FloatCurve Scale by length rate from this root (X: length rate, Y: scale); empty applies the full movement. Serialized as "Scale Curve By Bone Length Rate".
KawaiiPhysicsSyncTargetRoot = {}

---@return KawaiiPhysicsSyncTargetRoot
function KawaiiPhysicsSyncTargetRoot.new() end


---@class KawaiiPhysicsSyncBone
---@overload fun(): KawaiiPhysicsSyncBone
---@field bone string Serialized as "Bone".
---@field globalScale Vector3 Overall scale per axis, clamped to [0, 1] when applied to the component. Serialized as "Global Scale".
---@field scaleCurveByDeltaDistance FloatCurve Scale by movement distance (X: distance, Y: scale); empty applies the full movement. Serialized as "Scale Curve By Delta Distance".
---@field applyDirectionX KawaiiPhysicsSyncBoneDirection Serialized as "Apply Direction X".
---@field applyDirectionY KawaiiPhysicsSyncBoneDirection Serialized as "Apply Direction Y".
---@field applyDirectionZ KawaiiPhysicsSyncBoneDirection Serialized as "Apply Direction Z".
---@field enableDistanceAttenuation boolean Serialized as "Enable Distance Attenuation".
---@field attenuationInnerRadius number Serialized as "Attenuation Inner Radius".
---@field attenuationOuterRadius number Serialized as "Attenuation Outer Radius".
---@field maxAttenuationRate number Serialized as "Max Attenuation Rate".
KawaiiPhysicsSyncBone = {}

---@return KawaiiPhysicsSyncBone
function KawaiiPhysicsSyncBone.new() end

--- Add, read or replace target roots; indices are zero-based. Serialized as "Target Roots".
---@param value KawaiiPhysicsSyncTargetRoot
---@return nil
function KawaiiPhysicsSyncBone:AddTargetRoot(value) end

---@return nil
function KawaiiPhysicsSyncBone:ClearTargetRoots() end

---@return integer
function KawaiiPhysicsSyncBone:GetNumTargetRoots() end

---@param index integer
---@return KawaiiPhysicsSyncTargetRoot
function KawaiiPhysicsSyncBone:GetTargetRoot(index) end

---@param index integer
---@param value KawaiiPhysicsSyncTargetRoot
---@return boolean
function KawaiiPhysicsSyncBone:SetTargetRoot(index, value) end


---@class KawaiiPhysics : Component
---@overload fun(context: Context): KawaiiPhysics
---@overload fun(): KawaiiPhysics
---@field alpha number
---@field diagnostic string
KawaiiPhysics = {}

---@overload fun(self: KawaiiPhysics, context: Context): KawaiiPhysics
---@overload fun(context: Context): KawaiiPhysics
---@return KawaiiPhysics
function KawaiiPhysics.new() end

--- Rebuild the simulated hierarchy from this root bone. Serialized as "Root Bone".
---@param value string
---@return nil
function KawaiiPhysics:SetRootBoneName(value) end

---@return string
function KawaiiPhysics:GetRootBoneName() end

--- Exclude these bones and their descendants from simulation; output descendants still follow their parent. Serialized as "Exclude Bones".
---@param value string[]
---@return nil
function KawaiiPhysics:SetExcludeBoneNames(value) end

---@return string[]
function KawaiiPhysics:GetExcludeBoneNames() end

--- Set terminal dummy length in simulation units; zero disables terminal dummies. Serialized as "Dummy Bone Length".
---@param value number
---@return nil
function KawaiiPhysics:SetDummyBoneLength(value) end

---@return number
function KawaiiPhysics:GetDummyBoneLength() end

--- Set the minimum inter-bone dummy count, clamped to [0, 10]; zero disables bone subdivision. Serialized as "Bone Subdivision Count".
---@param value integer
---@return nil
function KawaiiPhysics:SetBoneSubdivisionCount(value) end

---@return integer
function KawaiiPhysics:GetBoneSubdivisionCount() end

--- Inter-bone dummies skip integration and are placed between their real endpoints. Serialized as "Bone Subdivision Collision Only".
---@param value boolean
---@return nil
function KawaiiPhysics:SetBoneSubdivisionCollisionOnly(value) end

---@return boolean
function KawaiiPhysics:GetBoneSubdivisionCollisionOnly() end

--- Add dummies where a segment is long relative to the collision radius. Serialized as "Bone Subdivision Densify By Radius".
---@param value boolean
---@return nil
function KawaiiPhysics:SetBoneSubdivisionDensifyByRadius(value) end

---@return boolean
function KawaiiPhysics:GetBoneSubdivisionDensifyByRadius() end

--- Bridge collision-proxy dummies per bone constraint, clamped to [0, 10]; zero disables them. Serialized as "Bone Constraint Subdivision Count".
---@param value integer
---@return nil
function KawaiiPhysics:SetBoneConstraintSubdivisionCount(value) end

---@return integer
function KawaiiPhysics:GetBoneConstraintSubdivisionCount() end

--- Strength of passing a bridge dummy's collision push to its endpoints, clamped to [0, 2]. Serialized as "Bone Constraint Subdivision Feedback Scale".
---@param value number
---@return nil
function KawaiiPhysics:SetBoneConstraintSubdivisionFeedbackScale(value) end

---@return number
function KawaiiPhysics:GetBoneConstraintSubdivisionFeedbackScale() end

--- Compliance of bone constraints that do not override it. Serialized as "Bone Constraint Global Compliance Type".
---@param value KawaiiPhysicsXPBDComplianceType
---@return nil
function KawaiiPhysics:SetBoneConstraintGlobalComplianceType(value) end

---@return KawaiiPhysicsXPBDComplianceType
function KawaiiPhysics:GetBoneConstraintGlobalComplianceType() end

--- Bone constraint passes before and after collision, clamped to nonnegative. Serialized as "Bone Constraint Iteration Count Before Collision".
---@param value integer
---@return nil
function KawaiiPhysics:SetBoneConstraintIterationCountBeforeCollision(value) end

---@return integer
function KawaiiPhysics:GetBoneConstraintIterationCountBeforeCollision() end

--- Serialized as "Bone Constraint Iteration Count After Collision".
---@param value integer
---@return nil
function KawaiiPhysics:SetBoneConstraintIterationCountAfterCollision(value) end

---@return integer
function KawaiiPhysics:GetBoneConstraintIterationCountAfterCollision() end

--- Also constrain the virtual tips and inter-bone dummies of constrained bones. Serialized as "Auto Add Child Dummy Bone Constraint".
---@param value boolean
---@return nil
function KawaiiPhysics:SetAutoAddChildDummyBoneConstraint(value) end

---@return boolean
function KawaiiPhysics:GetAutoAddChildDummyBoneConstraint() end

--- Simple external force: a constant velocity added to positions, in world space by default. Serialized as "Simple External Force".
---@param value Vector3
---@return nil
function KawaiiPhysics:SetSimpleExternalForce(value) end

---@return Vector3
function KawaiiPhysics:GetSimpleExternalForce() end

--- Serialized as "Use World Space Simple External Force".
---@param value boolean
---@return nil
function KawaiiPhysics:SetUseWorldSpaceSimpleExternalForce(value) end

---@return boolean
function KawaiiPhysics:GetUseWorldSpaceSimpleExternalForce() end

--- Set base physics settings; curves multiply these values.
---@param value KawaiiPhysicsSettings
---@return nil
function KawaiiPhysics:SetPhysicsSettings(value) end

---@return KawaiiPhysicsSettings
function KawaiiPhysics:GetPhysicsSettings() end

--- Set gravity acceleration, in world space by default. Serialized as "Gravity".
---@param value Vector3
---@return nil
function KawaiiPhysics:SetGravity(value) end

---@return Vector3
function KawaiiPhysics:GetGravity() end

--- Set automatic teleport distance; zero disables the distance test. Serialized as "Teleport Distance Threshold".
---@param value number
---@return nil
function KawaiiPhysics:SetTeleportDistanceThreshold(value) end

---@return number
function KawaiiPhysics:GetTeleportDistanceThreshold() end

--- Set automatic teleport angle in degrees; zero disables the angle test. Serialized as "Teleport Rotation Threshold".
---@param value number
---@return nil
function KawaiiPhysics:SetTeleportRotationThreshold(value) end

---@return number
function KawaiiPhysics:GetTeleportRotationThreshold() end

--- Select the imported bone local forward axis. Serialized as "Bone Forward Axis".
---@param value KawaiiPhysicsBoneForwardAxis
---@return nil
function KawaiiPhysics:SetBoneForwardAxis(value) end

---@return KawaiiPhysicsBoneForwardAxis
function KawaiiPhysics:GetBoneForwardAxis() end

--- Set simulation frequency in Hz; values below 1 are clamped to 1. Serialized as "Target Framerate".
---@param value integer
---@return nil
function KawaiiPhysics:SetTargetFramerate(value) end

---@return integer
function KawaiiPhysics:GetTargetFramerate() end

--- Constrain particles to the selected parent-pose plane. Serialized as "Planar Constraint".
---@param value KawaiiPhysicsPlanarConstraint
---@return nil
function KawaiiPhysics:SetPlanarConstraint(value) end

---@return KawaiiPhysicsPlanarConstraint
function KawaiiPhysics:GetPlanarConstraint() end

--- Scale each component of character motion before applying movement following. Serialized as "Skel Comp Move Scale".
---@param value Vector3
---@return nil
function KawaiiPhysics:SetSkelCompMoveScale(value) end

---@return Vector3
function KawaiiPhysics:GetSkelCompMoveScale() end

--- Set the number of simulation iterations used by requested warm-up. Serialized as "Warm Up Frames".
---@param value integer
---@return nil
function KawaiiPhysics:SetWarmUpFrames(value) end

---@return integer
function KawaiiPhysics:GetWarmUpFrames() end

--- Request warm-up when dynamics are reset or teleported. Serialized as "Use Warm Up When Reset Dynamics".
---@param value boolean
---@return nil
function KawaiiPhysics:SetUseWarmUpWhenResetDynamics(value) end

---@return boolean
function KawaiiPhysics:GetUseWarmUpWhenResetDynamics() end

--- Interpret gravity in world space when true, otherwise in component space. Serialized as "Use World Space Gravity".
---@param value boolean
---@return nil
function KawaiiPhysics:SetUseWorldSpaceGravity(value) end

---@return boolean
function KawaiiPhysics:GetUseWorldSpaceGravity() end

--- Use fixed substeps; configuration is per component. Serialized as "Use Fixed Substepping".
---@param value boolean
---@return nil
function KawaiiPhysics:SetUseFixedSubstepping(value) end

---@return boolean
function KawaiiPhysics:GetUseFixedSubstepping() end

--- Limit fixed substeps per evaluation, clamped to 1..16; excess elapsed time is discarded. Serialized as "Max Substeps".
---@param value integer
---@return nil
function KawaiiPhysics:SetMaxSubsteps(value) end

---@return integer
function KawaiiPhysics:GetMaxSubsteps() end

--- Select simulation reference space; existing particle history is converted. Serialized as "Simulation Space".
---@param value KawaiiPhysicsSimulationSpace
---@return nil
function KawaiiPhysics:SetSimulationSpace(value) end

---@return KawaiiPhysicsSimulationSpace
function KawaiiPhysics:GetSimulationSpace() end

--- Set the reference bone used by BaseBoneSpace. Serialized as "Simulation Base Bone".
---@param value string
---@return nil
function KawaiiPhysics:SetSimulationBaseBoneName(value) end

---@return string
function KawaiiPhysics:GetSimulationBaseBoneName() end

--- Add, read or replace configuration values; indices are zero-based. Out-of-range fields are clamped. Serialized as "Additional Root Bones".
---@param value KawaiiPhysicsRootBoneSetting
---@return nil
function KawaiiPhysics:AddAdditionalRootBone(value) end

---@return nil
function KawaiiPhysics:ClearAdditionalRootBones() end

---@return integer
function KawaiiPhysics:GetNumAdditionalRootBones() end

---@param index integer
---@return KawaiiPhysicsRootBoneSetting
function KawaiiPhysics:GetAdditionalRootBone(index) end

---@param index integer
---@param value KawaiiPhysicsRootBoneSetting
---@return boolean
function KawaiiPhysics:SetAdditionalRootBone(index, value) end

--- Add, read or replace configuration values; indices are zero-based. Out-of-range fields are clamped. Serialized as "Spherical Limits".
---@param value KawaiiPhysicsSphericalLimit
---@return nil
function KawaiiPhysics:AddSphericalLimit(value) end

---@return nil
function KawaiiPhysics:ClearSphericalLimits() end

---@return integer
function KawaiiPhysics:GetNumSphericalLimits() end

---@param index integer
---@return KawaiiPhysicsSphericalLimit
function KawaiiPhysics:GetSphericalLimit(index) end

---@param index integer
---@param value KawaiiPhysicsSphericalLimit
---@return boolean
function KawaiiPhysics:SetSphericalLimit(index, value) end

--- Add, read or replace configuration values; indices are zero-based. Out-of-range fields are clamped. Serialized as "Capsule Limits".
---@param value KawaiiPhysicsCapsuleLimit
---@return nil
function KawaiiPhysics:AddCapsuleLimit(value) end

---@return nil
function KawaiiPhysics:ClearCapsuleLimits() end

---@return integer
function KawaiiPhysics:GetNumCapsuleLimits() end

---@param index integer
---@return KawaiiPhysicsCapsuleLimit
function KawaiiPhysics:GetCapsuleLimit(index) end

---@param index integer
---@param value KawaiiPhysicsCapsuleLimit
---@return boolean
function KawaiiPhysics:SetCapsuleLimit(index, value) end

--- Add, read or replace configuration values; indices are zero-based. Out-of-range fields are clamped. Serialized as "Box Limits".
---@param value KawaiiPhysicsBoxLimit
---@return nil
function KawaiiPhysics:AddBoxLimit(value) end

---@return nil
function KawaiiPhysics:ClearBoxLimits() end

---@return integer
function KawaiiPhysics:GetNumBoxLimits() end

---@param index integer
---@return KawaiiPhysicsBoxLimit
function KawaiiPhysics:GetBoxLimit(index) end

---@param index integer
---@param value KawaiiPhysicsBoxLimit
---@return boolean
function KawaiiPhysics:SetBoxLimit(index, value) end

--- Add, read or replace configuration values; indices are zero-based. Out-of-range fields are clamped. Serialized as "Planar Limits".
---@param value KawaiiPhysicsPlanarLimit
---@return nil
function KawaiiPhysics:AddPlanarLimit(value) end

---@return nil
function KawaiiPhysics:ClearPlanarLimits() end

---@return integer
function KawaiiPhysics:GetNumPlanarLimits() end

---@param index integer
---@return KawaiiPhysicsPlanarLimit
function KawaiiPhysics:GetPlanarLimit(index) end

---@param index integer
---@param value KawaiiPhysicsPlanarLimit
---@return boolean
function KawaiiPhysics:SetPlanarLimit(index, value) end

--- Add, read or replace bone constraints; a change re-pairs them on the existing chain and keeps the swing. Serialized as "Bone Constraints".
---@param value KawaiiPhysicsModifyBoneConstraint
---@return nil
function KawaiiPhysics:AddBoneConstraint(value) end

---@return nil
function KawaiiPhysics:ClearBoneConstraints() end

---@return integer
function KawaiiPhysics:GetNumBoneConstraints() end

---@param index integer
---@return KawaiiPhysicsModifyBoneConstraint
function KawaiiPhysics:GetBoneConstraint(index) end

---@param index integer
---@param value KawaiiPhysicsModifyBoneConstraint
---@return boolean
function KawaiiPhysics:SetBoneConstraint(index, value) end

--- Add, read or replace sync bones; a change re-resolves targets and keeps the swing. Out-of-range fields are clamped. Serialized as "Sync Bones".
---@param value KawaiiPhysicsSyncBone
---@return nil
function KawaiiPhysics:AddSyncBone(value) end

---@return nil
function KawaiiPhysics:ClearSyncBones() end

---@return integer
function KawaiiPhysics:GetNumSyncBones() end

---@param index integer
---@return KawaiiPhysicsSyncBone
function KawaiiPhysics:GetSyncBone(index) end

---@param index integer
---@param value KawaiiPhysicsSyncBone
---@return boolean
function KawaiiPhysics:SetSyncBone(index, value) end

--- Set the multiplier curve sampled at normalized bone-chain length. Serialized as "Damping Curve Data".
---@param value FloatCurve
---@return nil
function KawaiiPhysics:SetDampingCurveData(value) end

---@return FloatCurve
function KawaiiPhysics:GetDampingCurveData() end

--- Set the multiplier curve sampled at normalized bone-chain length. Serialized as "Stiffness Curve Data".
---@param value FloatCurve
---@return nil
function KawaiiPhysics:SetStiffnessCurveData(value) end

---@return FloatCurve
function KawaiiPhysics:GetStiffnessCurveData() end

--- Set the multiplier curve sampled at normalized bone-chain length. Serialized as "World Damping Location Curve Data".
---@param value FloatCurve
---@return nil
function KawaiiPhysics:SetWorldDampingLocationCurveData(value) end

---@return FloatCurve
function KawaiiPhysics:GetWorldDampingLocationCurveData() end

--- Set the multiplier curve sampled at normalized bone-chain length. Serialized as "World Damping Rotation Curve Data".
---@param value FloatCurve
---@return nil
function KawaiiPhysics:SetWorldDampingRotationCurveData(value) end

---@return FloatCurve
function KawaiiPhysics:GetWorldDampingRotationCurveData() end

--- Set the multiplier curve sampled at normalized bone-chain length. Serialized as "Radius Curve Data".
---@param value FloatCurve
---@return nil
function KawaiiPhysics:SetRadiusCurveData(value) end

---@return FloatCurve
function KawaiiPhysics:GetRadiusCurveData() end

--- Set the multiplier curve sampled at normalized bone-chain length. Serialized as "Limit Angle Curve Data".
---@param value FloatCurve
---@return nil
function KawaiiPhysics:SetLimitAngleCurveData(value) end

---@return FloatCurve
function KawaiiPhysics:GetLimitAngleCurveData() end

--- Blend in local space; zero removes this component's contribution and freezes simulation. Serialized as "Alpha".
---@param alpha number
---@return nil
function KawaiiPhysics:SetAlpha(alpha) end

---@return number
function KawaiiPhysics:GetAlpha() end

--- Reset at the next effective evaluation; requests survive invisibility and pause.
---@return nil
function KawaiiPhysics:ResetDynamics() end

--- Serialized as "Need Warm Up".
---@param value boolean
---@return nil
function KawaiiPhysics:SetNeedWarmUp(value) end

---@return boolean
function KawaiiPhysics:GetNeedWarmUp() end

---@return string
function KawaiiPhysics:GetDiagnostic() end

