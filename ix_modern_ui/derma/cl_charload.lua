
local errorModel = "models/player/skeleton.mdl"
local PANEL = {}

AccessorFunc(PANEL, "animationTime", "AnimationTime", FORCE_NUMBER)

local function SetCharacter(self, character)
	self.character = character

	if (character) then
		self:SetModel(character:GetModel())
		self:SetSkin(character:GetData("skin", 0))

		for i = 0, (self:GetNumBodyGroups() - 1) do
			self:SetBodygroup(i, 0)
		end

		local bodygroups = character:GetData("groups", nil)

		if (istable(bodygroups)) then
			for k, v in pairs(bodygroups) do
				self:SetBodygroup(k, v)
			end
		end
	else
		self:SetModel(errorModel)
	end
end

local function GetCharacter(self)
	return self.character
end

function PANEL:Init()
	self.activeCharacter = ClientsideModel(errorModel)
	self.activeCharacter:SetNoDraw(true)
	self.activeCharacter.SetCharacter = SetCharacter
	self.activeCharacter.GetCharacter = GetCharacter
	

	self.lastCharacter = ClientsideModel(errorModel)
	self.lastCharacter:SetNoDraw(true)
	self.lastCharacter.SetCharacter = SetCharacter
	self.lastCharacter.GetCharacter = GetCharacter

	self.animationTime = 0.5

	self.shadeY = 0
	self.shadeHeight = 0

	self.cameraPosition = Vector(80, 0, 35)
	self.cameraAngle = Angle(0, 180, 0)
	self.lastPaint = 0
end

function PANEL:ResetSequence(model, lastModel)
	local sequence = model:LookupSequence("lineidle0".. math.random(1,4))

	if (sequence <= 0) then
		sequence = model:SelectWeightedSequence(ACT_IDLE)
	end

	if (sequence > 0) then
		model:ResetSequence(sequence)
	else
		local found = false

		for _, v in ipairs(model:GetSequenceList()) do
			if ((v:lower():find("idle") or v:lower():find("fly")) and v != "idlenoise") then
				model:ResetSequence(v)
				found = true

				break
			end
		end

		if (!found) then
			model:ResetSequence(4)
		end
	end

	model:SetIK(false)

	-- copy cycle if we can to avoid a jarring transition from resetting the sequence
	if (lastModel) then
		model:ResetSequence(sequence)
		model:SetCycle(lastModel:GetCycle())
	end
end

function PANEL:RunAnimation(model)
	model:FrameAdvance((RealTime() - self.lastPaint) * 1)
end

function PANEL:LayoutEntity(model)
	model:SetIK(false)

	self:RunAnimation(model)
end

function PANEL:SetActiveCharacter(character)
	self.shadeY = self:GetTall()
	self.shadeHeight = self:GetTall()

	-- set character immediately if we're an error (something isn't selected yet)
	if (self.activeCharacter:GetModel() == errorModel) then
		self.activeCharacter:SetCharacter(character)
		self:ResetSequence(self.activeCharacter)

		return
	end

	-- if the animation is already playing, we update its parameters so we can avoid restarting
	local shade = self:GetTweenAnimation(1)
	local shadeHide = self:GetTweenAnimation(2)

	if (shade) then
		shade.newCharacter = character
		return
	elseif (shadeHide) then
		shadeHide.queuedCharacter = character
		return
	end

	self.lastCharacter:SetCharacter(self.activeCharacter:GetCharacter())
	self:ResetSequence(self.lastCharacter, self.activeCharacter)

	shade = self:CreateAnimation(self.animationTime * 0.5, {
		index = 1,
		target = {
			shadeY = 0,
			shadeHeight = self:GetTall()
		},
		easing = "linear",

		OnComplete = function(shadeAnimation, shadePanel)
			shadePanel.activeCharacter:SetCharacter(shadeAnimation.newCharacter)
			shadePanel:ResetSequence(shadePanel.activeCharacter)

			shadePanel:CreateAnimation(shadePanel.animationTime, {
				index = 2,
				target = {shadeHeight = 0},
				easing = "outQuint",

				OnComplete = function(animation, panel)
					if (animation.queuedCharacter) then
						panel:SetActiveCharacter(animation.queuedCharacter)
					else
						panel.lastCharacter:SetCharacter(nil)
					end
				end
			})
		end
	})

	shade.newCharacter = character
