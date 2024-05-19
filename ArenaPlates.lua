--[[
   < ArenaPlates v0.4 Beta >
______________________________
 Author: Spyro
License: All Rights Reserved
Contact: Spyrö  @ ArenaJunkies
         Spyro  @ WowInterface
         Spyro_ @ Curse/WowAce
¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
]]

--<< Configuration >>--

-- Shows the numbers always 100% opaque, for improved visibility. If false, they will inherit the nameplate opacity (50% non-target / 100% target)
local OpaqueMode = false

-- Replaces the font default shadow with an outline (looks better). If false, the number will look exactly as the default level number
local Outline = true

-- Make the level font have its pre 5.4.2-patch size (Blizzard made all nameplate FontStrings smaller in this patch)
local OldSize = true

-- Hides the unitname of nameplates of arena enemy players, to make them more simple
local HideNames = false

-- Change the color of nameplates based on its combat status
local CombatColoring = true
-- Check the combat status every this seconds. The lower the number the higher the precision (but also the CPU use)
local CheckPrecision = 0.2
-- Color for nameplates of units in combat (default Blizzard color)
local CombatColor   = {}
      CombatColor.R = 1
      CombatColor.G = 1
      CombatColor.B = 1
-- Color for nameplates of units out of combat
local NoCombatColor   = {}
      NoCombatColor.R = 0
      NoCombatColor.G = 1
      NoCombatColor.B = 0

--<< End of Configuration >>--

-- Upvalues
local print, pcall, pairs, unpack, select, hooksecurefunc, WorldFrame, IsInInstance, UnitExists, UnitHealthMax, GetUnitName, UnitAffectingCombat, GetNumArenaOpponents =
      print, pcall, pairs, unpack, select, hooksecurefunc, WorldFrame, IsInInstance, UnitExists, UnitHealthMax, GetUnitName, UnitAffectingCombat, GetNumArenaOpponents

-- Namespace local vars
local NumChildren = -1 -- WorldFrame child counter
local Number = {} -- Stores the FontStrings with the ArenaID numbers
local VisiblePlates = {} -- Stores references to the visible nameplates that we want to check its combat status (indexed by UnitID)
local CombatChecker = CreateFrame("Frame") -- Frame whose OnUpdate will check the combat status of the nameplates on VisiblePlates
      CombatChecker.LastUpdate = 0
local AP = CreateFrame("Frame") -- Addon main frame
      AP:SetFrameStrata("LOW")

-- Event registration
AP:SetScript("OnEvent", function(self, event, ...) return self[event](self, ...) end)
AP:RegisterEvent("PLAYER_ENTERING_WORLD")

-- CreateNumber()
-- Creates an ArenaID number, to be anchored to nameplates.
-- > i:          Number digit.
-- > FontSource: Nameplate level FontString to clone it.
-- < Number:     FontString of the created number.
local function CreateNumber(i, FontSource)
  local Number = AP:CreateFontString()

  -- Cloning the level FontString
  Number:SetDrawLayer(FontSource:GetDrawLayer())
  Number:SetFontObject(FontSource:GetFontObject())
  Number:SetFont(FontSource:GetFont())
  Number:SetTextColor(FontSource:GetTextColor())
  Number:SetShadowColor(FontSource:GetShadowColor())
  Number:SetShadowOffset(FontSource:GetShadowOffset())
  Number:SetText(i)

  -- If outline wanted, creating it and removing the default shadow
  if Outline then
    local FontData = { FontSource:GetFont() }
    FontData[3] = "OUTLINE"
    Number:SetFont(unpack(FontData))
    Number:SetShadowColor(0, 0, 0, 0)
    Number:SetShadowOffset(0, 0)
  end

  -- If pre 5.4.2-patch size wanted
  if OldSize then
    local FontData = { Number:GetFont() }
    FontData[2] = 14
    Number:SetFont(unpack(FontData))
  end

  return Number
end

