local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local LocalPlayer=Players.LocalPlayer
local Mouse=LocalPlayer:GetMouse()
local Camera=workspace.CurrentCamera

local C_WIN=Color3.fromRGB(22,22,26)
local C_BORDER=Color3.fromRGB(55,50,65)
local C_ACCENT=Color3.fromRGB(195,66,148)
local C_TEXT=Color3.fromRGB(240,240,245)
local C_DIM=Color3.fromRGB(120,115,135)
local C_ON=Color3.fromRGB(195,66,148)
local C_OFF=Color3.fromRGB(60,55,70)
local C_THUMB=Color3.fromRGB(255,255,255)
local C_BG=Color3.fromRGB(28,26,34)
local C_DRAG=Color3.fromRGB(18,17,22)
local C_NPC=Color3.fromRGB(255,180,0)
local C_CORPSE=Color3.fromRGB(180,180,180)
local C_CORPSE_NPC=Color3.fromRGB(120,120,120)

local K_HOME=36;local K_UP=38;local K_DOWN=40;local K_ENTER=13;local K_BKSP=8
local CFG={invEsp=false,showList=true,aimOn=true,npcEsp=true,bodyEsp=true}
local UI={open=false,wx=80,wy=80,dragging=false,dragOffX=0,dragOffY=0}
local INV={cursor=1,selected=nil,players={},lastN=0,dirty=false,lx=10,ly=340,rx=0,ry=44,dragTarget=nil,dragOffX=0,dragOffY=0,prevM1=false}
local LP={w=185,h=200,opacity=0.85}
local RP={w=215,h=300,opacity=0.85}

local PAD=8;local DH=14;local MAX_P=20;local MAX_I=15
local WW=340;local ROW_H=28;local SEC_H=22
local WH=28+SEC_H+ROW_H*3+8+SEC_H+ROW_H*2+8+SEC_H+ROW_H*2+12
local RESIZE_HIT=12
local BASE_W=185  -- ancho base de referencia para calcular font size

local FILTER={
    Equipment=true,Keychain=true,Map=true,DAGR=true,
    Lighter=true,Radio=true,Pathfinder=true,['"Pathfinder"']=true,
    DV2=true,EstonianBorderMap=true,
    ["Village Key"]=true,["EVAC key"]=true,["EVAC Key"]=true,
    ["Airfield Key"]=true,["Garage Key"]=true,
    ["Fueling Station Key"]=true,["Lighthouse Key"]=true,
    ["W. Shirt"]=true,["W. Pants"]=true,
}

local function sv(o,v) if o then o.Visible=v end end
local function sq(x,y,w,h,col,zi,tr,cr)
    local o=Drawing.new("Square")
    o.Filled=true;o.Color=col;o.Transparency=tr or 0
    o.Position=Vector2.new(x,y);o.Size=Vector2.new(w,h)
    o.ZIndex=zi;o.Visible=false
    pcall(function() o.Corner=cr or 0 end);return o
end
local function sqO(x,y,w,h,col,zi,cr)
    local o=Drawing.new("Square")
    o.Filled=false;o.Color=col;o.Transparency=0;o.Thickness=1
    o.Position=Vector2.new(x,y);o.Size=Vector2.new(w,h)
    o.ZIndex=zi;o.Visible=false
    pcall(function() o.Corner=cr or 0 end);return o
end
local function tx(x,y,t,col,sz,zi,bold)
    local o=Drawing.new("Text")
    o.Text=t;o.Size=sz;o.Color=col;o.Outline=false;o.Center=false
    o.Font=bold and Drawing.Fonts.SystemBold or Drawing.Fonts.Monospace
    o.Position=Vector2.new(x,y);o.ZIndex=zi;o.Visible=false;return o
end
local function ln(x1,y1,x2,y2,col,tr,zi)
    local o=Drawing.new("Line")
    o.From=Vector2.new(x1,y1);o.To=Vector2.new(x2,y2)
    o.Color=col;o.Transparency=tr;o.Thickness=1
    o.ZIndex=zi;o.Visible=false;return o