end

function PANEL:Paint(width, height)
	local x, y = self:LocalToScreen(0, 0)
	local bTransition = self.lastCharacter:GetModel() != errorModel
	local modelFOV = 40

	cam.Start3D(self.cameraPosition, self.cameraAngle, modelFOV, x, y, width, height)
		render.SuppressEngineLighting(true)
		render.SetLightingOrigin(self.activeCharacter:GetPos())

		-- setup lighting
		render.SetModelLighting(0, 1.5, 1.5, 1.5)

		for i = 1, 4 do
			render.SetModelLighting(i, 0.4, 0.4, 0.4)
		end

		render.SetModelLighting(5, 0.04, 0.04, 0.04)

		-- clip anything out of bounds
		local curparent = self
		local rightx = self:GetWide()
		local leftx = 0
		local topy = 0
		local bottomy = self:GetTall()
		local previous = curparent

		while (curparent:GetParent() != nil) do
			local lastX, lastY = previous:GetPos()
			curparent = curparent:GetParent()

			topy = math.Max(lastY, topy + lastY)
			leftx = math.Max(lastX, leftx + lastX)
			bottomy = math.Min(lastY + previous:GetTall(), bottomy + lastY)
			rightx = math.Min(lastX + previous:GetWide(), rightx + lastX)

			previous = curparent
		end

		ix.util.ResetStencilValues()
		render.SetStencilEnable(true)
			render.SetStencilWriteMask(30)
			render.SetStencilTestMask(30)
			render.SetStencilReferenceValue(31)

			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilPassOperation(STENCIL_REPLACE)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)

			self:LayoutEntity(self.activeCharacter)

			if (bTransition) then
				-- only need to layout while it's used
				self:LayoutEntity(self.lastCharacter)

				render.SetScissorRect(leftx, topy, rightx, bottomy - (self:GetTall() - self.shadeHeight), true)
				self.lastCharacter:DrawModel()

				render.SetScissorRect(leftx, topy + self.shadeHeight, rightx, bottomy, true)
				self.activeCharacter:DrawModel()

				render.SetScissorRect(leftx, topy, rightx, bottomy, true)
			else
				self.activeCharacter:DrawModel()
			end

			render.SetStencilCompareFunction(STENCIL_EQUAL)
			render.SetStencilPassOperation(STENCIL_KEEP)

			cam.Start2D()
				derma.SkinFunc("PaintCharacterTransitionOverlay", self, 0, self.shadeY, width, self.shadeHeight)
			cam.End2D()
		render.SetStencilEnable(false)

		render.SetScissorRect(0, 0, 0, 0, false)
		render.SuppressEngineLighting(false)
	cam.End3D()

	self.lastPaint = RealTime()
end

function PANEL:OnRemove()
	self.lastCharacter:Remove()
	self.activeCharacter:Remove()
end

vgui.Register("ixCharMenuCarousel", PANEL, "Panel")

-- character load panel
PANEL = {}

AccessorFunc(PANEL, "animationTime", "AnimationTime", FORCE_NUMBER)
AccessorFunc(PANEL, "backgroundFraction", "BackgroundFraction", FORCE_NUMBER)