-- PutNumber()
-- Replace the level number of a nameplate for an ArenaID number.
-- > i:     Number digit
-- > Plate: Nameplate reference
local function PutNumber(i, Plate)
  if not Number[i] then Number[i] = CreateNumber(i, Plate.AP.Level) end
  local N = Number[i] -- ArenaID FontString reference

  if HideNames then Plate.AP.Name:SetAlpha(0) end -- Option for hiding the unitname
  Plate.AP.Level:SetAlpha(0) -- Hiding the level text, coz the ArenaID number will be here
  Plate.AP.ArenaID = N -- Storing a reference in the nameplate to the ArenaID number, for later use in NAMEPLATE_HIDE

  -- Anchoring the number to the nameplate
  local AnchorData = { Plate.AP.Level:GetPoint() } -- Getting the anchor point of the default level FontString
  if Outline then AnchorData[5] = AnchorData[5] - 1 end -- If outlined, move it 1 pixel down
  N:SetPoint(unpack(AnchorData)) -- Anchoring the ArenaID number on the same place of the default level FontString
  N:Show()

  -- If "always 100% opacity" is not wanted, configuring the number to inherit the nameplate opacity
  if not OpaqueMode then
    N:SetParent(Plate.AP.Level:GetParent())
    N:SetDrawLayer(Plate.AP.Level:GetDrawLayer())
  end
end

-- CombatCheckerFunc()
-- OnUpdate function for the CombatChecker frame.
-- Checks the combat status of visible nameplates that pertain to arena enemies, and changes the border color based on it.
-- > self:    Referente to the CombatChecker frame
-- > Elapsed: Time since the last OnUpdate cycle
local function CombatCheckerFunc(self, Elapsed)
  -- OnUpdate time check
  self.LastUpdate = self.LastUpdate + Elapsed
  if self.LastUpdate < CheckPrecision then return end
  self.LastUpdate = 0

  -- The time has passed, checking combat status on visible nameplates
  for UnitID, Plate in pairs(VisiblePlates) do
    if UnitAffectingCombat(UnitID) then Plate.AP.Border:SetVertexColor(CombatColor.R, CombatColor.G, CombatColor.B)
    else Plate.AP.Border:SetVertexColor(NoCombatColor.R, NoCombatColor.G, NoCombatColor.B) end
  end
end

-- IsUnitPlate()
-- Checks if a nameplate is the nameplate of a given UnitID.
-- > Plate:  Nameplate reference
-- > UnitID: UnitID
-- < Boolean result
local function IsUnitPlate(Plate, UnitID)
  if not UnitExists(UnitID) then return false end

  local p_HPmax = select(2, Plate.AP.Healthbar:GetMinMaxValues())
  local p_Name  = Plate.AP:GetUnitName()

  local u_HPmax = UnitHealthMax(UnitID)      -- Maximum health
  local u_Name  = GetUnitName(UnitID, false) -- Unit name

  if p_HPmax == u_HPmax and p_Name == u_Name then return true end
  return false
end

-- GetArenaUnitID()
-- Returns the Arena UnitID of a nameplate.
-- > Plate: Nameplate reference.
-- < UnitID (nil if not found)
local function GetArenaUnitID(Plate)
  -- Iterating thru all the arena enemies and their pets
  for i = 1, GetNumArenaOpponents() do
    for _, UnitID in pairs({"arena"..i, "arenapet"..i}) do
      if IsUnitPlate(Plate, UnitID) then return UnitID end
    end
  end

  return nil
end