end
local function inRect(mx,my,rx,ry,rw,rh) return mx>=rx and mx<=rx+rw and my>=ry and my<=ry+rh end
local function clamp(v,lo,hi) if v<lo then return lo elseif v>hi then return hi end return v end
local function fontSize(w) return math.max(9,math.min(20,math.floor(12*(w/BASE_W)))) end

-- Ventana config
local wBg=sq(0,0,WW,WH,C_WIN,20,1,4);local wOut=sqO(0,0,WW,WH,C_BORDER,20,4)
local wBar=sq(0,0,WW,28,C_DRAG,21,1,4);local wTitle=tx(0,0,"Project Delta",C_TEXT,13,22,true);local wSub=tx(0,0,"v4.0",C_DIM,11,22)
local wSep0=ln(0,0,0,0,C_BORDER,0.3,21);local sSec1=tx(0,0,"inv esp",C_DIM,10,21)
local t1Lbl=tx(0,0,"inv esp",C_TEXT,12,22);local t1Bg=sq(0,0,36,18,C_OFF,23,1,9);local t1Dot=sq(0,0,14,14,C_THUMB,24,1,7)
local t2Lbl=tx(0,0,"player list",C_TEXT,12,22);local t2Bg=sq(0,0,36,18,C_ON,23,1,9);local t2Dot=sq(0,0,14,14,C_THUMB,24,1,7)
local t3Lbl=tx(0,0,"aim panel",C_TEXT,12,22);local t3Bg=sq(0,0,36,18,C_ON,23,1,9);local t3Dot=sq(0,0,14,14,C_THUMB,24,1,7)
local wSep1=ln(0,0,0,0,C_BORDER,0.3,21);local sSec2=tx(0,0,"world esp",C_DIM,10,21)
local t4Lbl=tx(0,0,"npc esp",C_TEXT,12,22);local t4Bg=sq(0,0,36,18,C_ON,23,1,9);local t4Dot=sq(0,0,14,14,C_THUMB,24,1,7)
local t5Lbl=tx(0,0,"dead body esp",C_TEXT,12,22);local t5Bg=sq(0,0,36,18,C_ON,23,1,9);local t5Dot=sq(0,0,14,14,C_THUMB,24,1,7)
local wSep2=ln(0,0,0,0,C_BORDER,0.3,21);local sSec3=tx(0,0,"opacity",C_DIM,10,21)
local sl1Lbl=tx(0,0,"list",C_TEXT,12,22);local sl1Track=sq(0,0,120,4,C_OFF,22,1,2);local sl1Thumb=sq(0,0,10,10,C_ACCENT,23,1,5);local sl1Val=tx(0,0,"85%",C_DIM,11,22)
local sl2Lbl=tx(0,0,"inv / aim",C_TEXT,12,22);local sl2Track=sq(0,0,120,4,C_OFF,22,1,2);local sl2Thumb=sq(0,0,10,10,C_ACCENT,23,1,5);local sl2Val=tx(0,0,"85%",C_DIM,11,22)
local WIN_ELEMENTS={wBg,wOut,wBar,wTitle,wSub,wSep0,sSec1,t1Lbl,t1Bg,t1Dot,t2Lbl,t2Bg,t2Dot,t3Lbl,t3Bg,t3Dot,wSep1,sSec2,t4Lbl,t4Bg,t4Dot,t5Lbl,t5Bg,t5Dot,wSep2,sSec3,sl1Lbl,sl1Track,sl1Thumb,sl1Val,sl2Lbl,sl2Track,sl2Thumb,sl2Val}
local SLIDER_W=120

