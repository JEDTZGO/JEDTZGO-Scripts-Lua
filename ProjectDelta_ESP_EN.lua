local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
local Camera            = workspace.CurrentCamera

-- ─── ESP Colors (world labels) ────────────────────────────────────────────────
local C_NPC        = Color3.fromRGB(255, 180,   0)
local C_CORPSE     = Color3.fromRGB(180, 180, 180)
local C_CORPSE_NPC = Color3.fromRGB(120, 120, 120)

-- ─── Item filter ──────────────────────────────────────────────────────────────
local FILTER = {
    Equipment=true, Keychain=true, Map=true, DAGR=true,
    Lighter=true, Radio=true, Pathfinder=true, ['"Pathfinder"']=true,
    DV2=true, EstonianBorderMap=true,
    ["Village Key"]=true, ["EVAC key"]=true, ["EVAC Key"]=true,
    ["Airfield Key"]=true, ["Garage Key"]=true,
    ["Fueling Station Key"]=true, ["Lighthouse Key"]=true,
    ["W. Shirt"]=true, ["W. Pants"]=true,
}

-- ─── Default configuration values ─────────────────────────────────────────────
-- CFG is the single source of truth for all settings.
-- It is loaded from disk on startup, updated by Matcha callbacks,
-- and saved to disk whenever the user changes something.
local CFG_DEFAULTS = {
    invEsp       = false,
    showList     = true,
    aimOn        = true,
    npcEsp       = true,
    bodyEsp      = true,
    mapOn        = true,
    listOpacity  = 0.85,
    rightOpacity = 0.85,
    lx = 10,  ly = 340,
    rx = 0,   ry = 44,
}

local CFG = {}
for k,v in pairs(CFG_DEFAULTS) do CFG[k]=v end

