local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

local C_ACCENT=Color3.fromRGB(195,66,148); local C_TEXT=Color3.fromRGB(240,240,245)
local C_DIM=Color3.fromRGB(120,115,135);   local C_BG=Color3.fromRGB(28,26,34)
local C_DRAG=Color3.fromRGB(18,17,22);     local C_BORDER=Color3.fromRGB(55,50,65)
local C_NPC=Color3.fromRGB(255,180,0);     local C_CORPSE=Color3.fromRGB(180,180,180)
local C_CORPSE_NPC=Color3.fromRGB(120,120,120); local C_PLAYER=Color3.fromRGB(100,210,255)
local MAP_C_ENEMIGO=Color3.fromRGB(220,50,50); local MAP_C_YO=Color3.fromRGB(255,220,0)

local FILTRO={
    Equipment=true,Keychain=true,Map=true,DAGR=true,Lighter=true,Radio=true,
    Pathfinder=true,['"Pathfinder"']=true,DV2=true,EstonianBorderMap=true,
    ["Village Key"]=true,["EVAC key"]=true,["EVAC Key"]=true,
    ["Airfield Key"]=true,["Garage Key"]=true,["Fueling Station Key"]=true,
    ["Lighthouse Key"]=true,["W. Shirt"]=true,["W. Pants"]=true,
}

local CFG_DEFECTO={
    invEsp=true,mostrarLista=true,miraOn=true,jugadorEsp=true,npcEsp=true,cuerpoEsp=true,mapaOn=true,
    opacidadLista=0.85,opacidadDerecha=0.85,lx=10,ly=340,rx=0,ry=44,
}
local CFG={}; for k,v in pairs(CFG_DEFECTO) do CFG[k]=v end

