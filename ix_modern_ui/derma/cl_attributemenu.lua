
local PLUGIN = PLUGIN

local color_green = Color(50,150,100)
local color_red = Color(150, 50, 50)

local PANEL = {}
PANEL = {}

function PANEL:Init()
	ix.gui.attribute = self
	local character = LocalPlayer():GetCharacter()

	--self:SetSize(self:GetParent():GetSize())
    self:SetSize(ScrW() * 0.60, ScrH() * 0.9)
	self:SetPos( 10, 25 )

	local character = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()

    
    if (character) then --  ZWYKŁE SKILE/UMIEJĘTNOŚCI


        self.attributes = vgui.Create( "ixCategoryPanel", self )
        self.attributes:SetText(L("attributes"))
        self.attributes:SetSize(ScrW() * 0.60, ScrH() * 0.9)
        self.attributes:SetPos(0,50)
        self.attributes:DockMargin(0, 0, 0, 8)
        self.attributes.Paint = function(s,w,h)
            surface.SetDrawColor(Color(0, 0, 0, 255))
        end

        local boost = character:GetBoosts()
        local bFirst = true

        for k, v in SortedPairsByMemberValue(ix.attributes.list, "name") do
            if (v.name == "Policjant") or (v.name == "Gangster") or (v.name == "Medyk") or (v.name == "Kurier/Magazynier") then
                continue
            end

            
            local attributeBoost = 0

            if (boost[k]) then
                for _, bValue in pairs(boost[k]) do
                    attributeBoost = attributeBoost + bValue
                end
            end

            local bar = self.attributes:Add("ixAttributeBar")
            bar:Dock(TOP)
			bar:SetSize(100,75)
        	--bar:SetPos(50,0)

            if (!bFirst) then
                bar:DockMargin(0, 1, 0, 0)
            else
                bFirst = false
            end

            local value = character:GetAttribute(k, 0)

            if (attributeBoost) then
                bar:SetValue(value - attributeBoost or 0)
            else
                bar:SetValue(value)
            end

            local maximum = v.maxValue or ix.config.Get("maxAttributes", 100)
            bar:SetMax(maximum)
            bar:SetReadOnly()
			bar:SetTall(64)
            --bar:SetText(Format("%s [%.1f/%.1f] (%.1f%%)", L(v.name), value, maximum, value / maximum * 100))
			bar:SetText(Format("%s (%.1f%%)", L(v.name), value / maximum * 100))
            bar:SetAtribIcon(Format("%s", L(v.name)))

            if (attributeBoost) then
                bar:SetBoost(attributeBoost)
            end
        end

        self.attributes:SizeToContents()
    end

    -- Coś tu kiedyś było ale to wyjebałem - tak więc jebać kaktusownie.
    -- Nawet nie wiem czy ten kod działa yolo

end




vgui.Register("ixAttribute", PANEL, "EditablePanel")

hook.Add("CreateMenuButtons", "ixAttribute", function(tabs)
	if (hook.Run("BuildAttributeMenu") != false) then
		tabs["Skile"] = function(container)
			container:Add("ixAttribute")
		end
	end
end)


