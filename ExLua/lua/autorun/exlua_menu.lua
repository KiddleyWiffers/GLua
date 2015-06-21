AddCSLuaFile( "exlua_menu.lua" )
AddCSLuaFile("autorun/exlua_menu.lua")
-------
if SERVER then
	util.AddNetworkString("xlSendULXCommand")
	util.AddNetworkString("xlSendEntInfo") 
	-------
	net.Receive("xlSendULXCommand", function(_, ply)
		if ply:query( "ulx exlua" ) then
			ulx.exlua( ply, net.ReadString() )
		end
	end)
	-------
	net.Receive("xlSendEntInfo", function(_,ply) 
		if ply:query( "ulx exlua" ) then
			local ent = Entity(net.ReadTable()[1])
			if ply:IsSuperAdmin() then -- Only superadmins will get the info from the server.
				local temptab, tab = ent:GetTable(), {}
				
				for k,v in next, temptab do
					local k = tostring(k)
					if type(v) == "table" then
						local builder, safe = v, {}
						for s,x in next, builder do
							safe[tostring(s)] = tostring(x)
						end
						tab[k] = safe
					else
						tab[tostring(k)] = tostring(v)
					end
				end; temptab = nil

				net.Start("xlSendEntInfo")
				net.WriteTable({bool = true})
				net.WriteTable({ent,tab})
				net.Send(ply)
			else -- Everyone else will get the info from their client.
				net.Start("xlSendEntInfo")
				net.WriteTable({false})
				net.WriteTable({ent,{}})
				net.Send(ply)
			end
		end
	end)
end