-- ArenaEnemyPlayer()
-- Checks if an UnitID is an arena enemy player, in that case returns his number.
-- > UnitID: UnitID
-- < Number (nil if it's not an arena enemy player)
local function ArenaEnemyPlayer(UnitID)
  if UnitID:sub(1, 5) == "arena" and UnitID:len() == 6 then return UnitID:sub(6) end
  return nil
end

-- Event NAMEPLATE_SHOW
-- Fires when a nameplate appears on screen.
-- > Plate: Nameplate reference
local function NAMEPLATE_SHOW(Plate)
  local UnitID = GetArenaUnitID(Plate) -- UnitID of the owner of this nameplate
  if not UnitID then return end

  -- Storing nameplate UnitID (for future use in NAMEPLATE_HIDE)
  Plate.AP.UnitID = UnitID

  -- If it's an enemy player, put his ArenaID number on his nameplate
  local Number = ArenaEnemyPlayer(UnitID)
  if Number then PutNumber(Number, Plate) end

  -- If we want to color by combat status, add this nameplate to the combat checker process
  if CombatColoring then
    if #VisiblePlates == 0 then CombatChecker:SetScript("OnUpdate", CombatCheckerFunc) end
    VisiblePlates[UnitID] = Plate
  end
end

-- Event NAMEPLATE_HIDE
-- Fires when a nameplate disappears from screen.
-- > Plate: Nameplate reference
local function NAMEPLATE_HIDE(Plate)
  -- If it's a nameplate of a unit with an arena UnitID
  if Plate.AP.UnitID then
    -- Removing from the combat tracker
    if CombatColoring then
      VisiblePlates[Plate.AP.UnitID] = nil
      if #VisiblePlates == 0 then CombatChecker:SetScript("OnUpdate", nil) end
    end
    Plate.AP.UnitID = nil
  end

  -- If it has an ArenaID number attached, free it
  if Plate.AP.ArenaID then
    Plate.AP.ArenaID:ClearAllPoints()
    Plate.AP.ArenaID:SetParent(AP)
    Plate.AP.ArenaID:Hide()
    Plate.AP.ArenaID = nil
  end

  -- Rolling back the nameplate to its default state
  Plate.AP.Name:SetAlpha(1)
  Plate.AP.Level:SetAlpha(1)
  Plate.AP.Border:SetVertexColor(1, 1, 1)
end

-- SetScriptHook()
-- This function is used in the secure hook of SetScript() on nameplate frames, to detect selfish addons which use
-- that instead of HookScript() (destroying the hooks of every other nameplate addon running), to re-apply our hooks.
-- > Plate: Nameplate reference
-- > Handler: Script handler used on the SetScript() call
-- > Func: Hooked function
local function SetScriptHook(Plate, Handler, Func)
  if Handler == "OnShow" then Plate:HookScript("OnShow", NAMEPLATE_SHOW)
  elseif Handler == "OnHide" then Plate:HookScript("OnHide", NAMEPLATE_HIDE) end
end

-- StructurePlate()
-- Creates references to the frames and regions of a nameplate used by the addon.
-- Every new property is created under the table "AP", to avoid using the same names as other addons.
-- > Plate: Nameplate reference
local function StructurePlate(Plate)
  local Child = { Plate:GetChildren() }
  Child[1].Region = { Child[1]:GetRegions() }
  Plate.AP = {}

  -- Creating references to frames and regions we need to access
  Plate.AP.Border    = Child[1].Region[2]
  Plate.AP.Level     = Child[1].Region[4]
  Plate.AP.Healthbar = Child[1]:GetChildren()
  Plate.AP.Name      = Child[2]:GetRegions()

  -- Methods
  Plate.AP.GetUnitName = function() return Plate.AP.Name:GetText() end

  -- Scripts
  Plate:HookScript("OnShow", NAMEPLATE_SHOW) -- Event to trigger when the nameplate appears on screen
  Plate:HookScript("OnHide", NAMEPLATE_HIDE) -- Event to trigger when the nameplate disappears from screen
  if Plate:IsVisible() then NAMEPLATE_SHOW(Plate) end

  -- Hooking the use of SetScript() on nameplates by other addons, so they don't fuck our hooks
  hooksecurefunc(Plate, "SetScript", SetScriptHook)
end

-- PlateProcess()
-- Process the WorldFrame children whenever a new children it's created, to catch nameplates.
local function PlateProcess()
  if WorldFrame:GetNumChildren() == NumChildren then return end
  NumChildren = WorldFrame:GetNumChildren()

  for _, Plate in pairs({WorldFrame:GetChildren()}) do
    if not Plate.ArenaPlates and Plate:GetName() and Plate:GetName():find("NamePlate") then
      Plate.ArenaPlates = true -- Mark as seen to ignore it in future iterations.
      StructurePlate(Plate)
    end
  end
end

-- Event PLAYER_ENTERING_WORLD
-- Fires after a loading screen.
function AP:PLAYER_ENTERING_WORLD()
  -- If it's an arena, activating nameplate processing, disabling it otherwise
  if select(2, IsInInstance()) == "arena" then AP:SetScript("OnUpdate", PlateProcess)
  else AP:SetScript("OnUpdate", nil) end
end

print()