function PANEL:Init()
	local parent = self:GetParent()
	local padding = self:GetPadding()
	local halfWidth = parent:GetWide() * 0.5 - (padding * 2)
	local halfHeight = parent:GetTall() * 0.5 - (padding * 2)
	local modelFOV = (ScrW() > ScrH() * 1.8) and 102 or 78

	self.character = ix.char.loaded[ix.characters[1]]
	self.characterid = 1
	self.characterAttrib = {}

	self.animationTime = 1
	self.backgroundFraction = 1

	-- main panel
	self.panel = self:AddSubpanel("main")
	self.panel:SetTitle("")
	self.panel.OnSetActive = function()
		self:CreateAnimation(self.animationTime, {
			index = 2,
			target = {backgroundFraction = 1},
			easing = "outQuint",
		})
		
		self.character = ix.char.loaded[ix.characters[1]]
		self.carousel:SetActiveCharacter(ix.char.loaded[ix.characters[1]])
		--self.activeCharacter:SetCharacter(ix.char.loaded[ix.characters[1]])
	end

	local dscSubPanel = self.panel:Add("Panel")
	dscSubPanel:SetSize(self:GetWide() * 0.25, 500)
	dscSubPanel:SetPos(0,150)
	dscSubPanel.Paint = function(panel, width, height)
		--surface.SetDrawColor(Color(5, 0, 5, 255 * 0.5))
		--surface.DrawRect(0, 0, width, height)
	
		surface.SetDrawColor(ix.config.Get("color"))
		surface.DrawRect(0, 49, width, 1)
	
		surface.SetDrawColor(0, 0, 0, 80)
		surface.DrawRect(0, 0, width, height)
	
		surface.SetDrawColor(Color(0, 0, 0, 129))
		surface.DrawOutlinedRect( 0,0, width, height, 1 )
	end

	if !(self.character) then
		return
	end
	local index = self.character:GetFaction()
	local faction = ix.faction.indices[index]
	local color = faction and faction.color or color_white
	
	local charName = dscSubPanel:Add("DLabel")
	charName:Dock(FILL)
	charName:SetText(self.character:GetName())
	charName:DockMargin(15, 2, 0, 15)
	charName:SetFont("ixMenuButtonFont")
	charName:SetTextColor(color)
	charName:SetContentAlignment(8)
	
	local charDesc = dscSubPanel:Add("DLabel")
	charDesc:SetWrap(true)
	charDesc:Dock(FILL)
	charDesc:SetText(self.character:GetDescription())
	charDesc:DockMargin(15, 55, 3, 5)
	charDesc:SetFont("ixMenuButtonFont")
	charDesc:SetTextColor(color_white)
	charDesc:SetContentAlignment(8)



	--I don't know how to do it, so I'm trying ...  ¯\_(ツ)_/¯
	local perkSubPanel = self.panel:Add("Panel")
	perkSubPanel:SetSize(self:GetWide() * 0.25, 500)
	perkSubPanel:SetPos(self:GetWide() - (self:GetWide() * 0.25) - 200,150)
	perkSubPanel.Paint = function(panel, width, height)
		surface.SetDrawColor(ix.config.Get("color"))
		surface.DrawRect(0, 49, width, 1)
	
		surface.SetDrawColor(0, 0, 0, 80)
		surface.DrawRect(0, 0, width, height)
	
		surface.SetDrawColor(Color(0, 0, 0, 129))
		surface.DrawOutlinedRect( 0,0, width, height, 1 )
	end

	local perkTitle = perkSubPanel:Add("DLabel")
	perkTitle:SetText(L("attributes"))
	perkTitle:Dock(FILL)
	perkTitle:DockMargin(15, 2, 0, 15)
	perkTitle:SetFont("ixMenuButtonFont")
	perkTitle:SetTextColor(color_white)
	perkTitle:SetContentAlignment(8)


	local boost = self.character:GetBoosts()
    local bFirst = true
	for k, v in SortedPairsByMemberValue(ix.attributes.list, "name") do
		local attributeBoost = 0

		if (boost[k]) then
			for _, bValue in pairs(boost[k]) do
				attributeBoost = attributeBoost + bValue
			end
		end

		local bar = perkTitle:Add("ixAttributeBar")
		bar:Dock(TOP)
		bar:SetSize(100,100)

		if (!bFirst) then
			bar:DockMargin(0, 1, 20, 0)
		else
			bar:DockMargin(0, 60, 20, 0)
			bFirst = false
		end

		local value = self.character:GetAttribute(k, 0)

		if (attributeBoost) then
			bar:SetValue(value - attributeBoost or 0)
		else
			bar:SetValue(value)
		end 

		local maximum = v.maxValue or ix.config.Get("maxAttributes", 100)
		bar:SetMax(maximum)
		bar:SetReadOnly()
		bar:SetTall(44)
		--bar:SetText(Format("%s [%.1f/%.1f] (%.1f%%)", L(v.name), value, maximum, value / maximum * 100))
		bar:SetText(Format("%s (%.1f%%)", L(v.name), value / maximum * 100))

		if (attributeBoost) then
			bar:SetBoost(attributeBoost)
		end

		table.insert(self.characterAttrib, bar)
	end
	

	-- character button list
	local controlList = self.panel:Add("Panel")
	controlList:Dock(TOP)
	controlList:SetSize(halfWidth, halfHeight)



	local continueButton = controlList:Add("ixMenuButton") --It doesn't choose a character, it removes the character xD
	--continueButton:Dock(BOTTOM)
	continueButton:SetText("") -- or delete
	continueButton:SizeToContents()
	continueButton.DoClick = function()
		--self:SetActiveSubpanel("delete")
	end


	self.characterList = controlList:Add("ixCharMenuButtonList")
	self.characterList.buttons = {}
	self.characterList:SetSize(500,30)
	self.characterList:Dock(LEFT)
	self.characterList:SizeToContents()

	-- right-hand side with carousel and buttons
	local infoPanel = self.panel:Add("Panel")
	infoPanel:Dock(FILL)

	local infoButtons = infoPanel:Add("Panel")
	infoButtons:Dock(BOTTOM)
	infoButtons:SetTall(continueButton:GetTall() * 1.5) -- hmm...

	local deleteButton = infoButtons:Add("ixMenuButton") -- I was too lazy to change it, but this is a character selection button, not an delete button LOL
	deleteButton:Dock(RIGHT)
	deleteButton:SetText("Choose this character") -- or choose
	deleteButton:SetSize(450,50)
	deleteButton:SetContentAlignment(5)
	deleteButton:SetTextInset(0, 0)
	deleteButton:SizeToContents()
	deleteButton.DoClick = function()
		self:SetMouseInputEnabled(false)
		self:Slide("down", self.animationTime * 2, function()
			net.Start("ixCharacterChoose")
				net.WriteUInt(self.character:GetID(), 32)
			net.SendToServer()
		end, true)
	end
	deleteButton.Paint = function(panel, width, height)	
		surface.SetDrawColor(0, 0, 0, 135)
		surface.DrawRect(0, 0, width, height)
	
		surface.SetDrawColor(Color(0, 0, 0, 129))
		surface.DrawOutlinedRect( 0,0, width, height, 1 )
	end

	local back = infoButtons:Add("ixMenuButton")
	back:Dock(LEFT)
	back:SetText("return")
	back:SetSize(150,50)
	back:SetContentAlignment(5)
	back:SetTextInset(0, 0)
	back:SizeToContents()
	back.DoClick = function()
		self:SlideDown()
		parent.mainPanel:Undim()
	end
	back.Paint = function(panel, width, height)	
		surface.SetDrawColor(0, 0, 0, 135)
		surface.DrawRect(0, 0, width, height)
	
		surface.SetDrawColor(Color(0, 0, 0, 129))
		surface.DrawOutlinedRect( 0,0, width, height, 1 )
	end

	local removeCharacter = infoButtons:Add("ixMenuButton")
	removeCharacter:Dock(LEFT)
	removeCharacter:SetText("delete")
	removeCharacter:SetSize(150,50)
	removeCharacter:DockMargin(20, 0, 0, 0)
	removeCharacter:SetContentAlignment(5)
	removeCharacter:SetTextInset(0, 0)
	removeCharacter:SizeToContents()
	removeCharacter.DoClick = function()
		self:SetActiveSubpanel("delete")
	end
	removeCharacter.Paint = function(panel, width, height)	
		surface.SetDrawColor(0, 0, 0, 135)
		surface.DrawRect(0, 0, width, height)
	
		surface.SetDrawColor(Color(0, 0, 0, 129))
		surface.DrawOutlinedRect( 0,0, width, height, 1 )
	end

	self.carousel = self.panel:Add("ixCharMenuCarousel")
	self.carousel:SetSize(500,700)
	self.carousel:SetPos(self.panel:GetWide() * 0.5 - 250,150)
	self.carousel:SetActiveCharacter(self.character)
	--self.carousel:Dock(FILL)

	-- character deletion panel
	self.delete = self:AddSubpanel("delete")
	self.delete:SetTitle(nil)
	self.delete.OnSetActive = function()
		self.deleteModel:SetModel(self.character:GetModel())
		self:CreateAnimation(self.animationTime, {
			index = 2,
			target = {backgroundFraction = 0},
			easing = "outQuint"
		})
	end

	local deleteInfo = self.delete:Add("Panel")
	deleteInfo:SetSize(parent:GetWide() * 0.5, parent:GetTall())
	deleteInfo:Dock(LEFT)

	local deleteReturn = deleteInfo:Add("ixMenuButton")
	deleteReturn:Dock(BOTTOM)
	deleteReturn:SetText("NO! What am I doing - Go back!")
	deleteReturn:DockMargin(100, 0, 200, 0)
	deleteReturn:SizeToContents()
	deleteReturn.DoClick = function()
		self:SetActiveSubpanel("main")
	end
	deleteReturn.Paint = function(panel, width, height)	
		surface.SetDrawColor(0, 0, 0, 135)
		surface.DrawRect(0, 0, width, height)
	
		surface.SetDrawColor(Color(0, 0, 0, 129))
		surface.DrawOutlinedRect( 0,0, width, height, 1 )
	end
	

	local deleteConfirm = self.delete:Add("ixMenuButton")
	deleteConfirm:Dock(BOTTOM)
	deleteConfirm:SetText("Yes - I want to remove this character!")
	deleteConfirm:DockMargin(0, 0, 20, 0)
	--deleteConfirm:SetContentAlignment(6)
	deleteConfirm:SizeToContents()
	deleteConfirm:SetTextColor(derma.GetColor("Error", deleteConfirm))
	deleteConfirm.DoClick = function()
		local id = self.character:GetID()

		parent:ShowNotice(1, L("deleteComplete", self.character:GetName()))
		self:Populate(id)
		self:SetActiveSubpanel("main")

		net.Start("ixCharacterDelete")
			net.WriteUInt(id, 32)
		net.SendToServer()
	end
	deleteConfirm.Paint = function(panel, width, height)	
		surface.SetDrawColor(31, 0, 0, 135)
		surface.DrawRect(0, 0, width, height)
	
		surface.SetDrawColor(Color(0, 0, 0, 129))
		surface.DrawOutlinedRect( 0,0, width, height, 1 )
	end

	self.deleteModel = deleteInfo:Add("ixModelPanel")
	self.deleteModel:Dock(FILL)
	self.deleteModel:SetModel(errorModel)
	self.deleteModel:SetFOV(modelFOV)
	self.deleteModel.PaintModel = self.deleteModel.Paint

	local deleteNag = self.delete:Add("Panel")
	deleteNag:SetTall(parent:GetTall() * 0.5)
	deleteNag:Dock(BOTTOM)

	local deleteTitle = deleteNag:Add("DLabel")
	deleteTitle:SetFont("ixTitleFont")
	deleteTitle:SetText(L("areYouSure"):utf8upper())
	deleteTitle:SetTextColor(ix.config.Get("color"))
	deleteTitle:SizeToContents()
	deleteTitle:Dock(TOP)

	local deleteText = deleteNag:Add("DLabel")
	deleteText:SetFont("ixMenuButtonFont")
	deleteText:SetText(L("deleteConfirm"))
	deleteText:SetTextColor(color_white)
	deleteText:SetContentAlignment(7)
	deleteText:Dock(FILL)

	local preCharButton = self.panel:Add("ixMenuButton") 
	--preCharButton:Dock(LEFT)
	preCharButton:SetSize(25, self:GetWide() * 0.25)
	preCharButton:SetPos(dscSubPanel:GetWide() + 5, 150)
	preCharButton:SetText("<")
	preCharButton:SizeToContents()
	preCharButton.DoClick = function()
		for i = 1, #ix.characters do
			local id = ix.characters[i]
			local character = ix.char.loaded[id]
	
			if (!character or character:GetID() == ignoreID) then
				continue
			end

			local index = character:GetFaction()
			local faction = ix.faction.indices[index]
			local color = faction and faction.color or color_white
			
			if self.character != character then 
				if (self.characterid - 1 or 0) == i then
					local character = ix.char.loaded[ix.characters[i]]
					self.carousel:SetActiveCharacter(character)
					self.character = character
					self.characterid = i
					charName:SetTextColor(color)
					charName:SetText(character:GetName())
					charDesc:SetText(character:GetDescription())
					charDesc:SizeToContents()

					break
				end
			end

		end

		local boost = self.character:GetBoosts()
		local bFirst = true
		local count = 0
		for k, v in SortedPairsByMemberValue(ix.attributes.list, "name") do
			count = count + 1
			if count == count then
				self.characterAttrib[count]:Remove()
			end
			local attributeBoost = 0

			if (boost[k]) then
				for _, bValue in pairs(boost[k]) do
					attributeBoost = attributeBoost + bValue
				end
			end

			local bar = perkTitle:Add("ixAttributeBar")
			bar:Dock(TOP)
			bar:SetSize(100,100)

			if (!bFirst) then
				bar:DockMargin(0, 1, 20, 0)
			else
				bar:DockMargin(0, 60, 20, 0)
				bFirst = false
			end

			local value = self.character:GetAttribute(k, 0)

			if (attributeBoost) then
				bar:SetValue(value - attributeBoost or 0)
			else
				bar:SetValue(value)
			end 

			local maximum = v.maxValue or ix.config.Get("maxAttributes", 100)
			bar:SetMax(maximum)
			bar:SetReadOnly()
			bar:SetTall(44)
			--bar:SetText(Format("%s [%.1f/%.1f] (%.1f%%)", L(v.name), value, maximum, value / maximum * 100))
			bar:SetText(Format("%s (%.1f%%)", L(v.name), value / maximum * 100))

			if (attributeBoost) then
				bar:SetBoost(attributeBoost)
			end

			if count == count then
				self.characterAttrib[count] = bar
			end
		end
	end
	preCharButton.Paint = function(panel, width, height)	
		surface.SetDrawColor(0, 0, 0, 135)
		surface.DrawRect(0, 0, width, height)
	
		surface.SetDrawColor(Color(0, 0, 0, 129))
		surface.DrawOutlinedRect( 0,0, width, height, 1 )
	end

	local nextCharButton = self.panel:Add("ixMenuButton") 
	--nextCharButton:Dock(RIGHT)
	nextCharButton:SetSize(25, self:GetWide() * 0.25)
	nextCharButton:SetPos(controlList:GetWide() + perkSubPanel:GetWide() - 48, 150)
	nextCharButton:SetText(">")
	nextCharButton:SizeToContents()
	nextCharButton.DoClick = function()
		for i = 1, #ix.characters do
			local id = ix.characters[i]
			local character = ix.char.loaded[id]
	
			if (!character or character:GetID() == ignoreID) then
				continue
			end
	
			local index = character:GetFaction()
			local faction = ix.faction.indices[index]
			local color = faction and faction.color or color_white


			if (self.characterid or 0) < i then
				local character = ix.char.loaded[ix.characters[i]]
				self.carousel:SetActiveCharacter(character)
				self.character = character
				self.characterid = i	
				charName:SetTextColor(color)
				charName:SetText(character:GetName())
				charDesc:SetText(character:GetDescription())
				charDesc:SizeToContents()

				break
			end
		end

		local boost = self.character:GetBoosts()
		local bFirst = true
		local count = 0
		for k, v in SortedPairsByMemberValue(ix.attributes.list, "name") do
			count = count + 1
			if count == count then
				self.characterAttrib[count]:Remove()
			end
			local attributeBoost = 0

			if (boost[k]) then
				for _, bValue in pairs(boost[k]) do
					attributeBoost = attributeBoost + bValue
				end
			end

			local bar = perkTitle:Add("ixAttributeBar")
			bar:Dock(TOP)
			bar:SetSize(100,100)

			if (!bFirst) then
				bar:DockMargin(0, 1, 20, 0)
			else
				bar:DockMargin(0, 60, 20, 0)
				bFirst = false
			end

			local value = self.character:GetAttribute(k, 0)

			if (attributeBoost) then
				bar:SetValue(value - attributeBoost or 0)
			else
				bar:SetValue(value)
			end 

			local maximum = v.maxValue or ix.config.Get("maxAttributes", 100)
			bar:SetMax(maximum)
			bar:SetReadOnly()
			bar:SetTall(44)
			--bar:SetText(Format("%s [%.1f/%.1f] (%.1f%%)", L(v.name), value, maximum, value / maximum * 100))
			bar:SetText(Format("%s (%.1f%%)", L(v.name), value / maximum * 100))

			if (attributeBoost) then
				bar:SetBoost(attributeBoost)
			end

			if count == count then
				self.characterAttrib[count] = bar
			end
		end
	end
	nextCharButton.Paint = function(panel, width, height)	
		surface.SetDrawColor(0, 0, 0, 135)
		surface.DrawRect(0, 0, width, height)
	
		surface.SetDrawColor(Color(0, 0, 0, 129))
		surface.DrawOutlinedRect( 0,0, width, height, 1 )
	end

	-- finalize setup
	self:SetActiveSubpanel("main", 0)