local function positionWindow(wx,wy)
    local x,y=wx,wy
    wBg.Position=Vector2.new(x,y);wBg.Size=Vector2.new(WW,WH)
    wOut.Position=Vector2.new(x,y);wOut.Size=Vector2.new(WW,WH)
    wBar.Position=Vector2.new(x,y);wBar.Size=Vector2.new(WW,28)
    wTitle.Position=Vector2.new(x+12,y+7);wSub.Position=Vector2.new(x+WW-30,y+9)
    wSep0.From=Vector2.new(x,y+28);wSep0.To=Vector2.new(x+WW,y+28)
    local cy=y+32;sSec1.Position=Vector2.new(x+12,cy+4);cy=cy+SEC_H
    local function fila(lbl,bg,dot,on)
        lbl.Position=Vector2.new(x+12,cy+7)
        bg.Position=Vector2.new(x+WW-50,cy+5);bg.Size=Vector2.new(36,18)
        dot.Position=Vector2.new(on and (x+WW-50+20) or (x+WW-50+2),cy+7);dot.Size=Vector2.new(14,14)
        cy=cy+ROW_H
    end
    fila(t1Lbl,t1Bg,t1Dot,CFG.invEsp);fila(t2Lbl,t2Bg,t2Dot,CFG.showList);fila(t3Lbl,t3Bg,t3Dot,CFG.aimOn)
    wSep1.From=Vector2.new(x+8,cy);wSep1.To=Vector2.new(x+WW-8,cy);cy=cy+8
    sSec2.Position=Vector2.new(x+12,cy+4);cy=cy+SEC_H
    fila(t4Lbl,t4Bg,t4Dot,CFG.npcEsp);fila(t5Lbl,t5Bg,t5Dot,CFG.bodyEsp)
    wSep2.From=Vector2.new(x+8,cy);wSep2.To=Vector2.new(x+WW-8,cy);cy=cy+8
    sSec3.Position=Vector2.new(x+12,cy+4);cy=cy+SEC_H
    local tx2=x+55
    sl1Lbl.Position=Vector2.new(x+12,cy+7);sl1Track.Position=Vector2.new(tx2,cy+11);sl1Track.Size=Vector2.new(SLIDER_W,4)
    sl1Thumb.Position=Vector2.new(tx2+math.floor(LP.opacity*SLIDER_W)-5,cy+7);sl1Thumb.Size=Vector2.new(10,10)
    sl1Val.Position=Vector2.new(tx2+SLIDER_W+8,cy+7);sl1Val.Text=math.floor(LP.opacity*100).."%";cy=cy+ROW_H
    sl2Lbl.Position=Vector2.new(x+12,cy+7);sl2Track.Position=Vector2.new(tx2,cy+11);sl2Track.Size=Vector2.new(SLIDER_W,4)
    sl2Thumb.Position=Vector2.new(tx2+math.floor(RP.opacity*SLIDER_W)-5,cy+7);sl2Thumb.Size=Vector2.new(10,10)
    sl2Val.Position=Vector2.new(tx2+SLIDER_W+8,cy+7);sl2Val.Text=math.floor(RP.opacity*100).."%"
end
local function showWindow() positionWindow(UI.wx,UI.wy);for _,e in ipairs(WIN_ELEMENTS) do sv(e,true) end;UI.open=true end
local function hideWindow() for _,e in ipairs(WIN_ELEMENTS) do sv(e,false) end;UI.open=false end
local function updateToggle(bg,dot,on) bg.Color=on and C_ON or C_OFF;dot.Position=Vector2.new(on and (bg.Position.X+20) or (bg.Position.X+2),dot.Position.Y) end
local function refreshToggles()
    updateToggle(t1Bg,t1Dot,CFG.invEsp);updateToggle(t2Bg,t2Dot,CFG.showList)
    updateToggle(t3Bg,t3Dot,CFG.aimOn);updateToggle(t4Bg,t4Dot,CFG.npcEsp);updateToggle(t5Bg,t5Dot,CFG.bodyEsp)
end

-- Panel lista
local lDrag=sq(0,0,LP.w,DH,C_DRAG,7,1,3);local lDOut=sqO(0,0,LP.w,DH,C_BORDER,7,3)
local lDLbl=tx(0,0,":: players",C_ACCENT,11,8);local lBg=sq(0,0,LP.w,20,C_BG,8,1,3)
local lOut=sqO(0,0,LP.w,20,C_BORDER,8,3);local lSep=ln(0,0,0,0,C_BORDER,0.3,9)
local lResizeA=ln(0,0,0,0,C_ACCENT,0.3,10);local lResizeB=ln(0,0,0,0,C_ACCENT,0.3,10)
local pRows={}
for i=1,MAX_P do pRows[i]=tx(0,0,"",C_DIM,12,10) end