local function exportarCFG()
    local p={"PD"}
    for k,v in pairs(CFG) do
        local t=type(v)
        if t=="boolean" then p[#p+1]=k..":"..(v and "1" or "0")
        elseif t=="number" then p[#p+1]=k..":"..string.format("%.4g",v) end
    end
    return table.concat(p,"|")
end
local function importarCFG(raw)
    if type(raw)~="string" or raw:sub(1,3)~="PD|" then return false end
    local datos={}
    for par in raw:gmatch("[^|]+") do
        local k,v=par:match("^(%w+):(.+)$")
        if k and v and CFG_DEFECTO[k]~=nil then
            local dt=type(CFG_DEFECTO[k])
            if dt=="boolean" then datos[k]=(v=="1")
            elseif dt=="number" then local n=tonumber(v); if n then datos[k]=n end end
        end
    end
    for k,v in pairs(datos) do CFG[k]=v end
    return true
end
local function copiarPortapapeles(str) pcall(setclipboard,str) end

local function esperarUI(timeout)
    local t=0
    while t<timeout do
        if type(UI)=="table" and UI.AddTab then return true end
        task.wait(0.2); t=t+0.2
    end
    return false
end
local function sv(o,v) if o then o.Visible=v end end
local function limitar(v,lo,hi) if v<lo then return lo elseif v>hi then return hi end; return v end
local function enRect(mx,my,rx,ry,rw,rh) return mx>=rx and mx<=rx+rw and my>=ry and my<=ry+rh end
local function tamanoFuente(w) return math.max(9,math.min(20,math.floor(12*(w/185)))) end
local function mkSq(x,y,w,h,col,zi,tr,cr)
    local o=Drawing.new("Square"); o.Filled=true; o.Color=col; o.Transparency=tr or 0
    o.Position=Vector2.new(x,y); o.Size=Vector2.new(w,h); o.ZIndex=zi; o.Visible=false
    pcall(function() o.Corner=cr or 0 end); return o
end
local function mkSqO(x,y,w,h,col,zi,cr)
    local o=Drawing.new("Square"); o.Filled=false; o.Color=col; o.Transparency=0; o.Thickness=1
    o.Position=Vector2.new(x,y); o.Size=Vector2.new(w,h); o.ZIndex=zi; o.Visible=false
    pcall(function() o.Corner=cr or 0 end); return o
end
local function mkTx(x,y,t,col,sz,zi,negrita)
    local o=Drawing.new("Text"); o.Text=t; o.Size=sz; o.Color=col; o.Outline=false; o.Center=false
    o.Font=negrita and Drawing.Fonts.SystemBold or Drawing.Fonts.Monospace
    o.Position=Vector2.new(x,y); o.ZIndex=zi; o.Visible=false; return o
end
local function mkLn(x1,y1,x2,y2,col,tr,zi)
    local o=Drawing.new("Line"); o.From=Vector2.new(x1,y1); o.To=Vector2.new(x2,y2)
    o.Color=col; o.Transparency=tr; o.Thickness=1; o.ZIndex=zi; o.Visible=false; return o
end

-- ─── ESP de mapa ──────────────────────────────────────────────────────────────
local MAP_SX=0.133647; local MAP_SY=0.133905
local MAP_OX=933.08;   local MAP_OY=556.44
local mapaPuntos={}; local mapaUltPos={}; local mapaUltChar={}

local function mundoAMapa(wx,wz) return MAP_OX+wx*MAP_SX, MAP_OY+wz*MAP_SY end
local function mapaNuevoPunto(col)
    local o=Drawing.new("Circle"); o.Radius=5; o.Filled=true; o.Color=col
    o.Transparency=1; o.NumSides=12; o.Visible=false; return o
end
local function mapaNuevaEtiqueta(col)
    local o=Drawing.new("Text"); o.Color=col; o.Size=10; o.Outline=true
    o.Center=true; o.Font=Drawing.Fonts.SystemBold; o.Visible=false; return o
end
local function mapaObtenerOCrear(nombre,col)
    if not mapaPuntos[nombre] then mapaPuntos[nombre]={punto=mapaNuevoPunto(col),etiqueta=mapaNuevaEtiqueta(col)} end
    return mapaPuntos[nombre]
end
local function mapaEliminar(nombre)
    if mapaPuntos[nombre] then
        pcall(function() mapaPuntos[nombre].punto:Remove() end)
        pcall(function() mapaPuntos[nombre].etiqueta:Remove() end)
        mapaPuntos[nombre]=nil
    end
    mapaUltPos[nombre]=nil; mapaUltChar[nombre]=nil
end
local function mapaOcultar()
    for _,s in pairs(mapaPuntos) do s.punto.Visible=false; s.etiqueta.Visible=false end
end
local function mapaRaiz(p)
    if not p.Character then return nil end
    local h=p.Character:FindFirstChildOfClass("Humanoid")
    if h and h.Health<=0 then return nil end
    return p.Character:FindFirstChild("HumanoidRootPart")
        or p.Character:FindFirstChild("UpperTorso")
        or p.Character:FindFirstChild("Head")
end

task.spawn(function()
    local estabaAbierto=false
    while true do
        task.wait(0.1)
        if not LocalPlayer then continue end
        local abierto=iskeypressed(77) and CFG.mapaOn
        if not abierto then
            if estabaAbierto then mapaOcultar() end
        else
            local actual={}
            for _,p in ipairs(Players:GetPlayers()) do actual[p.Name]=p end
            for nombre in pairs(mapaPuntos) do
                if not actual[nombre] then mapaEliminar(nombre) end
            end
            for nombre,p in pairs(actual) do
                if not LocalPlayer then break end
                local esYo=(nombre==LocalPlayer.Name)
                local col=esYo and MAP_C_YO or MAP_C_ENEMIGO
                if p.Character~=mapaUltChar[nombre] then
                    mapaUltPos[nombre]=nil; mapaUltChar[nombre]=p.Character
                end
                local raiz
                if esYo then
                    local char=LocalPlayer.Character
                    raiz=char and char:FindFirstChild("HumanoidRootPart")
                else raiz=mapaRaiz(p) end
                local wx,wz
                if raiz then wx,wz=raiz.Position.X,raiz.Position.Z; mapaUltPos[nombre]={x=wx,z=wz}
                elseif mapaUltPos[nombre] then wx,wz=mapaUltPos[nombre].x,mapaUltPos[nombre].z end
                if wx then
                    local px,py=mundoAMapa(wx,wz); local s=mapaObtenerOCrear(nombre,col)
                    s.punto.Color=col; s.etiqueta.Color=col
                    s.punto.Position=Vector2.new(px,py); s.punto.Visible=true
                    s.etiqueta.Text=esYo and "[ tu ]" or nombre
                    s.etiqueta.Position=Vector2.new(px,py-12); s.etiqueta.Visible=true
                elseif mapaPuntos[nombre] then
                    mapaPuntos[nombre].punto.Visible=false; mapaPuntos[nombre].etiqueta.Visible=false
                end
            end
        end
        estabaAbierto=abierto
    end
end)

-- ─── Arranque con espera ───────────────────────────────────────────────────────
notify("Project Delta cargando en 10s...","PD v5.3",4)
task.spawn(function()
    task.wait(10)
    if not esperarUI(20) then notify("Matcha no encontrado","PD v5.3",5); return end

    local Camara=workspace.CurrentCamera
    local DH=14; local MARG=8; local ZONA_RESIZE=12
    local LP={a=185,h=200}; local RP={a=215,h=300}
    local INV={cursor=1,seleccionado=nil,jugadores={},ultimoN=0,sucio=false,lx=CFG.lx,ly=CFG.ly,rx=CFG.rx,ry=CFG.ry}
    local MAX_J=20; local MAX_I=15
    local ultimoNombreMira=nil; local UMBRAL2=350*350; local pDerVisible=false
    local miraRx=0; local miraRy=CFG.ry

    -- ─── Paneles ──────────────────────────────────────────────────────────────
    local lArrastrar=mkSq(0,0,LP.a,DH,C_DRAG,7,1,3); local lBorde=mkSqO(0,0,LP.a,DH,C_BORDER,7,3)
    local lEtiq=mkTx(0,0,":: jugadores",C_ACCENT,11,8); local lFondo=mkSq(0,0,LP.a,20,C_BG,8,1,3)
    local lContorno=mkSqO(0,0,LP.a,20,C_BORDER,8,3); local lSep=mkLn(0,0,0,0,C_BORDER,0.3,9)
    local lResizeA=mkLn(0,0,0,0,C_ACCENT,0.3,10); local lResizeB=mkLn(0,0,0,0,C_ACCENT,0.3,10)
    local filasJ={}; for i=1,MAX_J do filasJ[i]=mkTx(0,0,"",C_DIM,12,10) end
    local rFondo=mkSq(0,0,RP.a,20,C_BG,8,1,3); local rContorno=mkSqO(0,0,RP.a,20,C_BORDER,8,3)
    local rArrastrar=mkSq(0,0,RP.a,DH,C_DRAG,9,1,3); local rBorde=mkSqO(0,0,RP.a,DH,C_BORDER,9,3)
    local rEtiq=mkTx(0,0,":: arrastra",C_DIM,11,10); local rTitulo=mkTx(0,0,"",C_ACCENT,12,10)
    local rSep=mkLn(0,0,0,0,C_BORDER,0.3,10); local rResizeA=mkLn(0,0,0,0,C_ACCENT,0.3,11)
    local rResizeB=mkLn(0,0,0,0,C_ACCENT,0.3,11)
    local filasI={}; for i=1,MAX_I do filasI[i]=mkTx(0,0,"",C_TEXT,12,11) end
    local rVacio=mkTx(0,0,"  (vacio)",C_DIM,12,11); local rMas=mkTx(0,0,"",C_DIM,12,11)

    local function aplicarOpacidadLista() local tr=1-CFG.opacidadLista; lFondo.Transparency=tr; lArrastrar.Transparency=tr end
    local function aplicarOpacidadDerecha() local tr=1-CFG.opacidadDerecha; rFondo.Transparency=tr; rArrastrar.Transparency=tr end
    local function aplicarPosList(x,y)
        lArrastrar.Position=Vector2.new(x,y-DH); lArrastrar.Size=Vector2.new(LP.a,DH)
        lBorde.Position=Vector2.new(x,y-DH); lBorde.Size=Vector2.new(LP.a,DH)
        lEtiq.Position=Vector2.new(x+MARG,y-DH+2)
        lFondo.Position=Vector2.new(x,y); lContorno.Position=Vector2.new(x,y)
        lSep.From=Vector2.new(x+MARG,y+18); lSep.To=Vector2.new(x+LP.a-MARG,y+18)
        aplicarOpacidadLista()
    end
    local function aplicarPosDerecha(x,y,h)
        rArrastrar.Position=Vector2.new(x,y); rArrastrar.Size=Vector2.new(RP.a,DH)
        rBorde.Position=Vector2.new(x,y); rBorde.Size=Vector2.new(RP.a,DH)
        rEtiq.Position=Vector2.new(x+MARG,y+2)
        local by=y+DH
        rFondo.Position=Vector2.new(x,by); rFondo.Size=Vector2.new(RP.a,h)
        rContorno.Position=Vector2.new(x,by); rContorno.Size=Vector2.new(RP.a,h)
        rTitulo.Position=Vector2.new(x+MARG,by+5); rTitulo.Size=tamanoFuente(RP.a)+1
        rSep.From=Vector2.new(x+MARG,by+20); rSep.To=Vector2.new(x+RP.a-MARG,by+20)
        local bx=x+RP.a; local bot=by+h
        rResizeA.From=Vector2.new(bx-ZONA_RESIZE,bot); rResizeA.To=Vector2.new(bx,bot)
        rResizeB.From=Vector2.new(bx,bot-ZONA_RESIZE); rResizeB.To=Vector2.new(bx,bot)
        aplicarOpacidadDerecha()
    end
    local function actualizarResizeLista()
        local x,y=INV.lx,INV.ly; local bx=x+LP.a; local by=y+LP.h
        lResizeA.From=Vector2.new(bx-ZONA_RESIZE,by); lResizeA.To=Vector2.new(bx,by)
        lResizeB.From=Vector2.new(bx,by-ZONA_RESIZE); lResizeB.To=Vector2.new(bx,by)
        sv(lResizeA,true); sv(lResizeB,true)
    end
    local function ocultarLista()
        sv(lArrastrar,false); sv(lBorde,false); sv(lEtiq,false)
        sv(lFondo,false); sv(lContorno,false); sv(lSep,false)
        sv(lResizeA,false); sv(lResizeB,false)
        for i=1,MAX_J do sv(filasJ[i],false) end
    end
    local function construirLista()
        if not CFG.invEsp or not CFG.mostrarLista then ocultarLista(); return end
        local x,y=INV.lx,INV.ly; local fs=tamanoFuente(LP.a); local altFila=fs+6
        local todos=Players:GetPlayers(); local n=math.min(#todos,MAX_J)
        INV.jugadores=todos; if INV.cursor>n then INV.cursor=math.max(n,1) end
        LP.h=math.max(22+n*altFila+4,60)
        lFondo.Position=Vector2.new(x,y); lFondo.Size=Vector2.new(LP.a,LP.h)
        lContorno.Position=Vector2.new(x,y); lContorno.Size=Vector2.new(LP.a,LP.h)
        sv(lArrastrar,true); sv(lBorde,true); sv(lEtiq,true)
        sv(lFondo,true); sv(lContorno,true); sv(lSep,true)
        local ry=y+22
        for i=1,MAX_J do
            if i<=n then
                filasJ[i].Size=fs; filasJ[i].Position=Vector2.new(x+MARG,ry)
                filasJ[i].Text=todos[i].Name
                filasJ[i].Color=(i==INV.cursor) and C_ACCENT or C_TEXT
                sv(filasJ[i],true); ry=ry+altFila
            else sv(filasJ[i],false) end
        end
        actualizarResizeLista(); INV.sucio=false
    end
    local function ocultarDerecha()
        sv(rFondo,false); sv(rContorno,false); sv(rTitulo,false); sv(rSep,false)
        sv(rArrastrar,false); sv(rBorde,false); sv(rEtiq,false)
        sv(rVacio,false); sv(rMas,false); sv(rResizeA,false); sv(rResizeB,false)
        for i=1,MAX_I do sv(filasI[i],false) end; pDerVisible=false
    end
    local function mostrarDerecha(titulo,items)
        local x,y=INV.rx,INV.ry; local fs=tamanoFuente(RP.a); local altFila=fs+6
        local n=#items; local vis=math.min(n,MAX_I); local ext=math.max(n-MAX_I,0)
        local H=26+math.max(vis,1)*altFila+MARG+(ext>0 and altFila or 0)+MARG
        RP.h=H; aplicarPosDerecha(x,y,H); rTitulo.Text=titulo
        sv(rArrastrar,true); sv(rBorde,true); sv(rEtiq,true)
        sv(rFondo,true); sv(rContorno,true); sv(rTitulo,true)
        sv(rSep,true); sv(rResizeA,true); sv(rResizeB,true)
        local ry=y+DH+26
        if n==0 then
            rVacio.Size=fs; rVacio.Position=Vector2.new(x+MARG,ry)
            sv(rVacio,true); sv(rMas,false)
            for i=1,MAX_I do sv(filasI[i],false) end
        else
            sv(rVacio,false)
            for i=1,MAX_I do
                if i<=vis then
                    filasI[i].Size=fs; filasI[i].Position=Vector2.new(x+MARG,ry)
                    filasI[i].Text="· "..items[i].nombre; sv(filasI[i],true); ry=ry+altFila
                else sv(filasI[i],false) end
            end
            if ext>0 then rMas.Size=fs; rMas.Text="  + "..ext.." mas"; rMas.Position=Vector2.new(x+MARG,ry); sv(rMas,true)
            else sv(rMas,false) end
        end
        pDerVisible=true
    end
    local function leerInventario(carpeta)
        local t={}; if not carpeta then return t end
        for _,item in ipairs(carpeta:GetChildren()) do
            if not FILTRO[item.Name] then table.insert(t,{nombre=item.Name}) end
        end; return t
    end
    local function ocultarInv()
        if INV.seleccionado then ocultarDerecha(); INV.seleccionado=nil; INV.rx=miraRx; INV.ry=miraRy end
    end
    local function abrirCursor()
        local p=INV.jugadores[INV.cursor]; if not p then return end
        if INV.seleccionado==p.Name then ocultarInv()
        else
            INV.seleccionado=p.Name
            local vp=Camara.ViewportSize; local nx=INV.lx+LP.a+6
            if nx+RP.a>vp.X-4 then nx=INV.lx-RP.a-6 end
            INV.rx=nx; INV.ry=INV.ly-DH
            local rs=ReplicatedStorage:FindFirstChild("Players")
            local pf=rs and rs:FindFirstChild(p.Name)
            mostrarDerecha(p.Name,leerInventario(pf and pf:FindFirstChild("Inventory")))
            construirLista()
        end
    end

    -- ─── ESP del mundo ────────────────────────────────────────────────────────
    local ranuras={}
    local function espEtiqueta(col)
        local t=Drawing.new("Text"); t.Color=col; t.Size=13; t.Outline=true
        t.Center=true; t.Font=Drawing.Fonts.SystemBold; t.Visible=false; return t
    end
    local function espRaiz(m)
        return m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
            or m:FindFirstChild("UpperTorso") or m:FindFirstChild("LowerTorso")
            or m:FindFirstChildOfClass("MeshPart") or m:FindFirstChildOfClass("BasePart")
    end
    local function espObtener(m,col)
        if not ranuras[m] then
            ranuras[m]={etiqueta=espEtiqueta(col),raiz=espRaiz(m),texto="",col=col}
        else
            if not ranuras[m].raiz or not ranuras[m].raiz.Parent then ranuras[m].raiz=espRaiz(m) end
            ranuras[m].etiqueta.Color=col; ranuras[m].col=col
        end
        return ranuras[m]
    end
    local function espEliminar(m)
        if ranuras[m] then
            ranuras[m].etiqueta.Visible=false
            pcall(function() ranuras[m].etiqueta:Remove() end)
            ranuras[m]=nil
        end
    end

    -- ─── Interfaz Matcha ──────────────────────────────────────────────────────
    UI.AddTab("Project Delta",function(tab)
        local secInv=tab:Section("Inv ESP","Left")
        secInv:Toggle("invEsp","Inv ESP",CFG.invEsp,function(estado)
            CFG.invEsp=estado
            if estado then construirLista() else ocultarLista(); ocultarDerecha(); INV.seleccionado=nil end
        end)
        secInv:Toggle("mostrarLista","Lista de jugadores",CFG.mostrarLista,function(estado)
            CFG.mostrarLista=estado
            if CFG.invEsp then if estado then construirLista() else ocultarLista(); ocultarInv() end end
        end)
        secInv:Toggle("miraOn","Panel de mira",CFG.miraOn,function(estado)
            CFG.miraOn=estado; if not estado and not INV.seleccionado then ocultarDerecha() end
        end)
        local secMundo=tab:Section("ESP del mundo","Left")
        secMundo:Toggle("jugadorEsp","ESP de jugadores",CFG.jugadorEsp,function(estado) CFG.jugadorEsp=estado end)
        secMundo:Toggle("npcEsp","ESP de NPCs",CFG.npcEsp,function(estado) CFG.npcEsp=estado end)
        secMundo:Toggle("cuerpoEsp","ESP de cadaveres",CFG.cuerpoEsp,function(estado) CFG.cuerpoEsp=estado end)
        secMundo:Toggle("mapaOn","ESP de mapa",CFG.mapaOn,function(estado)
            CFG.mapaOn=estado; if not estado then mapaOcultar() end
        end)
        local secOpac=tab:Section("Opacidad","Right")
        secOpac:SliderFloat("opacidadLista","Panel lista",0.0,1.0,CFG.opacidadLista,"%.2f",function(val)
            CFG.opacidadLista=val; lFondo.Transparency=1-val; lArrastrar.Transparency=1-val
        end)
        secOpac:SliderFloat("opacidadDerecha","Inv / Panel mira",0.0,1.0,CFG.opacidadDerecha,"%.2f",function(val)
            CFG.opacidadDerecha=val; rFondo.Transparency=1-val; rArrastrar.Transparency=1-val
        end)
        local secGuardar=tab:Section("Config","Right")
        secGuardar:Text("Exportar copia tu config al portapapeles.")
        secGuardar:Text("Pegala en el campo Importar para restaurarla.")
        secGuardar:Spacing()
        secGuardar:Button("Exportar config",function()
            CFG.lx=INV.lx; CFG.ly=INV.ly; CFG.rx=INV.rx; CFG.ry=INV.ry
            copiarPortapapeles(exportarCFG()); notify("Config copiada!","Project Delta",3)
        end)
        secGuardar:Spacing()
        secGuardar:InputText("cfgImportar","Pegar config aqui","",function(texto)
            if importarCFG(texto) then
                UI.SetValue("invEsp",CFG.invEsp); UI.SetValue("mostrarLista",CFG.mostrarLista)
                UI.SetValue("miraOn",CFG.miraOn); UI.SetValue("jugadorEsp",CFG.jugadorEsp)
                UI.SetValue("npcEsp",CFG.npcEsp)
                UI.SetValue("cuerpoEsp",CFG.cuerpoEsp); UI.SetValue("mapaOn",CFG.mapaOn)
                UI.SetValue("opacidadLista",CFG.opacidadLista); UI.SetValue("opacidadDerecha",CFG.opacidadDerecha)
                lFondo.Transparency=1-CFG.opacidadLista; lArrastrar.Transparency=1-CFG.opacidadLista
                rFondo.Transparency=1-CFG.opacidadDerecha; rArrastrar.Transparency=1-CFG.opacidadDerecha
                INV.lx=CFG.lx; INV.ly=CFG.ly; INV.rx=CFG.rx; INV.ry=CFG.ry
                aplicarPosList(INV.lx,INV.ly)
                if CFG.invEsp then construirLista() else ocultarLista(); ocultarDerecha(); INV.seleccionado=nil end
                UI.SetValue("cfgImportar",""); notify("Config cargada!","Project Delta",3)
            else notify("String invalido.","Project Delta",3) end
        end)
        secGuardar:Spacing()
        local secMisc=tab:Section("Misc","Right")
        secMisc:Button("Resetear a valores por defecto",function()
            for k,v in pairs(CFG_DEFECTO) do CFG[k]=v end
            UI.SetValue("invEsp",CFG.invEsp); UI.SetValue("mostrarLista",CFG.mostrarLista)
            UI.SetValue("miraOn",CFG.miraOn); UI.SetValue("jugadorEsp",CFG.jugadorEsp)
            UI.SetValue("npcEsp",CFG.npcEsp)
            UI.SetValue("cuerpoEsp",CFG.cuerpoEsp); UI.SetValue("mapaOn",CFG.mapaOn)
            UI.SetValue("opacidadLista",CFG.opacidadLista); UI.SetValue("opacidadDerecha",CFG.opacidadDerecha)
            INV.lx=CFG.lx; INV.ly=CFG.ly; INV.rx=CFG.rx; INV.ry=CFG.ry
            lFondo.Transparency=1-CFG.opacidadLista; lArrastrar.Transparency=1-CFG.opacidadLista
            rFondo.Transparency=1-CFG.opacidadDerecha; rArrastrar.Transparency=1-CFG.opacidadDerecha
            ocultarLista(); ocultarDerecha(); INV.seleccionado=nil; construirLista()
        end)
    end)

    -- ─── Inicio ───────────────────────────────────────────────────────────────
    INV.rx=Camara.ViewportSize.X-RP.a-10
    miraRx=INV.rx; miraRy=INV.ry
    aplicarPosList(INV.lx,INV.ly); aplicarOpacidadDerecha()
    pcall(function()
        UI.SetValue("invEsp",CFG.invEsp); UI.SetValue("mostrarLista",CFG.mostrarLista)
        UI.SetValue("miraOn",CFG.miraOn); UI.SetValue("jugadorEsp",CFG.jugadorEsp)
        UI.SetValue("npcEsp",CFG.npcEsp)
        UI.SetValue("cuerpoEsp",CFG.cuerpoEsp); UI.SetValue("mapaOn",CFG.mapaOn)
        UI.SetValue("opacidadLista",CFG.opacidadLista); UI.SetValue("opacidadDerecha",CFG.opacidadDerecha)
    end)
    if CFG.invEsp then construirLista() end

    -- ─── Bucle: arrastre + teclado ────────────────────────────────────────────
    task.spawn(function()
        local T_ARRIBA=38; local T_ABAJO=40; local T_ENTER=13; local T_BORRAR=8
        local pArriba,pAbajo,pEnter,pBorrar=false,false,false,false
        local objetoArrastre,offsetX,offsetY=nil,0,0
        local prevRaton1=false
        while true do
            local ok=pcall(function()
                task.wait(0.05)
                local Raton=LocalPlayer:GetMouse()
                local mx,my=Raton.X,Raton.Y; local raton1=ismouse1pressed()
                if raton1 and not prevRaton1 then
                    local ldy=INV.ly-DH; local lbx=INV.lx+LP.a; local lby=INV.ly+LP.h
                    local rbx=INV.rx+RP.a; local rby=INV.ry+DH+RP.h
                    if CFG.invEsp and CFG.mostrarLista and enRect(mx,my,lbx-ZONA_RESIZE,lby-ZONA_RESIZE,ZONA_RESIZE,ZONA_RESIZE) then objetoArrastre="lresize"
                    elseif pDerVisible and enRect(mx,my,rbx-ZONA_RESIZE,rby-ZONA_RESIZE,ZONA_RESIZE,ZONA_RESIZE) then objetoArrastre="rresize"
                    elseif enRect(mx,my,INV.lx,ldy,LP.a,DH) then objetoArrastre="lista"; offsetX=mx-INV.lx; offsetY=my-ldy
                    elseif pDerVisible and enRect(mx,my,INV.rx,INV.ry,RP.a,DH) then objetoArrastre="derecha"; offsetX=mx-INV.rx; offsetY=my-INV.ry end
                end
                if not raton1 then objetoArrastre=nil end
                if objetoArrastre and raton1 then
                    local vp=Camara.ViewportSize
                    if objetoArrastre=="lista" then
                        INV.lx=limitar(mx-offsetX,0,vp.X-LP.a); INV.ly=limitar((my-offsetY)+DH,DH,vp.Y-20)
                        aplicarPosList(INV.lx,INV.ly); construirLista()
                        if INV.seleccionado then
                            local rnx=INV.lx+LP.a+6; if rnx+RP.a>vp.X-4 then rnx=INV.lx-RP.a-6 end
                            INV.rx=rnx; INV.ry=INV.ly-DH
                            local rs=ReplicatedStorage:FindFirstChild("Players")
                            local pf=rs and rs:FindFirstChild(INV.seleccionado)
                            mostrarDerecha(INV.seleccionado,leerInventario(pf and pf:FindFirstChild("Inventory")))
                        end
                    elseif objetoArrastre=="derecha" then
                        INV.rx=limitar(mx-offsetX,0,vp.X-RP.a); INV.ry=limitar(my-offsetY,0,vp.Y-DH-20)
                        local rs=ReplicatedStorage:FindFirstChild("Players"); local nombre=INV.seleccionado or ultimoNombreMira
                        if nombre then local pf=rs and rs:FindFirstChild(nombre); local iv=pf and pf:FindFirstChild("Inventory"); if iv then mostrarDerecha(nombre,leerInventario(iv)) end end
                    elseif objetoArrastre=="lresize" then
                        LP.a=limitar(mx-INV.lx,80,400); lArrastrar.Size=Vector2.new(LP.a,DH); lBorde.Size=Vector2.new(LP.a,DH); construirLista()
                    elseif objetoArrastre=="rresize" then
                        RP.a=limitar(mx-INV.rx,80,500); RP.h=limitar(my-(INV.ry+DH),60,600)
                        local rs=ReplicatedStorage:FindFirstChild("Players"); local nombre=INV.seleccionado or ultimoNombreMira
                        if nombre then local pf=rs and rs:FindFirstChild(nombre); local iv=pf and pf:FindFirstChild("Inventory"); if iv then mostrarDerecha(nombre,leerInventario(iv)) end end
                        aplicarPosDerecha(INV.rx,INV.ry,RP.h)
                    end
                end
                prevRaton1=raton1
                local arriba=iskeypressed(T_ARRIBA); local abajo=iskeypressed(T_ABAJO)
                local enter=iskeypressed(T_ENTER); local borrar=iskeypressed(T_BORRAR)
                if CFG.invEsp and CFG.mostrarLista then
                    local n=#INV.jugadores
                    if arriba and not pArriba and n>0 then INV.cursor=INV.cursor>1 and INV.cursor-1 or n; INV.sucio=true end
                    if abajo and not pAbajo and n>0 then INV.cursor=INV.cursor<n and INV.cursor+1 or 1; INV.sucio=true end
                    if enter and not pEnter then abrirCursor() end
                    if borrar and not pBorrar then ocultarInv() end
                    if INV.sucio then construirLista() end
                end
                pArriba=arriba; pAbajo=abajo; pEnter=enter; pBorrar=borrar
            end)
            if not ok then task.wait(0.1) end
        end
    end)

    -- ─── Bucle: mira ──────────────────────────────────────────────────────────
    task.spawn(function()
        while true do
            task.wait(0.15)
            if not LocalPlayer then continue end
            if not CFG.invEsp or not CFG.miraOn or INV.seleccionado then
                if ultimoNombreMira and not INV.seleccionado then ocultarDerecha(); ultimoNombreMira=nil end
            else
                local rsCache=ReplicatedStorage:FindFirstChild("Players")
                local vp=Camara.ViewportSize; local cx,cy=vp.X*0.5,vp.Y*0.5
                local mejorJ,mejorD=nil,UMBRAL2
                for _,p in ipairs(Players:GetPlayers()) do
                    if p~=LocalPlayer and p.Character then
                        local raiz=p.Character:FindFirstChild("HumanoidRootPart")
                        if raiz then
                            local sp,en=WorldToScreen(raiz.Position)
                            if en then
                                local dx,dy=sp.X-cx,sp.Y-cy
                                local d2=dx*dx+dy*dy
                                if d2<mejorD then mejorD=d2; mejorJ=p end
                            end
                        end
                    end
                end
                if mejorJ then
                    ultimoNombreMira=mejorJ.Name
                    local pf=rsCache and rsCache:FindFirstChild(mejorJ.Name)
                    mostrarDerecha(mejorJ.Name,leerInventario(pf and pf:FindFirstChild("Inventory")))
                else
                    if ultimoNombreMira then ocultarDerecha(); ultimoNombreMira=nil end
                end
            end
        end
    end)

    -- ─── Bucle: escaneo de NPCs y cadaveres ───────────────────────────────────
    task.spawn(function()
        while true do
            task.wait(0.5)
            local activos={}

            local zonasIA=workspace:FindFirstChild("AiZones")
            if zonasIA then
                for _,zona in ipairs(zonasIA:GetChildren()) do
                    for _,npc in ipairs(zona:GetChildren()) do
                        local h=npc:FindFirstChildOfClass("Humanoid")
                        if h and h.Health>0 and not npc:FindFirstChild("RagdollConstraints") then
                            activos[npc]=true; local ranura=espObtener(npc,C_NPC)
                            ranura.texto=npc.Name; ranura.col=C_NPC; ranura.etiqueta.Color=C_NPC
                        end
                    end
                end
            end

            local nombresJugadores={}
            for _,p in ipairs(Players:GetPlayers()) do nombresJugadores[p.Name]=true end
            local tirados=workspace:FindFirstChild("DroppedItems")
            if tirados then
                for _,modelo in ipairs(tirados:GetChildren()) do
                    local h=modelo:FindFirstChildOfClass("Humanoid")
                    if h and h.Health==0 then
                        activos[modelo]=true
                        local esJugador=nombresJugadores[modelo.Name]
                        local col=esJugador and C_CORPSE or C_CORPSE_NPC
                        local ranura=espObtener(modelo,col)
                        ranura.texto=(esJugador and "[MUERTO] " or "[NPC] ")..modelo.Name
                        ranura.col=col; ranura.etiqueta.Color=col
                    end
                end
            end

            for modelo in pairs(ranuras) do
                if not activos[modelo] then espEliminar(modelo) end
            end
        end
    end)

    -- ─── Bucle: renderizado ESP ───────────────────────────────────────────────
    task.spawn(function()
        while true do
            task.wait(0.05)
            if not LocalPlayer then continue end
            local lc=LocalPlayer.Character
            local lr=lc and lc:FindFirstChild("HumanoidRootPart")
            for modelo,ranura in pairs(ranuras) do
                local raiz=ranura.raiz
                if not raiz or not raiz.Parent then
                    ranura.etiqueta.Visible=false
                else
                    local esJugador=ranura.col==C_PLAYER
                    local esCadaver=ranura.col==C_CORPSE or ranura.col==C_CORPSE_NPC
                    local mostrar=(esJugador and CFG.jugadorEsp) or (esCadaver and CFG.cuerpoEsp) or (not esJugador and not esCadaver and CFG.npcEsp)
                    if not mostrar then
                        ranura.etiqueta.Visible=false
                    else
                        local sp,en=WorldToScreen(raiz.Position)
                        if en then
                            local ocultar=false; local dist=""
                            if lr then
                                local d=raiz.Position-lr.Position
                                local m=math.floor(math.sqrt(d.X*d.X+d.Y*d.Y+d.Z*d.Z))
                                if m>300 then ocultar=true else dist=" "..m.."m" end
                            end
                            if ocultar then ranura.etiqueta.Visible=false
                            else
                                ranura.etiqueta.Text=ranura.texto..dist
                                ranura.etiqueta.Position=Vector2.new(sp.X,sp.Y-20)
                                ranura.etiqueta.Visible=true
                            end
                        else ranura.etiqueta.Visible=false end
                    end
                end
            end
        end
    end)

    -- ─── Bucle: contador de jugadores ────────────────────────────────────────
    task.spawn(function()
        while true do
            task.wait(0.1)
            if CFG.invEsp then
                local n=#Players:GetPlayers()
                if n~=INV.ultimoN then INV.ultimoN=n; construirLista() end
            end
        end
    end)

    notify("Project Delta listo  -  abre Matcha para configurar","PD v5.3",4)
end)