if CLIENT then
	local pastCommands, el_cmenuOpen, el_entry = {}, false, false

	net.Receive("xlSendEntInfo", function()
		local allowed, nettable = net.ReadTable(), net.ReadTable()
		if nettable then
			el_cmenuOpen = true

			local ent = {v = nettable[1], tab = nettable[2]}
			local Menu = vgui.Create( "DMenu" )
			
			if not allowed.bool then ent.tab = ent.v:GetTable() end

			Menu.CancleFunc = function()
				el_cmenuOpen = false
				if el_entry then
					el_entry:RequestFocus()
				end
			end

			Menu.MainFunc = function(self) -- This is ran when an item is selected from the menu.
				local str = tostring(self:GetText())
				if str == "<Undefined>" or str == "<Empty>" then str = "" end
				local current = el_entry:GetText() or ""
				if string.Trim(str) ~= "" then el_entry:SetText(current..str) end
				--------
				el_cmenuOpen = false
				if el_entry then
					el_entry:RequestFocus()
				end
			end

			Menu.Paint = function(self, w, h)
				draw.RoundedBoxEx(8, 0, 0, w, h, Color( 255, 255, 255, 255 ), false, true, true, false)
			end

			local mTitle = Menu:AddOption( string.upper(ent.v:GetClass()) )
			mTitle:SetIcon( "icon16/bug.png" )
			mTitle.Paint = function(self, w, h) draw.RoundedBoxEx(8, 0, 0, w, h, Color( 240, 240, 240, 255 ), false, true, false, false) end

			Menu:GetVBar().Paint = function() return true end
			Menu:GetVBar().btnUp.Paint = function() return true end
			Menu:GetVBar().btnDown.Paint = function() return true end
			Menu:GetVBar().btnGrip.Paint = function() return true end
			Menu:GetVBar():SetWidth(0)
			function Menu:OnScrollbarAppear() return true end

			Menu:AddSpacer()
			if (ent.v.Health and ent.v:Health() > 0) or ent.v.Team or ent.v.GetActiveWeapon or ent.v:IsPlayer() then
				if ent.v.Health and ent.v:Health() > 0 then Menu:AddOption("Health: "..tostring(ent.v:Health())) end
				if ent.v.Team then 
					local sm = Menu:AddSubMenu("Team: "..tostring(ent.v:Team()))
					local tm = sm:AddOption(" ")
					tm.Paint = function(self, w, h)
						draw.RoundedBox(0, 0, 0, w, h, team.GetColor( ent.v:Team() or 0 ))
						surface.SetDrawColor( 255, 255, 255, 255 )
					end
					Menu:AddOption("Group: "..tostring(ent.v:GetNetworkedString( "UserGroup" ))) 
				end
				if ent.v.GetActiveWeapon then
					local en = ent.v:GetActiveWeapon()
					if IsValid(en) then
						Menu:AddOption("Weapon: "..tostring(en:GetClass()))
					else
						Menu:AddOption("Weapon: <Undefined>")
					end
				end
				Menu:AddSpacer()
			end
			for k,v in next, ent.tab do
				local SubMenu = Menu:AddSubMenu( k, Menu.MainFunc )
				SubMenu.Paint = Menu.Paint
				local x = tostring(v)
				if string.Trim(x) ~= "" then
					if type(v) == "table" then
						local s = SubMenu:AddOption( tostring(x), Menu.MainFunc )
						s.Paint = mTitle.Paint
						SubMenu:AddSpacer()
						local count = 0
						for i,d in next, v do
							local l = SubMenu:AddSubMenu( tostring(i), Menu.MainFunc )
							l.Paint = Menu.Paint
							if string.Trim(tostring(d)) ~= "" then
								l:AddOption( tostring(d), Menu.MainFunc )
							else
								l:AddOption( "<Undefined>", Menu.CancleFunc )
							end
							count = count + 1
						end
						if count <= 0 then SubMenu:AddOption( "<Empty>", Menu.CancleFunc ) end
						count = 0
					else
						SubMenu:AddOption( tostring(x), Menu.MainFunc )
					end
				else
					SubMenu:AddOption( "<Undefined>", Menu.CancleFunc )
				end
			end
			Menu:Open()
			Menu:RequestFocus()
		end
		nettable = nil
	end)

	local function EntityClick(code, pos, tr, state)
		if not state and code == (MOUSE_RIGHT or 108) then
			if IsValid(tr.Entity) then
				local tempent = tr.Entity:EntIndex()
				net.Start("xlSendEntInfo")
				net.WriteTable({tempent})
				net.SendToServer()
				tempent = nil
			end
		elseif not state then
			if IsValid(Menu) then Menu:Close() Menu:Remove() end
			if IsValid(el_entry) then el_entry:RequestFocus() end
		end
	end

	local function BuildMenu()
		if not derma.GetSkinTable()["Black"] then
			local skinf = derma.GetSkinTable()["Default"] or SKIN;
			skinf.Colours.Label.Bright	= Color(255,255,255);
			skinf.Colours.Label.Dark	= Color(255,255,255);
			derma.DefineSkin( "Black", "wat", skinf );
		end

		local hax = vgui.Create("DFrame")
		hax:SetPos(0,0)
		hax:SetSize( ScrW(), ScrH() )
		hax:SetTitle(" ")
		hax:SetDraggable( false )
		hax:ShowCloseButton( false )
		hax:SetWorldClicker( true )
		hax:MakePopup()
		hax.Paint = function()
			draw.RoundedBox( 8, 0, 0, hax:GetWide(), hax:GetTall(), Color( 0, 0, 0, 0 ) )
		end

		local PlyList = vgui.Create( "DListView", hax )
		PlyList:SetSize( ScrW()/3, ScrH()/5 )
		PlyList:SetMultiSelect( true )

		PlyList.Paint = function(self, w, h) draw.RoundedBoxEx(8, 0, 0, w, h, Color( 0, 0, 0, 220 ), false, false, false, true) end

		local plist = {}
		plist[1] = PlyList:AddColumn( "Index" );
		plist[1]:SetFixedWidth( 40 );
		plist[2] = PlyList:AddColumn( "Player" );
		plist[2]:SetWidth( 200 );
		plist[3] = PlyList:AddColumn( "SteamID" );
		plist[3]:SetFixedWidth( 116 );

		for _,v in next, plist do
			v.Header:SetTextColor( Color( 255, 255, 255 ) ) 
			v.Header.Paint = function(self, w, h) draw.RoundedBox( 0, 0, 0, w+10, h, Color(0,0,0,230) ) end 
		end

		for _,v in next, player.GetAll() do
			local a = PlyList:AddLine( v:EntIndex(), v:Nick() or v:Name(), tostring(v:SteamID()) or "NULL" )
			a.Entity = v
			a:SetSkin("Black")
		end

		PlyList.OnRowSelected = function()
			local sel = sel or {}
			local vlist = PlyList:GetSelected() or {}
			for _,v in next, vlist do
				if not table.HasValue(sel, v.Entity) then 
					table.insert(sel, v.Entity)
				end
			end
			net.Start("ulx_selector") net.WriteTable(sel) net.SendToServer()
		end

		hax.OnMousePressed = function( p, code )
			EntityClick(code, gui.ScreenToVector( gui.MousePos() ), LocalPlayer():GetEyeTrace(), true)
		end
		hax.OnMouseReleased = function( p, code )
			EntityClick(code, gui.ScreenToVector( gui.MousePos() ), LocalPlayer():GetEyeTrace(), false)
		end

		local txtbox = vgui.Create( "DTextEntry", hax )
		if txtbox then el_entry = txtbox end
		txtbox:SetPos( 0, ScrH() - 25 )
		txtbox:SetSize( ScrW(), 25 )
		txtbox:RequestFocus()
		txtbox.OnLoseFocus = function( self ) timer.Simple(0.5, function() if IsValid(self) and not el_cmenuOpen then self:RequestFocus() end end) end
		txtbox.Paint = function( self )
			draw.RoundedBoxEx(8, 0, 0, self:GetWide(), self:GetTall(), Color( 0, 0, 0, 250 ), true, true, false, false)
			self:DrawTextEntryText(Color(255, 255, 255), Color(30, 130, 255), Color(255, 255, 255))
		end

		local i = 0
		txtbox.OnKeyCodeTyped = function( self, key )
			local str = self:GetValue()
			if key == KEY_DOWN then
				i=i+1; if i > #pastCommands then i = 1 end
				if pastCommands[i] then
					self:SetText(pastCommands[i])
					self:SetValue(pastCommands[i])
				end
				return true
			elseif key == KEY_UP then
				i=i-1; if i > #pastCommands or i <= 0 then i = #pastCommands end
				if pastCommands[i] then
					self:SetText(pastCommands[i])
					self:SetValue(pastCommands[i])
				end
				return true
			elseif key == KEY_ESCAPE or gui.IsConsoleVisible() then
				hax:Remove()
				return true
			elseif key == KEY_ENTER then
				if not table.HasValue(pastCommands, string.Left(str, 1000)) then
					if #pastCommands <= 50 then
						table.insert(pastCommands, string.Left(str, 1000))
					else
						table.Empty(pastCommands)
					end
				end

				if LocalPlayer():query( "ulx exlua" ) then
					ulx.exlua(LocalPlayer(), str)
					------
					net.Start("xlSendULXCommand")
					net.WriteString(str)
					net.SendToServer()
				end

				hax:Remove()
				return true
			end
			return false
		end
	end

	local function TriggerMenu()
		if not LocalPlayer():query( "ulx exlua" ) then return end

		local tab = {}
		table.RemoveByValue( pastCommands, "" )
		table.RemoveByValue( pastCommands, nil )
		for _,v in next, pastCommands do 
			local v = tostring(v)
			if v and string.Trim(v) ~= "" then
				table.insert(tab, v)
			end
		end
		pastCommands = tab
		tab = nil
		chat.Close()

		BuildMenu()
	end

	concommand.Add("exlua_menu", function( ply ) if LocalPlayer() == ply then TriggerMenu() end end)
	hook.Add("ChatTextChanged", "__ExLuaM", function(str)
		if str == "!l " or str == "!L " then
			TriggerMenu()
		end
	end)
end