local function applyListOpacity() local tr=1-LP.opacity;lBg.Transparency=tr;lDrag.Transparency=tr end
local function applyListPos(x,y)
    lDrag.Position=Vector2.new(x,y-DH);lDrag.Size=Vector2.new(LP.w,DH)
    lDOut.Position=Vector2.new(x,y-DH);lDOut.Size=Vector2.new(LP.w,DH)
    lDLbl.Position=Vector2.new(x+PAD,y-DH+2)
    lBg.Position=Vector2.new(x,y);lOut.Position=Vector2.new(x,y)
    lSep.From=Vector2.new(x+PAD,y+18);lSep.To=Vector2.new(x+LP.w-PAD,y+18)
    applyListOpacity()
end
local function updateListResize()
    local x,y=INV.lx,INV.ly;local bx=x+LP.w;local by=y+LP.h
    lResizeA.From=Vector2.new(bx-RESIZE_HIT,by);lResizeA.To=Vector2.new(bx,by)
    lResizeB.From=Vector2.new(bx,by-RESIZE_HIT);lResizeB.To=Vector2.new(bx,by)
    sv(lResizeA,true);sv(lResizeB,true)
end
local function hideList()
    sv(lDrag,false);sv(lDOut,false);sv(lDLbl,false);sv(lBg,false);sv(lOut,false);sv(lSep,false)
    sv(lResizeA,false);sv(lResizeB,false)
    for i=1,MAX_P do sv(pRows[i],false) end
