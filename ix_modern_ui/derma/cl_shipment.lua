
local PANEL = {}

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:SetTitle(L"shipment")
	self:Center()
	self:MakePopup()
	self.Paint = function(s,w,h)
		surface.SetDrawColor(Color(0, 0, 0, 255))
		Derma_DrawBackgroundBlur(self, self.startTime)
		Derma_DrawBackgroundBlur(self, self.startTime)
		Derma_DrawBackgroundBlur(self, self.startTime)

		surface.SetDrawColor(255, 255, 255, 145)
		surface.SetMaterial(Material("darkrpg/derma/full_bg.png"))
		surface.DrawTexturedRect(0,0,ScrW(),ScrH())
	end

	self.scroll = self:Add("DScrollPanel")
	self.scroll:Dock(FILL)

	self.list = self.scroll:Add("DListLayout")
	--self.list:Dock(FILL)
	self.list:SetSize(800,50)
	self.list:SetPos(ScrW() * 0.5 - 400,ScrH() * 0.5 - 350)
end

function PANEL:SetItems(entity, items)
	self.entity = entity
	self.items = true
	self.itemPanels = {}

	for k, v in SortedPairs(items) do
		local itemTable = ix.item.list[k]

		if (itemTable) then
			local item = self.list:Add("DPanel")
			item:SetTall(80)
			item:Dock(TOP)
			item:DockMargin(4, 4, 4, 0)
			item.Paint = function(s,w,h)
				surface.SetDrawColor(255, 255, 255, 70)
				surface.SetMaterial(Material("darkrpg/items/bg.png"))
				surface.DrawTexturedRect(-20,-20,w + 40 ,h + 40 )

				surface.SetDrawColor(Color(0, 0, 0, 133))
				surface.DrawOutlinedRect( 1,1, w - 2, h - 2, 1 )
			end

			item.icon = item:Add("SpawnIcon")
			item.icon:SetPos(2, 2)
			item.icon:SetSize(80, 80)
			item.icon:SetModel(itemTable:GetModel())
			item.icon:SetHelixTooltip(function(tooltip)
				ix.hud.PopulateItemTooltip(tooltip, itemTable)
			end)
			if itemTable.CustomIcon != nil then
				item.icon.Paint = function(s,w,h)
					surface.SetMaterial(Material(itemTable.CustomIcon))
					surface.SetDrawColor(255, 255, 255)
					surface.DrawTexturedRect( 0,0,w,h)
				end
			end

			item.quantity = item:Add("DLabel")
			item.quantity:SetPos(300, 35)
			item.quantity:SetSize(200, 50)
			item.quantity:SetContentAlignment(5)
			item.quantity:SetTextInset(0, 0)
			item.quantity:SetText("Dostępne: "..v.." szt.")
			item.quantity:SetFont("ixSmallFont")
			item.quantity:SetExpensiveShadow(1, Color(0, 0, 0, 150))

			item.name = item:Add("DLabel")
			item.name:SetPos(300, 5)
			item.name:SetSize(200, 50)
			item.name:SetFont("ixSubTitleFont")
			item.name:SetText(L(itemTable.name))
			item.name:SetContentAlignment(5)
			item.name:SetTextColor(color_white)

			item.take = item:Add("DButton")
			item.take:Dock(RIGHT)
			item.take:SetText(L"take")
			item.take:SetFont("ixMenuButtonFont")
			item.take:SetWide(150)
			item.take:DockMargin(3, 3, 3, 3)
			item.take:SetTextColor(color_white)
			item.take.DoClick = function(this)
				net.Start("ixShipmentUse")
					net.WriteString(k)
					net.WriteBool(false)
				net.SendToServer()

				items[k] = items[k] - 1

				item.quantity:SetText("Dostępne: "..items[k].." szt.")

				if (items[k] <= 0) then
					item:Remove()
					items[k] = nil
				end

				if (table.IsEmpty(items)) then
					self:Remove()
				end
			end
			item.take.Paint = function(s,w,h)
			--	surface.SetDrawColor(Color(0, 0, 0, 255))
			--	surface.SetDrawColor(255, 255, 255, 37)
			--	surface.SetMaterial(Material("darkrpg/items/bg.png"))
			--	surface.DrawTexturedRect(0,0,w,h)
			end

			--item.drop = item:Add("DButton")
			--item.drop:Dock(RIGHT)
			--item.drop:SetText(L"drop")
			--item.drop:SetWide(48)
			--item.drop:DockMargin(3, 3, 0, 3)
			--item.drop:SetTextColor(color_white)
			--item.drop.DoClick = function(this)
			--	net.Start("ixShipmentUse")
			--		net.WriteString(k)
			--		net.WriteBool(true)
			--	net.SendToServer()
--
			--	items[k] = items[k] - 1
--
			--	item.quantity:SetText(items[k])
--
			--	if (items[k] <= 0) then
			--		item:Remove()
			--	end
			--end

			self.itemPanels[k] = item
		end
	end
end

function PANEL:Close()
	net.Start("ixShipmentClose")
	net.SendToServer()

	self:Remove()
end

function PANEL:Think()
	if (self.items and !IsValid(self.entity)) then
		self:Remove()
	end
end

vgui.Register("ixShipment", PANEL, "DFrame")