-- ─── Serialization (pure Lua, no executor APIs) ───────────────────────────────
-- Format: "PD|key:value|key:value|..." — compact, fits on a single line.
local function exportCFG()
    local parts = {"PD"}
    for k,v in pairs(CFG) do
        local t = type(v)
        if t=="boolean" then
            parts[#parts+1] = k..":"..(v and "1" or "0")
        elseif t=="number" then
            -- round to 4 significant digits to keep the string short
            parts[#parts+1] = k..":"..string.format("%.4g", v)
        end
    end
    return table.concat(parts, "|")
end

local function importCFG(raw)
    if type(raw)~="string" or raw:sub(1,3)~="PD|" then return false end
    local data = {}
    for pair in raw:gmatch("[^|]+") do
        local k,v = pair:match("^(%w+):(.+)$")
        if k and v and CFG_DEFAULTS[k]~=nil then
            local defType = type(CFG_DEFAULTS[k])
            if defType=="boolean" then
                data[k] = (v=="1")
            elseif defType=="number" then
                local n = tonumber(v)
                if n then data[k]=n end
            end
        end
    end
    for k,v in pairs(data) do CFG[k]=v end
    return true
end

-- Attempts setclipboard (available in most executors). Silently ignores if unavailable.
local function copyToClipboard(str)
    pcall(setclipboard, str)
end

-- ─── Runtime state ────────────────────────────────────────────────────────────
local INV = {
    cursor=1, selected=nil, players={}, lastN=0, dirty=false,
    lx=CFG.lx, ly=CFG.ly, rx=CFG.rx, ry=CFG.ry,
}
local MAX_P       = 20
local MAX_I       = 15
local lastAimName = nil
local THRESHOLD2  = 350 * 350

-- ─── Drawing utilities ────────────────────────────────────────────────────────
local DH         = 14
local PAD        = 8
local BASE_W     = 185
local RESIZE_HIT = 12
local LP         = {w=185, h=200}
local RP         = {w=215, h=300}

local C_ACCENT = Color3.fromRGB(195, 66, 148)
local C_TEXT   = Color3.fromRGB(240, 240, 245)
local C_DIM    = Color3.fromRGB(120, 115, 135)
local C_BG     = Color3.fromRGB( 28,  26,  34)
local C_DRAG   = Color3.fromRGB( 18,  17,  22)
local C_BORDER = Color3.fromRGB( 55,  50,  65)

local function sv(o, v) if o then o.Visible=v end end
local function clamp(v, lo, hi)
    if v<lo then return lo elseif v>hi then return hi end; return v
end
local function inRect(mx, my, rx, ry, rw, rh)
    return mx>=rx and mx<=rx+rw and my>=ry and my<=ry+rh
end
local function fontSize(w)
    return math.max(9, math.min(20, math.floor(12*(w/BASE_W))))
end
local function mkSq(x,y,w,h,col,zi,tr,cr)
    local o=Drawing.new("Square")
    o.Filled=true; o.Color=col; o.Transparency=tr or 0
    o.Position=Vector2.new(x,y); o.Size=Vector2.new(w,h)
    o.ZIndex=zi; o.Visible=false
    pcall(function() o.Corner=cr or 0 end); return o
end
local function mkSqO(x,y,w,h,col,zi,cr)
    local o=Drawing.new("Square")
    o.Filled=false; o.Color=col; o.Transparency=0; o.Thickness=1
    o.Position=Vector2.new(x,y); o.Size=Vector2.new(w,h)
    o.ZIndex=zi; o.Visible=false
    pcall(function() o.Corner=cr or 0 end); return o
end
local function mkTx(x,y,t,col,sz,zi,bold)
    local o=Drawing.new("Text")
    o.Text=t; o.Size=sz; o.Color=col; o.Outline=false; o.Center=false
    o.Font=bold and Drawing.Fonts.SystemBold or Drawing.Fonts.Monospace
    o.Position=Vector2.new(x,y); o.ZIndex=zi; o.Visible=false; return o
end
local function mkLn(x1,y1,x2,y2,col,tr,zi)
    local o=Drawing.new("Line")
    o.From=Vector2.new(x1,y1); o.To=Vector2.new(x2,y2)
    o.Color=col; o.Transparency=tr; o.Thickness=1
    o.ZIndex=zi; o.Visible=false; return o
end

-- ─── Player list panel (Drawing) ──────────────────────────────────────────────
local lDrag    = mkSq (0,0,LP.w,DH, C_DRAG,  7,1,3)
local lDOut    = mkSqO(0,0,LP.w,DH, C_BORDER,7,  3)
local lDLbl    = mkTx (0,0,":: players", C_ACCENT,11,8)
local lBg      = mkSq (0,0,LP.w,20, C_BG,    8,1,3)
local lOut     = mkSqO(0,0,LP.w,20, C_BORDER,8,  3)
local lSep     = mkLn (0,0,0,0, C_BORDER,0.3,9)
local lResizeA = mkLn (0,0,0,0, C_ACCENT, 0.3,10)
local lResizeB = mkLn (0,0,0,0, C_ACCENT, 0.3,10)
local pRows = {}
for i=1,MAX_P do pRows[i]=mkTx(0,0,"",C_DIM,12,10) end

-- Uses CFG directly — safe to call at any point, even before UI.AddTab
local function applyListOpacity()
    local tr = 1 - CFG.listOpacity
    lBg.Transparency=tr; lDrag.Transparency=tr
end
local function applyListPos(x, y)
    lDrag.Position=Vector2.new(x,y-DH); lDrag.Size=Vector2.new(LP.w,DH)
    lDOut.Position=Vector2.new(x,y-DH); lDOut.Size=Vector2.new(LP.w,DH)
    lDLbl.Position=Vector2.new(x+PAD,y-DH+2)
    lBg.Position=Vector2.new(x,y); lOut.Position=Vector2.new(x,y)
    lSep.From=Vector2.new(x+PAD,y+18); lSep.To=Vector2.new(x+LP.w-PAD,y+18)
    applyListOpacity()
end
local function updateListResize()
    local x,y=INV.lx,INV.ly; local bx=x+LP.w; local by=y+LP.h
    lResizeA.From=Vector2.new(bx-RESIZE_HIT,by); lResizeA.To=Vector2.new(bx,by)
    lResizeB.From=Vector2.new(bx,by-RESIZE_HIT); lResizeB.To=Vector2.new(bx,by)
    sv(lResizeA,true); sv(lResizeB,true)
end
local function hideList()
    sv(lDrag,false); sv(lDOut,false); sv(lDLbl,false)
    sv(lBg,false); sv(lOut,false); sv(lSep,false)
    sv(lResizeA,false); sv(lResizeB,false)
    for i=1,MAX_P do sv(pRows[i],false) end
end
local function buildList()
    if not CFG.invEsp or not CFG.showList then hideList(); return end
    local x,y   = INV.lx, INV.ly
    local fs    = fontSize(LP.w)
    local rowH  = fs+6
    local all   = Players:GetPlayers()
    local n     = math.min(#all, MAX_P)
    INV.players = all
    if INV.cursor>n then INV.cursor=math.max(n,1) end
    LP.h = math.max(22+n*rowH+4, 60)
    lBg.Position=Vector2.new(x,y); lBg.Size=Vector2.new(LP.w,LP.h)
    lOut.Position=Vector2.new(x,y); lOut.Size=Vector2.new(LP.w,LP.h)
    sv(lDrag,true); sv(lDOut,true); sv(lDLbl,true)
    sv(lBg,true);   sv(lOut,true);  sv(lSep,true)
    local ry=y+22
    for i=1,MAX_P do
        if i<=n then
            pRows[i].Size     = fs
            pRows[i].Position = Vector2.new(x+PAD,ry)
            pRows[i].Text     = all[i].Name
            pRows[i].Color    = (i==INV.cursor) and C_ACCENT or C_TEXT
            sv(pRows[i],true); ry=ry+rowH
        else sv(pRows[i],false) end
    end
    updateListResize(); INV.dirty=false
end

-- ─── Right panel (inventory, Drawing) ────────────────────────────────────────
local rBg      = mkSq (0,0,RP.w,20, C_BG,    8,1,3)
local rOut     = mkSqO(0,0,RP.w,20, C_BORDER,8,  3)
local rDrag    = mkSq (0,0,RP.w,DH, C_DRAG,  9,1,3)
local rDOut    = mkSqO(0,0,RP.w,DH, C_BORDER,9,  3)
local rDLbl    = mkTx (0,0,":: drag", C_DIM,11,10)
local rTitle   = mkTx (0,0,"", C_ACCENT,12,10)
local rSep     = mkLn (0,0,0,0, C_BORDER,0.3,10)
local rResizeA = mkLn (0,0,0,0, C_ACCENT, 0.3,11)
local rResizeB = mkLn (0,0,0,0, C_ACCENT, 0.3,11)
local rRows = {}
for i=1,MAX_I do rRows[i]=mkTx(0,0,"",C_TEXT,12,11) end
local rEmpty   = mkTx(0,0,"  (empty)",C_DIM,12,11)
local rMore    = mkTx(0,0,"",C_DIM,12,11)
local rVisible = false

local function applyRightOpacity()
    local tr = 1 - CFG.rightOpacity
    rBg.Transparency=tr; rDrag.Transparency=tr
end
local function applyRightPos(x,y,h)
    rDrag.Position=Vector2.new(x,y); rDrag.Size=Vector2.new(RP.w,DH)
    rDOut.Position=Vector2.new(x,y); rDOut.Size=Vector2.new(RP.w,DH)
    rDLbl.Position=Vector2.new(x+PAD,y+2)
    local by=y+DH
    rBg.Position=Vector2.new(x,by);  rBg.Size=Vector2.new(RP.w,h)
    rOut.Position=Vector2.new(x,by); rOut.Size=Vector2.new(RP.w,h)
    rTitle.Position=Vector2.new(x+PAD,by+5); rTitle.Size=fontSize(RP.w)+1
    rSep.From=Vector2.new(x+PAD,by+20); rSep.To=Vector2.new(x+RP.w-PAD,by+20)
    local bx=x+RP.w; local bot=by+h
    rResizeA.From=Vector2.new(bx-RESIZE_HIT,bot); rResizeA.To=Vector2.new(bx,bot)
    rResizeB.From=Vector2.new(bx,bot-RESIZE_HIT); rResizeB.To=Vector2.new(bx,bot)
    applyRightOpacity()
end
local function hideRight()
    sv(rBg,false); sv(rOut,false); sv(rTitle,false); sv(rSep,false)
    sv(rDrag,false); sv(rDOut,false); sv(rDLbl,false)
    sv(rEmpty,false); sv(rMore,false)
    sv(rResizeA,false); sv(rResizeB,false)
    for i=1,MAX_I do sv(rRows[i],false) end
    rVisible=false
end
local function showRight(title, items)
    local x,y  = INV.rx, INV.ry
    local fs   = fontSize(RP.w); local rowH=fs+6
    local n    = #items
    local vis  = math.min(n,MAX_I)
    local ext  = math.max(n-MAX_I,0)
    local H    = 26+math.max(vis,1)*rowH+PAD+(ext>0 and rowH or 0)+PAD
    RP.h=H; applyRightPos(x,y,H)
    rTitle.Text=title
    sv(rDrag,true); sv(rDOut,true); sv(rDLbl,true)
    sv(rBg,true);   sv(rOut,true);  sv(rTitle,true)
    sv(rSep,true);  sv(rResizeA,true); sv(rResizeB,true)
    local ry=y+DH+26
    if n==0 then
        rEmpty.Size=fs; rEmpty.Position=Vector2.new(x+PAD,ry)
        sv(rEmpty,true); sv(rMore,false)
        for i=1,MAX_I do sv(rRows[i],false) end
    else
        sv(rEmpty,false)
        for i=1,MAX_I do
            if i<=vis then
                rRows[i].Size=fs; rRows[i].Position=Vector2.new(x+PAD,ry)
                rRows[i].Text="· "..items[i].name
                sv(rRows[i],true); ry=ry+rowH
            else sv(rRows[i],false) end
        end
        if ext>0 then
            rMore.Size=fs; rMore.Text="  + "..ext.." more"
            rMore.Position=Vector2.new(x+PAD,ry); sv(rMore,true)
        else sv(rMore,false) end
    end
    rVisible=true
end

local function readInv(folder)
    local t={}
    if not folder then return t end
    for _,item in ipairs(folder:GetChildren()) do
        if not FILTER[item.Name] then table.insert(t,{name=item.Name}) end
    end
    return t
end
local function hideInv()
    if INV.selected then hideRight(); INV.selected=nil end
end
local function openCursor()
    local p=INV.players[INV.cursor]
    if not p then return end
    if INV.selected==p.Name then
        hideInv()
    else
        INV.selected=p.Name
        local vp=Camera.ViewportSize
        local nx=INV.lx+LP.w+6
        if nx+RP.w>vp.X-4 then nx=INV.lx-RP.w-6 end
        INV.rx=nx; INV.ry=INV.ly-DH
        local rs=ReplicatedStorage:FindFirstChild("Players")
        local pf=rs and rs:FindFirstChild(p.Name)
        showRight(p.Name, readInv(pf and pf:FindFirstChild("Inventory")))
        buildList()
    end
end

-- ─── World ESP labels ─────────────────────────────────────────────────────────
local espSlots={}
local function espLabel(col)
    local t=Drawing.new("Text"); t.Color=col; t.Size=13; t.Outline=true
    t.Center=true; t.Font=Drawing.Fonts.SystemBold; t.Visible=false; return t
end
local function espRoot(m)
    return m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("LowerTorso")
        or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Head")
        or m:FindFirstChildOfClass("MeshPart") or m:FindFirstChildOfClass("BasePart")
end
local function espGet(m, col)
    if not espSlots[m] then
        espSlots[m]={label=espLabel(col), root=espRoot(m), text="", col=col}
    end
    return espSlots[m]
end
local function espRemove(m)
    if espSlots[m] then
        espSlots[m].label.Visible=false
        espSlots[m].label:Remove()
        espSlots[m]=nil
    end
end

-- ─── Matcha menu tab ──────────────────────────────────────────────────────────

UI.AddTab("Project Delta", function(tab)

    -- Left: Inv ESP
    local invSec = tab:Section("Inv ESP", "Left")

    invSec:Toggle("invEsp", "Inv ESP", CFG.invEsp, function(state)
        CFG.invEsp=state
        if state then buildList()
        else hideList(); hideRight(); INV.selected=nil end
    end)

    invSec:Toggle("showList", "Player list", CFG.showList, function(state)
        CFG.showList=state
        if CFG.invEsp then
            if state then buildList() else hideList(); hideInv() end
        end
    end)

    invSec:Toggle("aimOn", "Aim panel", CFG.aimOn, function(state)
        CFG.aimOn=state
        if not state and not INV.selected then hideRight() end
    end)

    -- Left: World ESP
    local worldSec = tab:Section("World ESP", "Left")

    worldSec:Toggle("npcEsp",  "NPC ESP",       CFG.npcEsp,  function(state) CFG.npcEsp=state  end)
    worldSec:Toggle("bodyEsp", "Dead Body ESP",  CFG.bodyEsp, function(state) CFG.bodyEsp=state end)
    worldSec:Toggle("mapOn",   "Map ESP",        CFG.mapOn,   function(state) CFG.mapOn=state   end)

    -- Right: Opacity
    local opSec = tab:Section("Opacity", "Right")

    opSec:SliderFloat("listOpacity", "List panel", 0.0, 1.0, CFG.listOpacity, "%.2f", function(val)
        CFG.listOpacity=val
        lBg.Transparency=1-val; lDrag.Transparency=1-val
    end)

    opSec:SliderFloat("rightOpacity", "Inv / Aim panel", 0.0, 1.0, CFG.rightOpacity, "%.2f", function(val)
        CFG.rightOpacity=val
        rBg.Transparency=1-val; rDrag.Transparency=1-val
    end)

    -- Right: Save / Load config
    local saveSec = tab:Section("Config", "Right")

    saveSec:Text("Export copies your config to the clipboard.")
    saveSec:Text("Paste it into the Import field to restore it.")
    saveSec:Spacing()

    -- Export: encodes the current CFG + panel positions and copies to clipboard
    saveSec:Button("Export config  (copy to clipboard)", function()
        -- sync panel positions into CFG before exporting
        CFG.lx=INV.lx; CFG.ly=INV.ly
        CFG.rx=INV.rx; CFG.ry=INV.ry
        local str = exportCFG()
        copyToClipboard(str)
        notify("Config copied to clipboard!", "Project Delta", 3)
    end)

    saveSec:Spacing()

    -- Import: user pastes the exported string here and presses Enter
    local importField = saveSec:InputText("cfgImport", "Paste config here", "", function(text)
        if importCFG(text) then
            -- apply all loaded values
            UI.SetValue("invEsp",       CFG.invEsp)
            UI.SetValue("showList",     CFG.showList)
            UI.SetValue("aimOn",        CFG.aimOn)
            UI.SetValue("npcEsp",       CFG.npcEsp)
            UI.SetValue("bodyEsp",      CFG.bodyEsp)
            UI.SetValue("mapOn",        CFG.mapOn)
            UI.SetValue("listOpacity",  CFG.listOpacity)
            UI.SetValue("rightOpacity", CFG.rightOpacity)
            -- apply opacity to Drawing panels
            lBg.Transparency=1-CFG.listOpacity;  lDrag.Transparency=1-CFG.listOpacity
            rBg.Transparency=1-CFG.rightOpacity; rDrag.Transparency=1-CFG.rightOpacity
            -- restore panel positions
            INV.lx=CFG.lx; INV.ly=CFG.ly
            INV.rx=CFG.rx; INV.ry=CFG.ry
            applyListPos(INV.lx, INV.ly)
            if CFG.invEsp then buildList() else hideList(); hideRight(); INV.selected=nil end
            -- clear the field
            UI.SetValue("cfgImport", "")
            notify("Config loaded!", "Project Delta", 3)
        else
            notify("Invalid config string.", "Project Delta", 3)
        end
    end)

    saveSec:Spacing()

    -- Right: Reset
    local miscSec = tab:Section("Misc", "Right")

    miscSec:Button("Reset to default values", function()
        for k,v in pairs(CFG_DEFAULTS) do CFG[k]=v end
        UI.SetValue("invEsp",       CFG.invEsp)
        UI.SetValue("showList",     CFG.showList)
        UI.SetValue("aimOn",        CFG.aimOn)
        UI.SetValue("npcEsp",       CFG.npcEsp)
        UI.SetValue("bodyEsp",      CFG.bodyEsp)
        UI.SetValue("mapOn",        CFG.mapOn)
        UI.SetValue("listOpacity",  CFG.listOpacity)
        UI.SetValue("rightOpacity", CFG.rightOpacity)
        INV.lx=CFG.lx; INV.ly=CFG.ly; INV.rx=CFG.rx; INV.ry=CFG.ry
        lBg.Transparency=1-CFG.listOpacity;  lDrag.Transparency=1-CFG.listOpacity
        rBg.Transparency=1-CFG.rightOpacity; rDrag.Transparency=1-CFG.rightOpacity
        hideList(); hideRight(); INV.selected=nil
        buildList()
    end)
end)

-- ─── List panel drag + keyboard navigation ────────────────────────────────────
local Mouse = LocalPlayer:GetMouse()
local K_UP=38; local K_DOWN=40; local K_ENTER=13; local K_BKSP=8

spawn(function()
    local wUp,wDwn,wEnt,wDel=false,false,false,false
    local dragTarget,dragOffX,dragOffY=nil,0,0
    local prevM1=false
    while true do
        task.wait(0.05)
        local mx,my = Mouse.X, Mouse.Y
        local m1    = ismouse1pressed()

        if m1 and not prevM1 then
            local ldy=INV.ly-DH
            local lbx=INV.lx+LP.w; local lby=INV.ly+LP.h
            local rbx=INV.rx+RP.w; local rby=INV.ry+DH+RP.h
            if CFG.invEsp and CFG.showList
                and inRect(mx,my,lbx-RESIZE_HIT,lby-RESIZE_HIT,RESIZE_HIT,RESIZE_HIT) then
                    dragTarget="lresize"
            elseif rVisible and inRect(mx,my,rbx-RESIZE_HIT,rby-RESIZE_HIT,RESIZE_HIT,RESIZE_HIT) then
                dragTarget="rresize"
            elseif inRect(mx,my,INV.lx,ldy,LP.w,DH) then
                dragTarget="list"; dragOffX=mx-INV.lx; dragOffY=my-ldy
            elseif rVisible and inRect(mx,my,INV.rx,INV.ry,RP.w,DH) then
                dragTarget="right"; dragOffX=mx-INV.rx; dragOffY=my-INV.ry
            end
        end
        if not m1 then dragTarget=nil end

        if dragTarget and m1 then
            local vp=Camera.ViewportSize
            if dragTarget=="list" then
                INV.lx=clamp(mx-dragOffX,0,vp.X-LP.w)
                INV.ly=clamp((my-dragOffY)+DH,DH,vp.Y-20)
                applyListPos(INV.lx,INV.ly); buildList()
                if INV.selected then
                    local rnx=INV.lx+LP.w+6
                    if rnx+RP.w>vp.X-4 then rnx=INV.lx-RP.w-6 end
                    INV.rx=rnx; INV.ry=INV.ly-DH
                    local rs=ReplicatedStorage:FindFirstChild("Players")
                    local pf=rs and rs:FindFirstChild(INV.selected)
                    showRight(INV.selected, readInv(pf and pf:FindFirstChild("Inventory")))
                end
            elseif dragTarget=="right" then
                INV.rx=clamp(mx-dragOffX,0,vp.X-RP.w)
                INV.ry=clamp(my-dragOffY,0,vp.Y-DH-20)
                local rs=ReplicatedStorage:FindFirstChild("Players")
                local name=INV.selected or lastAimName
                if name then
                    local pf=rs and rs:FindFirstChild(name)
                    local iv=pf and pf:FindFirstChild("Inventory")
                    if iv then showRight(name,readInv(iv)) end
                end
            elseif dragTarget=="lresize" then
                LP.w=clamp(mx-INV.lx,80,400)
                lDrag.Size=Vector2.new(LP.w,DH); lDOut.Size=Vector2.new(LP.w,DH)
                buildList()
            elseif dragTarget=="rresize" then
                RP.w=clamp(mx-INV.rx,80,500)
                RP.h=clamp(my-(INV.ry+DH),60,600)
                local rs=ReplicatedStorage:FindFirstChild("Players")
                local name=INV.selected or lastAimName
                if name then
                    local pf=rs and rs:FindFirstChild(name)
                    local iv=pf and pf:FindFirstChild("Inventory")
                    if iv then showRight(name,readInv(iv)) end
                end
                applyRightPos(INV.rx,INV.ry,RP.h)
            end
        end
        prevM1=m1

        -- keyboard navigation in the list
        local up  = iskeypressed(K_UP)
        local dwn = iskeypressed(K_DOWN)
        local ent = iskeypressed(K_ENTER)
        local del = iskeypressed(K_BKSP)
        if CFG.invEsp and CFG.showList then
            local n=#INV.players
            if up  and not wUp  and n>0 then INV.cursor=INV.cursor>1 and INV.cursor-1 or n; INV.dirty=true end
            if dwn and not wDwn and n>0 then INV.cursor=INV.cursor<n and INV.cursor+1 or 1; INV.dirty=true end
            if ent and not wEnt then openCursor() end
            if del and not wDel then hideInv() end
            if INV.dirty then buildList() end
        end
        wUp=up; wDwn=dwn; wEnt=ent; wDel=del

        -- world ESP label rendering
        local lc=LocalPlayer.Character
        local lr=lc and lc:FindFirstChild("HumanoidRootPart")
        for model,slot in pairs(espSlots) do
            local root=slot.root
            if not root or not root.Parent then
                slot.label.Visible=false
            else
                local isCorpse = slot.col==C_CORPSE or slot.col==C_CORPSE_NPC
                local show = (isCorpse and CFG.bodyEsp)
                          or (not isCorpse and CFG.npcEsp)
                if not show then
                    slot.label.Visible=false
                else
                    local sp,on=WorldToScreen(root.Position)
                    if on then
                        local hide=false; local dist=""
                        if lr then
                            local d=root.Position-lr.Position
                            local m=math.floor(math.sqrt(d.X*d.X+d.Y*d.Y+d.Z*d.Z))
                            if m>300 then hide=true else dist=" "..m.."m" end
                        end
                        if hide then slot.label.Visible=false
                        else
                            slot.label.Text=slot.text..dist
                            slot.label.Position=Vector2.new(sp.X,sp.Y-20)
                            slot.label.Visible=true
                        end
                    else slot.label.Visible=false end
                end
            end
        end
    end
end)

-- ─── Aim panel: tracks the player closest to the crosshair ───────────────────
lastAimName=nil
spawn(function()
    while true do
        task.wait(0.15)
        if not CFG.invEsp or not CFG.aimOn or INV.selected then
            if lastAimName and not INV.selected then hideRight(); lastAimName=nil end
        else
            local rsCache=ReplicatedStorage:FindFirstChild("Players")
            local vp=Camera.ViewportSize
            local cx,cy=vp.X*0.5,vp.Y*0.5
            local bestP,bestD=nil,THRESHOLD2
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and p.Character then
                    local root=p.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local sp,on=WorldToScreen(root.Position)
                        if on then
                            local dx,dy=sp.X-cx,sp.Y-cy
                            local d2=dx*dx+dy*dy
                            if d2<bestD then bestD=d2; bestP=p end
                        end
                    end
                end
            end
            if bestP then
                lastAimName=bestP.Name
                local pf=rsCache and rsCache:FindFirstChild(bestP.Name)
                showRight(bestP.Name, readInv(pf and pf:FindFirstChild("Inventory")))
            else
                if lastAimName then hideRight(); lastAimName=nil end
            end
        end
    end
end)

-- ─── NPC & corpse ESP scanner ─────────────────────────────────────────────────
spawn(function()
    while true do
        task.wait(0.5)
        local playerNames={}
        for _,p in ipairs(Players:GetPlayers()) do playerNames[p.Name]=true end
        local active={}

        local aiZones=workspace:FindFirstChild("AiZones")
        if aiZones then
            for _,zone in ipairs(aiZones:GetChildren()) do
                for _,npc in ipairs(zone:GetChildren()) do
                    local h=npc:FindFirstChildOfClass("Humanoid")
                    if h and h.Health>0 and not npc:FindFirstChild("RagdollConstraints") then
                        active[npc]=true
                        local slot=espGet(npc,C_NPC)
                        slot.text=npc.Name; slot.col=C_NPC; slot.label.Color=C_NPC
                    end
                end
            end
        end

        local dropped=workspace:FindFirstChild("DroppedItems")
        if dropped then
            for _,model in ipairs(dropped:GetChildren()) do
                local h=model:FindFirstChildOfClass("Humanoid")
                if h and h.Health==0 then
                    active[model]=true
                    local isPlayer=playerNames[model.Name]
                    local col=isPlayer and C_CORPSE or C_CORPSE_NPC
                    local slot=espGet(model,col)
                    slot.text=(isPlayer and "[DEAD] " or "[NPC] ")..model.Name
                    slot.col=col; slot.label.Color=col
                end
            end
        end

        for model in pairs(espSlots) do
            if not active[model] then espRemove(model) end
        end
    end
end)

-- ─── Player count watcher ─────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function()
    if not CFG.invEsp then return end
    local n=#Players:GetPlayers()
    if n~=INV.lastN then INV.lastN=n; buildList() end
end)

-- ─── Map ESP ──────────────────────────────────────────────────────────────────
-- Original logic from MapESP v12.3, toggled via CFG.mapOn instead of keypress.
-- K_MAP (M) still shows the map; if CFG.mapOn is off the map never renders.
local MAP_K_MAP   = 77  -- M
local MAP_C_ENEMY = Color3.fromRGB(220,  50,  50)
local MAP_C_SELF  = Color3.fromRGB(255, 220,   0)

local MAP_SCALE_X  =  0.133647
local MAP_SCALE_Y  =  0.133905
local MAP_ORIGIN_X =  933.08
local MAP_ORIGIN_Y =  556.44

local function mapFindWait(parent, name)
    local o = parent:FindFirstChild(name)
    while not o do task.wait(0.1); o = parent:FindFirstChild(name) end
    return o
end

local mapGui       = LocalPlayer.PlayerGui
local mapMainFrame = mapFindWait(
    mapFindWait(mapFindWait(mapGui, "MainGui").MainFrame, "MapFrame"), "MainFrame"
)

local function worldToMap(wx, wz)
    return MAP_ORIGIN_X + wx * MAP_SCALE_X,
           MAP_ORIGIN_Y + wz * MAP_SCALE_Y
end

local mapDots = {}

local function mapNewDot(col)
    local o = Drawing.new("Circle")
    o.Radius=5; o.Filled=true; o.Color=col
    o.Transparency=1; o.NumSides=12; o.Visible=false
    return o
end
local function mapNewLabel(col)
    local o = Drawing.new("Text")
    o.Color=col; o.Size=10; o.Outline=true
    o.Center=true; o.Font=Drawing.Fonts.SystemBold; o.Visible=false
    return o
end
local function mapGetOrCreate(name, col)
    if not mapDots[name] then
        mapDots[name] = {dot=mapNewDot(col), label=mapNewLabel(col)}
    end
    return mapDots[name]
end
local function mapRemoveDot(name)
    if mapDots[name] then
        mapDots[name].dot:Remove(); mapDots[name].label:Remove(); mapDots[name]=nil
    end
end
local function mapHideAll()
    for _,s in pairs(mapDots) do s.dot.Visible=false; s.label.Visible=false end
end

local function mapGetRootPart(p)
    if not p.Character then return nil end
    return p.Character:FindFirstChild("HumanoidRootPart")
        or p.Character:FindFirstChild("UpperTorso")
        or p.Character:FindFirstChild("Head")
        or p.Character:FindFirstChildOfClass("BasePart")
end

local mapLastPos = {}

spawn(function()
    local wasOpen = false
    while true do
        local keyDown = iskeypressed(MAP_K_MAP)
        local open    = keyDown and CFG.mapOn   -- respects the UI toggle

        if not open then
            if wasOpen then mapHideAll() end
        else
            local current = {}
            for _,p in ipairs(Players:GetPlayers()) do current[p.Name]=p end

            for name in pairs(mapDots) do
                if not current[name] then
                    mapRemoveDot(name); mapLastPos[name]=nil
                end
            end

            for name,p in pairs(current) do
                local isSelf = (name == LocalPlayer.Name)
                local col    = isSelf and MAP_C_SELF or MAP_C_ENEMY

                local root
                if isSelf then
                    local char = LocalPlayer.Character
                    root = char and char:FindFirstChild("HumanoidRootPart")
                else
                    root = mapGetRootPart(p)
                end

                local wx, wz
                if root then
                    wx,wz = root.Position.X, root.Position.Z
                    mapLastPos[name] = {x=wx, z=wz}
                elseif mapLastPos[name] then
                    wx,wz = mapLastPos[name].x, mapLastPos[name].z
                end

                if wx then
                    local px,py = worldToMap(wx,wz)
                    local s = mapGetOrCreate(name,col)
                    s.dot.Color   = col; s.label.Color = col
                    s.dot.Position   = Vector2.new(px,py);      s.dot.Visible   = true
                    s.label.Text     = isSelf and "[ you ]" or name
                    s.label.Position = Vector2.new(px,py-12);   s.label.Visible = true
                elseif mapDots[name] then
                    mapDots[name].dot.Visible=false; mapDots[name].label.Visible=false
                end
            end
        end

        wasOpen = open
        task.wait(open and 0.1 or 0.2)
    end
end)

-- ─── Init ─────────────────────────────────────────────────────────────────────
INV.rx = Camera.ViewportSize.X - RP.w - 10
applyListPos(INV.lx, INV.ly)
applyRightOpacity()
if CFG.invEsp then buildList() end
notify("Project Delta  -  open Matcha menu to configure", "PD v4.0", 4)