end
local function buildList()
    if not CFG.invEsp or not CFG.showList then hideList();return end
    local x,y=INV.lx,INV.ly
    local fs=fontSize(LP.w)
    local rowH=fs+6
    local all=Players:GetPlayers();local n=math.min(#all,MAX_P)
    INV.players=all
    if INV.cursor>n then INV.cursor=math.max(n,1) end
    LP.h=math.max(22+n*rowH+4,60)
    lBg.Position=Vector2.new(x,y);lBg.Size=Vector2.new(LP.w,LP.h)
    lOut.Position=Vector2.new(x,y);lOut.Size=Vector2.new(LP.w,LP.h)
    sv(lDrag,true);sv(lDOut,true);sv(lDLbl,true);sv(lBg,true);sv(lOut,true);sv(lSep,true)
    local ry=y+22
    for i=1,MAX_P do
        if i<=n then
            local sel=(i==INV.cursor)
            pRows[i].Size=fs
            pRows[i].Position=Vector2.new(x+PAD,ry)
            pRows[i].Text=all[i].Name
            pRows[i].Color=sel and C_ACCENT or C_TEXT
            sv(pRows[i],true);ry=ry+rowH
        else sv(pRows[i],false) end
    end
    updateListResize();INV.dirty=false
end

-- Panel derecho
local rBg=sq(0,0,RP.w,20,C_BG,8,1,3);local rOut=sqO(0,0,RP.w,20,C_BORDER,8,3)
local rDrag=sq(0,0,RP.w,DH,C_DRAG,9,1,3);local rDOut=sqO(0,0,RP.w,DH,C_BORDER,9,3)
local rDLbl=tx(0,0,":: drag",C_DIM,11,10);local rTitle=tx(0,0,"",C_ACCENT,12,10)
local rSep=ln(0,0,0,0,C_BORDER,0.3,10);local rResizeA=ln(0,0,0,0,C_ACCENT,0.3,11);local rResizeB=ln(0,0,0,0,C_ACCENT,0.3,11)
local rRows={}
for i=1,MAX_I do rRows[i]=tx(0,0,"",C_TEXT,12,11) end
local rEmpty=tx(0,0,"  (empty)",C_DIM,12,11);local rMore=tx(0,0,"",C_DIM,12,11)
local rVisible=false

local function applyRightOpacity() local tr=1-RP.opacity;rBg.Transparency=tr;rDrag.Transparency=tr end
local function applyRightPos(x,y,h)
    rDrag.Position=Vector2.new(x,y);rDrag.Size=Vector2.new(RP.w,DH)
    rDOut.Position=Vector2.new(x,y);rDOut.Size=Vector2.new(RP.w,DH)
    rDLbl.Position=Vector2.new(x+PAD,y+2)
    local by=y+DH
    rBg.Position=Vector2.new(x,by);rBg.Size=Vector2.new(RP.w,h)
    rOut.Position=Vector2.new(x,by);rOut.Size=Vector2.new(RP.w,h)
    rTitle.Position=Vector2.new(x+PAD,by+5);rTitle.Size=fontSize(RP.w)+1
    rSep.From=Vector2.new(x+PAD,by+20);rSep.To=Vector2.new(x+RP.w-PAD,by+20)
    local bx=x+RP.w;local bot=by+h
    rResizeA.From=Vector2.new(bx-RESIZE_HIT,bot);rResizeA.To=Vector2.new(bx,bot)
    rResizeB.From=Vector2.new(bx,bot-RESIZE_HIT);rResizeB.To=Vector2.new(bx,bot)
    applyRightOpacity()
end
local function hideRight()
    sv(rBg,false);sv(rOut,false);sv(rTitle,false);sv(rSep,false)
    sv(rDrag,false);sv(rDOut,false);sv(rDLbl,false);sv(rEmpty,false);sv(rMore,false)
    sv(rResizeA,false);sv(rResizeB,false)
    for i=1,MAX_I do sv(rRows[i],false) end;rVisible=false
end
local function showRight(title,items)
    local x,y=INV.rx,INV.ry
    local fs=fontSize(RP.w);local rowH=fs+6
    local n=#items;local vis=math.min(n,MAX_I);local ext=math.max(n-MAX_I,0)
    local H=26+math.max(vis,1)*rowH+PAD+(ext>0 and rowH or 0)+PAD
    RP.h=H;applyRightPos(x,y,H)
    rTitle.Text=title
    sv(rDrag,true);sv(rDOut,true);sv(rDLbl,true);sv(rBg,true);sv(rOut,true);sv(rTitle,true);sv(rSep,true);sv(rResizeA,true);sv(rResizeB,true)
    local ry=y+DH+26
    if n==0 then
        rEmpty.Size=fs;rEmpty.Position=Vector2.new(x+PAD,ry);sv(rEmpty,true);sv(rMore,false)
        for i=1,MAX_I do sv(rRows[i],false) end
    else
        sv(rEmpty,false)
        for i=1,MAX_I do
            if i<=vis then
                rRows[i].Size=fs;rRows[i].Position=Vector2.new(x+PAD,ry)
                rRows[i].Text="· "..items[i].name
                sv(rRows[i],true);ry=ry+rowH
            else sv(rRows[i],false) end
        end
        if ext>0 then
            rMore.Size=fs;rMore.Text="  + "..ext.." more"
            rMore.Position=Vector2.new(x+PAD,ry);sv(rMore,true)
        else sv(rMore,false) end
    end
    rVisible=true
end

local function readInv(folder)
    local t={}
    if not folder then return t end
    for _,item in ipairs(folder:GetChildren()) do
        if not FILTER[item.Name] then
            table.insert(t,{name=item.Name})
        end
    end
    return t
end
local function hideInv() if INV.selected then hideRight();INV.selected=nil end end
local function openCursor()
    local p=INV.players[INV.cursor]
    if not p then return end
    if INV.selected==p.Name then hideInv()
    else
        INV.selected=p.Name
        local vp=Camera.ViewportSize
        local nx=INV.lx+LP.w+6
        if nx+RP.w>vp.X-4 then nx=INV.lx-RP.w-6 end
        INV.rx=nx;INV.ry=INV.ly-DH
        local rs=ReplicatedStorage:FindFirstChild("Players")
        local pf=rs and rs:FindFirstChild(p.Name)
        showRight(p.Name,readInv(pf and pf:FindFirstChild("Inventory")))
        buildList()
    end
end

-- ESP
local espSlots={}
local function espLabel(col)
    local t=Drawing.new("Text");t.Color=col;t.Size=13;t.Outline=true
    t.Center=true;t.Font=Drawing.Fonts.SystemBold;t.Visible=false;return t
end
local function espRoot(m)
    return m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("LowerTorso")
        or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Head")
        or m:FindFirstChildOfClass("MeshPart") or m:FindFirstChildOfClass("BasePart")
end
local function espGet(m,col)
    if not espSlots[m] then espSlots[m]={label=espLabel(col),root=espRoot(m),text="",col=col} end
    return espSlots[m]
end
local function espRemove(m)
    if espSlots[m] then espSlots[m].label.Visible=false;espSlots[m].label:Remove();espSlots[m]=nil end
end

-- Sliders
local activeSlider=nil
local function applySlider1(mx)
    local op=clamp((mx-sl1Track.Position.X)/SLIDER_W,0,1);LP.opacity=op
    sl1Thumb.Position=Vector2.new(sl1Track.Position.X+math.floor(op*SLIDER_W)-5,sl1Thumb.Position.Y)
    sl1Val.Text=math.floor(op*100).."%";applyListOpacity()
end
local function applySlider2(mx)
    local op=clamp((mx-sl2Track.Position.X)/SLIDER_W,0,1);RP.opacity=op
    sl2Thumb.Position=Vector2.new(sl2Track.Position.X+math.floor(op*SLIDER_W)-5,sl2Thumb.Position.Y)
    sl2Val.Text=math.floor(op*100).."%";applyRightOpacity()
end

local function handleToggleClick(mx,my)
    if not UI.open then return end
    local function check(bg,key)
        if inRect(mx,my,bg.Position.X,bg.Position.Y,36,18) then
            CFG[key]=not CFG[key];refreshToggles()
            if key=="invEsp" then if CFG.invEsp then buildList() else hideList();hideRight();INV.selected=nil end
            elseif key=="showList" and CFG.invEsp then if CFG.showList then buildList() else hideList();hideInv() end
            elseif key=="aimOn" then if not CFG.aimOn and not INV.selected then hideRight() end end
        end
    end
    check(t1Bg,"invEsp");check(t2Bg,"showList");check(t3Bg,"aimOn");check(t4Bg,"npcEsp");check(t5Bg,"bodyEsp")
end

spawn(function()
    local wHome,wUp,wDwn,wEnt,wDel=false,false,false,false,false
    while true do
        task.wait(0.05)
        local mx=Mouse.X;local my=Mouse.Y;local m1=ismouse1pressed()
        local home=iskeypressed(K_HOME)
        if home and not wHome then if UI.open then hideWindow() else showWindow() end end
        wHome=home
        if m1 and not INV.prevM1 then
            handleToggleClick(mx,my)
            if UI.open and inRect(mx,my,UI.wx,UI.wy,WW,28) then UI.dragging=true;UI.dragOffX=mx-UI.wx;UI.dragOffY=my-UI.wy end
            if UI.open then
                if inRect(mx,my,sl1Track.Position.X,sl1Track.Position.Y-4,SLIDER_W,12) then activeSlider="list";applySlider1(mx)
                elseif inRect(mx,my,sl2Track.Position.X,sl2Track.Position.Y-4,SLIDER_W,12) then activeSlider="right";applySlider2(mx) end
            end
            local ldy=INV.ly-DH;local lbx=INV.lx+LP.w;local lby=INV.ly+LP.h
            local rbx=INV.rx+RP.w;local rby=INV.ry+DH+RP.h
            if CFG.invEsp and CFG.showList and inRect(mx,my,lbx-RESIZE_HIT,lby-RESIZE_HIT,RESIZE_HIT,RESIZE_HIT) then INV.dragTarget="lresize"
            elseif rVisible and inRect(mx,my,rbx-RESIZE_HIT,rby-RESIZE_HIT,RESIZE_HIT,RESIZE_HIT) then INV.dragTarget="rresize"
            elseif inRect(mx,my,INV.lx,ldy,LP.w,DH) then INV.dragTarget="list";INV.dragOffX=mx-INV.lx;INV.dragOffY=my-ldy
            elseif rVisible and inRect(mx,my,INV.rx,INV.ry,RP.w,DH) then INV.dragTarget="right";INV.dragOffX=mx-INV.rx;INV.dragOffY=my-INV.ry end
        end
        if not m1 then UI.dragging=false;INV.dragTarget=nil;activeSlider=nil end
        if UI.dragging and m1 then
            local vp=Camera.ViewportSize
            UI.wx=clamp(mx-UI.dragOffX,0,vp.X-WW);UI.wy=clamp(my-UI.dragOffY,0,vp.Y-WH)
            positionWindow(UI.wx,UI.wy);refreshToggles()
        end
        if activeSlider and m1 then if activeSlider=="list" then applySlider1(mx) else applySlider2(mx) end end
        if INV.dragTarget and m1 then
            local vp=Camera.ViewportSize
            if INV.dragTarget=="list" then
                INV.lx=clamp(mx-INV.dragOffX,0,vp.X-LP.w);INV.ly=clamp((my-INV.dragOffY)+DH,DH,vp.Y-20)
                applyListPos(INV.lx,INV.ly);buildList()
                if INV.selected then
                    local rnx=INV.lx+LP.w+6;if rnx+RP.w>vp.X-4 then rnx=INV.lx-RP.w-6 end
                    INV.rx=rnx;INV.ry=INV.ly-DH
                    local rs=ReplicatedStorage:FindFirstChild("Players");local pf=rs and rs:FindFirstChild(INV.selected)
                    showRight(INV.selected,readInv(pf and pf:FindFirstChild("Inventory")))
                end
            elseif INV.dragTarget=="right" then
                INV.rx=clamp(mx-INV.dragOffX,0,vp.X-RP.w);INV.ry=clamp(my-INV.dragOffY,0,vp.Y-DH-20)
                local rs=ReplicatedStorage:FindFirstChild("Players");local name=INV.selected or lastAimName
                if name then local pf=rs and rs:FindFirstChild(name);local iv=pf and pf:FindFirstChild("Inventory");if iv then showRight(name,readInv(iv)) end end
            elseif INV.dragTarget=="lresize" then
                LP.w=clamp(mx-INV.lx,80,400);lDrag.Size=Vector2.new(LP.w,DH);lDOut.Size=Vector2.new(LP.w,DH);buildList()
            elseif INV.dragTarget=="rresize" then
                RP.w=clamp(mx-INV.rx,80,500);RP.h=clamp(my-(INV.ry+DH),60,600)
                local rs=ReplicatedStorage:FindFirstChild("Players");local name=INV.selected or lastAimName
                if name then local pf=rs and rs:FindFirstChild(name);local iv=pf and pf:FindFirstChild("Inventory");if iv then showRight(name,readInv(iv)) end end
                applyRightPos(INV.rx,INV.ry,RP.h)
            end
        end
        INV.prevM1=m1
        local up=iskeypressed(K_UP);local dwn=iskeypressed(K_DOWN);local ent=iskeypressed(K_ENTER);local del=iskeypressed(K_BKSP)
        if CFG.invEsp and CFG.showList then
            local n=#INV.players
            if up and not wUp and n>0 then INV.cursor=INV.cursor>1 and INV.cursor-1 or n;INV.dirty=true end
            if dwn and not wDwn and n>0 then INV.cursor=INV.cursor<n and INV.cursor+1 or 1;INV.dirty=true end
            if ent and not wEnt then openCursor() end;if del and not wDel then hideInv() end
            if INV.dirty then buildList() end
        end
        wUp=up;wDwn=dwn;wEnt=ent;wDel=del
        local lc=LocalPlayer.Character;local lr=lc and lc:FindFirstChild("HumanoidRootPart")
        for model,slot in pairs(espSlots) do
            local root=slot.root
            if not root or not root.Parent then slot.label.Visible=false
            else
                local isCorpse=slot.col==C_CORPSE or slot.col==C_CORPSE_NPC
                if not ((isCorpse and CFG.bodyEsp) or (not isCorpse and CFG.npcEsp)) then slot.label.Visible=false
                else
                    local sp,on=WorldToScreen(root.Position)
                    if on then
                        local hide=false;local dist=""
                        if lr then local d=root.Position-lr.Position;local m=math.floor(math.sqrt(d.X*d.X+d.Y*d.Y+d.Z*d.Z));if m>300 then hide=true else dist=" "..m.."m" end end
                        if hide then slot.label.Visible=false
                        else slot.label.Text=slot.text..dist;slot.label.Position=Vector2.new(sp.X,sp.Y-20);slot.label.Visible=true end
                    else slot.label.Visible=false end
                end
            end
        end
    end
end)

lastAimName=nil;local THRESHOLD2=350*350
spawn(function()
    while true do
        task.wait(0.15)
        if not CFG.invEsp or not CFG.aimOn or INV.selected then
            if lastAimName and not INV.selected then hideRight();lastAimName=nil end
        else
            local rsCache=ReplicatedStorage:FindFirstChild("Players")
            local vp=Camera.ViewportSize;local cx,cy=vp.X*0.5,vp.Y*0.5
            local bestP,bestD=nil,THRESHOLD2
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and p.Character then
                    local root=p.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local sp,on=WorldToScreen(root.Position)
                        if on then local dx,dy=sp.X-cx,sp.Y-cy;local d2=dx*dx+dy*dy;if d2<bestD then bestD=d2;bestP=p end end
                    end
                end
            end
            if bestP then
                lastAimName=bestP.Name
                local pf=rsCache and rsCache:FindFirstChild(bestP.Name)
                showRight(bestP.Name,readInv(pf and pf:FindFirstChild("Inventory")))
            else if lastAimName then hideRight();lastAimName=nil end end
        end
    end
end)

spawn(function()
    while true do
        task.wait(0.5)
        local playerNames={};for _,p in ipairs(Players:GetPlayers()) do playerNames[p.Name]=true end
        local active={}
        local aiZones=workspace:FindFirstChild("AiZones")
        if aiZones then
            for _,zone in ipairs(aiZones:GetChildren()) do
                for _,npc in ipairs(zone:GetChildren()) do
                    local h=npc:FindFirstChildOfClass("Humanoid")
                    if h and h.Health>0 and not npc:FindFirstChild("RagdollConstraints") then
                        active[npc]=true;local slot=espGet(npc,C_NPC);slot.text=npc.Name;slot.col=C_NPC;slot.label.Color=C_NPC
                    end
                end
            end
        end
        local dropped=workspace:FindFirstChild("DroppedItems")
        if dropped then
            for _,model in ipairs(dropped:GetChildren()) do
                local h=model:FindFirstChildOfClass("Humanoid")
                if h and h.Health==0 then
                    active[model]=true;local isPlayer=playerNames[model.Name];local col=isPlayer and C_CORPSE or C_CORPSE_NPC
                    local slot=espGet(model,col);slot.text=(isPlayer and "[DEAD] " or "[NPC] ")..model.Name;slot.col=col;slot.label.Color=col
                end
            end
        end
        for model in pairs(espSlots) do if not active[model] then espRemove(model) end end
    end
end)

RunService.RenderStepped:Connect(function()
    if not CFG.invEsp then return end
    local n=#Players:GetPlayers();if n~=INV.lastN then INV.lastN=n;buildList() end
end)

INV.rx=Camera.ViewportSize.X-RP.w-10
applyListPos(INV.lx,INV.ly)
notify("Project Delta  -  HOME to open config","PD v4.0",4)