end

function PANEL:OnCharacterDeleted(character)
	if (self.bActive and #ix.characters == 0) then
		self:SlideDown()
	end
end

function PANEL:Populate(ignoreID)
	self.characterList:SetPadding(10, 8, 10, 8)
	self.characterList:Clear()
	self.characterList.buttons = {}

	local bSelected

	-- loop backwards to preserve order since we're docking to the bottom
	for i = 1, #ix.characters do
		local id = ix.characters[i]
		local character = ix.char.loaded[id]

		if (!character or character:GetID() == ignoreID) then
			continue
		end

		local index = character:GetFaction()
		local faction = ix.faction.indices[index]
		local color = faction and faction.color or color_white

		
		print(character)

		--nextCharButton.DoClick = function()
		--	self.carousel:SetActiveCharacter(panel.character)
		--	self.character = panel.character
		--end

		--local button = self.characterList:Add("ixMenuSelectionButton")
		--button:SetBackgroundColor(color)
		--button:SetText(character:GetName())
		--button:SetSize(300,30)
		----button:Dock(LEFT)
		--button:SizeToContents()
		--button:SetButtonList(self.characterList.buttons)
		--button.character = character
		--button.OnSelected = function(panel)
		--	self:OnCharacterButtonSelected(panel)
		--	print(panel.character)
		--end
		--button.Paint = function(panel, width, height) end
--
		---- select currently loaded character if available
		--local localCharacter = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
--
		--if (localCharacter and character:GetID() == localCharacter:GetID()) then
		--	button:SetSelected(true)
		--	self.characterList:ScrollToChild(button)
--
		--	bSelected = true
		--end
	end

	if (!bSelected) then
		local buttons = self.characterList.buttons

		if (#buttons > 0) then
			local button = buttons[#buttons]

			button:SetSelected(true)
			self.characterList:ScrollToChild(button)
		else
			self.character = nil
		end
	end

	self.characterList:SizeToContents()
end

function PANEL:OnSlideUp()
	self.bActive = true
	self:Populate()
end

function PANEL:OnSlideDown()
	self.bActive = false
end

function PANEL:OnCharacterButtonSelected(panel)
	self.carousel:SetActiveCharacter(panel.character)
	self.character = panel.character
end

function PANEL:Paint(width, height)
		surface.SetDrawColor(255, 255, 255, 145)
		surface.SetMaterial(Material("darkrpg/derma/full_bg.png"))
		surface.DrawTexturedRect(0,0,ScrW(),ScrH())

		surface.SetDrawColor(Color(0, 1, 5, self.currentAlpha * 0.5))
		surface.DrawRect(0, 0, width, 50)
	
		surface.SetDrawColor(ix.config.Get("color"))
		surface.DrawRect(0, 50, width, 1)

		draw.DrawText(L"loadTitle", "ixSubTitleFont", 30, 2, ix.config.Get("color"), TEXT_ALIGN_LEFT)

end

vgui.Register("ixCharMenuLoad", PANEL, "ixCharMenuPanel")
