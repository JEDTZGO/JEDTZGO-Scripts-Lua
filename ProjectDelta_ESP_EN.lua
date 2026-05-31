--[[
Project Delta - main.lua
Single-file build compatible with loadstring.

Migrated from archive/ProjectDelta_v5_legacy.lua.
Organized by MODULE sections without splitting the script into external files.
]]

-- =========================================================
-- MODULE: PROJECT HEADER
-- =========================================================

-- Project Delta v5.3 legacy organized for single-file main.lua.

-- =========================================================
-- MODULE: RUNTIME / SERVICES
-- =========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
-- =========================================================
-- MODULE: CONSTANTS
-- =========================================================

local C_ACCENT_DEFECTO=Color3.fromRGB(195,66,148); local C_TEXT=Color3.fromRGB(240,240,245)
local C_ACCENT=C_ACCENT_DEFECTO
local C_DIM=Color3.fromRGB(120,115,135);   local C_BG=Color3.fromRGB(28,26,34)
local C_DRAG=Color3.fromRGB(18,17,22);     local C_BORDER=Color3.fromRGB(55,50,65)
local C_PANEL_INNER=Color3.fromRGB(22,22,26); local C_STRIPE=Color3.fromRGB(70,70,78)
local C_CORPSE=Color3.fromRGB(180,180,180)
local C_CORPSE_NPC=Color3.fromRGB(120,120,120)
local MAP_C_ENEMIGO=Color3.fromRGB(220,50,50); local MAP_C_YO=Color3.fromRGB(255,220,0)

local FILTRO={
    Equipment=true,Keychain=true,Map=true,DAGR=true,Lighter=true,Radio=true,
    Pathfinder=true,['"Pathfinder"']=true,DV2=true,EstonianBorderMap=true,
    ["Village Key"]=true,["EVAC key"]=true,["EVAC Key"]=true,
    ["Airfield Key"]=true,["Garage Key"]=true,["Fueling Station Key"]=true,
    ["Lighthouse Key"]=true,["W. Shirt"]=true,["W. Pants"]=true,
}

-- =========================================================
-- MODULE: CONFIG
-- =========================================================

local CFG_DEFECTO={
    invEsp=true,mostrarLista=true,miraOn=true,cuerpoEsp=true,mapaOn=true,
    opacidadLista=0.85,opacidadDerecha=0.85,lx=10,ly=340,rx=0,ry=44,
    noRetroceso=false,noSpread=false,predictionAim=false,predictionAimTecla=106,predictionAimModo=0,
    accentR=195,accentG=66,accentB=148,panelStripes=true,
}
local CFG={}; for k,v in pairs(CFG_DEFECTO) do CFG[k]=v end

-- =========================================================
-- MODULE: CONFIG MANAGER
-- =========================================================

local function exportarCFG()
    local p={"PD"}
    for k,v in pairs(CFG) do
        if k~="noRetroceso" and k~="noSpread" and k~="predictionAim" then
            local t=type(v)
            if t=="boolean" then p[#p+1]=k..":"..(v and "1" or "0")
            elseif t=="number" then p[#p+1]=k..":"..string.format("%.4g",v) end
        end
    end
    return table.concat(p,"|")
end
local function importarCFG(raw)
    if type(raw)~="string" or raw:sub(1,3)~="PD|" then return false end
    local datos={}
    for par in raw:gmatch("[^|]+") do
        local k,v=par:match("^(%w+):(.+)$")
        if k and v and CFG_DEFECTO[k]~=nil and k~="noRetroceso" and k~="noSpread" and k~="predictionAim" then
            local dt=type(CFG_DEFECTO[k])
            if dt=="boolean" then datos[k]=(v=="1")
            elseif dt=="number" then local n=tonumber(v); if n then datos[k]=n end end
        end
    end
    for k,v in pairs(datos) do CFG[k]=v end
    CFG.noRetroceso=false; CFG.noSpread=false; CFG.predictionAim=false
    CFG.accentR=math.max(0,math.min(255,math.floor(CFG.accentR or CFG_DEFECTO.accentR)))
    CFG.accentG=math.max(0,math.min(255,math.floor(CFG.accentG or CFG_DEFECTO.accentG)))
    CFG.accentB=math.max(0,math.min(255,math.floor(CFG.accentB or CFG_DEFECTO.accentB)))
    CFG.opacidadLista=math.max(0,math.min(1,CFG.opacidadLista or CFG_DEFECTO.opacidadLista))
    CFG.opacidadDerecha=math.max(0,math.min(1,CFG.opacidadDerecha or CFG_DEFECTO.opacidadDerecha))
    return true
end
local function copiarPortapapeles(str) pcall(setclipboard,str) end

local CFG_ARCHIVO="ProjectDelta.cfg"
local function archivoConfigDisponible()
    return type(writefile)=="function" and type(readfile)=="function"
end
local function autoGuardarCFG()
    if not archivoConfigDisponible() then return false end
    return pcall(writefile,CFG_ARCHIVO,exportarCFG())
end
local function autoCargarCFG()
    if not archivoConfigDisponible() then return false end
    if type(isfile)=="function" then
        local ok,existe=pcall(isfile,CFG_ARCHIVO)
        if ok and not existe then return false end
    end
    local ok,raw=pcall(readfile,CFG_ARCHIVO)
    if ok and raw then return importarCFG(raw) end
    return false
end

-- =========================================================
-- MODULE: HELPERS
-- =========================================================

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
local function actualizarAccent()
    CFG.accentR=math.max(0,math.min(255,math.floor(CFG.accentR or CFG_DEFECTO.accentR)))
    CFG.accentG=math.max(0,math.min(255,math.floor(CFG.accentG or CFG_DEFECTO.accentG)))
    CFG.accentB=math.max(0,math.min(255,math.floor(CFG.accentB or CFG_DEFECTO.accentB)))
    C_ACCENT=Color3.fromRGB(CFG.accentR,CFG.accentG,CFG.accentB)
end
-- =========================================================
-- MODULE: DRAWING OBJECTS
-- =========================================================

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

-- =========================================================
-- MODULE: FEATURE / NO RECOIL
-- =========================================================
local NO_RETROCESO_BACKUP={}
local NO_RETROCESO_ACTIVO=false

local function encontrarOffsetValor(instancia, valorReal, tolerancia)
    tolerancia = tolerancia or 0.0001
    for offset = 0, 0x300, 4 do
        local ok, comoDouble = pcall(memory_read, "double", instancia.Address + offset)
        if ok and math.abs(comoDouble - valorReal) < tolerancia then return offset, "double" end
        local ok2, comoFloat = pcall(memory_read, "float", instancia.Address + offset)
        if ok2 and math.abs(comoFloat - valorReal) < tolerancia then return offset, "float" end
    end
    return nil, nil
end

local function detectarOffset(rutaArma)
    local carpetas = {"RecoilPattern", "RecoilPattern2", "RecoilPatternDisabled", "RecoilPattern3", "RecoilPatternOLD"}
    for _, nombreCarpeta in ipairs(carpetas) do
        local carpeta = rutaArma:FindFirstChild(nombreCarpeta)
        if carpeta then
            for _, hijo in ipairs(carpeta:GetChildren()) do
                if hijo.ClassName == "BoolValue" then
                    for _, interno in ipairs(hijo:GetChildren()) do
                        if interno.ClassName == "NumberValue" and interno.Value ~= 0 then
                            local offset, tipo = encontrarOffsetValor(interno, interno.Value)
                            if offset then return offset, tipo end
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

local function aplicarNoRetroceso(rutaArma)
    local offsetDetectado, tipoDetectado = detectarOffset(rutaArma)
    if not offsetDetectado then return end
    local carpetas = {"RecoilPattern", "RecoilPattern2", "RecoilPatternDisabled", "RecoilPattern3", "RecoilPatternOLD"}
    for _, nombreCarpeta in ipairs(carpetas) do
        local carpeta = rutaArma:FindFirstChild(nombreCarpeta)
        if carpeta then
            for _, hijo in ipairs(carpeta:GetChildren()) do
                if hijo.ClassName == "BoolValue" then
                    for _, interno in ipairs(hijo:GetChildren()) do
                        if interno.ClassName == "NumberValue" then
                            local direccion=interno.Address + offsetDetectado
                            local clave=tipoDetectado..":"..tostring(direccion)
                            if not NO_RETROCESO_BACKUP[clave] then
                                local okOriginal,valorOriginal=pcall(memory_read,tipoDetectado,direccion)
                                if okOriginal then
                                    NO_RETROCESO_BACKUP[clave]={tipo=tipoDetectado,direccion=direccion,valor=valorOriginal}
                                end
                            end
                            pcall(memory_write, tipoDetectado, direccion, 0)
                        end
                    end
                end
            end
        end
    end
end

local function activarNoRetroceso()
    local armas = ReplicatedStorage:FindFirstChild("RangedWeapons")
    if not armas then return end
    for _, arma in ipairs(armas:GetChildren()) do
        pcall(aplicarNoRetroceso, arma)
    end
    NO_RETROCESO_ACTIVO=true
end

local function desactivarNoRetroceso()
    local restaurados=0
    local fallidos=0
    for _,dato in pairs(NO_RETROCESO_BACKUP) do
        local ok=pcall(memory_write,dato.tipo,dato.direccion,dato.valor)
        if ok then restaurados=restaurados+1 else fallidos=fallidos+1 end
    end
    NO_RETROCESO_ACTIVO=false
    return restaurados,fallidos
end

-- =========================================================
-- MODULE: FEATURE / NO SPREAD
-- =========================================================
local NO_SPREAD_MUZZLE=nil
local NO_SPREAD_CFRAME=nil
local NO_SPREAD_ARMA=nil
local NO_SPREAD_ULTIMA_BUSQUEDA=0

local function rangedWeapons()
    return ReplicatedStorage:FindFirstChild("RangedWeapons")
end
local function armaExiste(nombre)
    local rw=rangedWeapons()
    return nombre and rw and rw:FindFirstChild(nombre)~=nil
end
local function nombreDesdeValor(valor)
    if not valor then return nil end
    local okNombre,nombre=pcall(function() return valor.Name end)
    if okNombre and armaExiste(nombre) then return nombre end
    local okValor,interno=pcall(function() return valor.Value end)
    if okValor and interno then
        local okInterno,nombreInterno=pcall(function() return interno.Name end)
        if okInterno and armaExiste(nombreInterno) then return nombreInterno end
        if armaExiste(interno) then return interno end
    end
    return nil
end
local function armaEquipada()
    if not LocalPlayer or not LocalPlayer.Character then return nil end
    local holding=LocalPlayer.Character:FindFirstChild("Holding")
    local okHolding,equipada=pcall(function() return holding and holding.Value end)
    local desdeHolding=okHolding and nombreDesdeValor(equipada)
    if desdeHolding then return desdeHolding end

    local playersFolder=ReplicatedStorage:FindFirstChild("Players")
    local playerData=playersFolder and playersFolder:FindFirstChild(LocalPlayer.Name)
    local status=playerData and playerData:FindFirstChild("Status")
    local gameplay=status and status:FindFirstChild("GameplayVariables")
    local equippedTool=gameplay and gameplay:FindFirstChild("EquippedTool")
    local okEquipped,statusEquipped=pcall(function() return equippedTool and equippedTool.Value end)
    local desdeStatus=okEquipped and nombreDesdeValor(statusEquipped)
    if desdeStatus then return desdeStatus end

    local rw=rangedWeapons()
    if rw then
        for _,child in ipairs(LocalPlayer.Character:GetChildren()) do
            if rw:FindFirstChild(child.Name) and child:FindFirstChild("AttachmentPoints") then
                return child.Name
            end
        end
    end
    return nil
end
local function buscarDescendientePorNombre(root,nombre,limite)
    if not root then return nil end
    local cola={root}; local i=1; local revisados=0
    while cola[i] and revisados<(limite or 260) do
        local obj=cola[i]; i=i+1; revisados=revisados+1
        if obj.Name==nombre then return obj end
        local ok,hijos=pcall(function() return obj:GetChildren() end)
        if ok and hijos then
            for _,h in ipairs(hijos) do cola[#cola+1]=h end
        end
    end
    return nil
end
local function muzzleEnRaiz(root,arma)
    if not root then return nil,false end
    local attachments=root:FindFirstChild("Attachments")
    local front=attachments and attachments:FindFirstChild("Front")
    local real=front and front:FindFirstChild("MuzzleOffset")
    if real then return real,true end
    local encontrado=buscarDescendientePorNombre(root,"MuzzleOffset",260)
    if encontrado then return encontrado,true end
    local attachmentPoints=root:FindFirstChild("AttachmentPoints")
    local ap=attachmentPoints and (attachmentPoints:FindFirstChild("Muzzle") or attachmentPoints:FindFirstChild("Front"))
    if ap then return ap,false end
    if arma then
        local armaRoot=root:FindFirstChild(arma)
        if armaRoot then return muzzleEnRaiz(armaRoot,nil) end
    end
    return nil,false
end
local function recapturarNoSpread(forzar)
    local ahora=os.clock()
    if not forzar and NO_SPREAD_MUZZLE and NO_SPREAD_MUZZLE.Parent and ahora-NO_SPREAD_ULTIMA_BUSQUEDA<0.25 then
        return NO_SPREAD_MUZZLE
    end
    NO_SPREAD_ULTIMA_BUSQUEDA=ahora
    local arma=armaEquipada()
    if arma~=NO_SPREAD_ARMA then
        NO_SPREAD_MUZZLE=nil; NO_SPREAD_CFRAME=nil; NO_SPREAD_ARMA=arma
    end
    local cam=workspace.CurrentCamera
    local viewModel=cam and cam:FindFirstChild("ViewModel")
    local item=viewModel and viewModel:FindFirstChild("Item")
    local muzzle,real=muzzleEnRaiz(item,arma)
    if not muzzle then muzzle,real=muzzleEnRaiz(viewModel,arma) end
    if not muzzle and cam then muzzle,real=muzzleEnRaiz(cam:FindFirstChild(LocalPlayer.Name),arma) end
    if not muzzle and LocalPlayer.Character then
        muzzle,real=muzzleEnRaiz(arma and LocalPlayer.Character:FindFirstChild(arma),arma)
    end
    if not muzzle and LocalPlayer.Character then muzzle,real=muzzleEnRaiz(LocalPlayer.Character,arma) end
    NO_SPREAD_MUZZLE=muzzle
    if muzzle and real then
        local ok,cf=pcall(function() return muzzle.CFrame end)
        if ok and cf and (not NO_SPREAD_CFRAME or forzar) then NO_SPREAD_CFRAME=cf end
    else
        NO_SPREAD_CFRAME=nil
    end
    return NO_SPREAD_MUZZLE
end
local function aplicarNoSpread()
    if not CFG.noSpread then return end
    local muzzle=recapturarNoSpread(false)
    if muzzle and NO_SPREAD_CFRAME then pcall(function() muzzle.CFrame=NO_SPREAD_CFRAME end) end
end
local function desactivarNoSpread()
    NO_SPREAD_MUZZLE=nil; NO_SPREAD_CFRAME=nil; NO_SPREAD_ARMA=nil
end

-- =========================================================
-- MODULE: FEATURE / PREDICTIVE AIM BETA
-- =========================================================
local PRED_KEY_TOGGLE=false
local PRED_KEY_ANTERIOR=false
local PRED_ULTIMO_ENVIO=0
local PRED_ULTIMO_OBJETIVO=nil
local PRED_ULTIMA_POS=nil
local PRED_ULTIMO_TIEMPO=0
local PRED_VELOCIDAD=Vector3.new(0,0,0)

local PRED_SPEEDS_MPS={
    SVD=940,R700=992,Mosin=885,SKS=715,FAL=900,M4=933,M4A1=933,ADAR=933,ADAR15=933,
    MK23=465,MP5SD=465,MP443=465,PKM=940,AsVal=424,["AS Val"]=424,TFZ98S=1015,
    RPG7=200,["RPG-7"]=200,Saiga=425,IZh81=425,["IZh-81"]=425,IZh12=425,["IZh-12"]=425,
    TFZ0=404,["TFZ-0"]=404,TT33=460,["TT-33"]=460,PPSH41=460,["PPSH-41"]=460,
    Makarov=359,PM=359,["Golden (KGB) Pistol Makarov"]=359,TOZ106=425,["TOZ-106"]=425,
    VZ61=359,Vz61=359,vz61=359,["vz. 61"]=359,["Skorpion vz. 61"]=359,["Škorpion vz. 61"]=359,
}
local function velocidadArmaMps(nombre)
    return PRED_SPEEDS_MPS[nombre] or 900
end
local function parteObjetivo(char)
    if not char then return nil end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
end
local function parteLocal()
    local char=LocalPlayer and LocalPlayer.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))
end
local function calcularVelocidadObjetivo(nombre,parte)
    local ahora=os.clock()
    if PRED_ULTIMO_OBJETIVO~=nombre then
        PRED_ULTIMO_OBJETIVO=nombre; PRED_ULTIMA_POS=parte.Position; PRED_ULTIMO_TIEMPO=ahora
        PRED_VELOCIDAD=Vector3.new(0,0,0)
        return PRED_VELOCIDAD
    end
    local dt=ahora-PRED_ULTIMO_TIEMPO
    if dt>=0.025 and PRED_ULTIMA_POS then
        local delta=parte.Position-PRED_ULTIMA_POS
        local nueva=Vector3.new(delta.X/dt,0,delta.Z/dt)
        PRED_VELOCIDAD=Vector3.new(PRED_VELOCIDAD.X*0.45+nueva.X*0.55,0,PRED_VELOCIDAD.Z*0.45+nueva.Z*0.55)
        PRED_ULTIMA_POS=parte.Position; PRED_ULTIMO_TIEMPO=ahora
    end
    return PRED_VELOCIDAD
end
local function mejorObjetivoPrediction()
    local cam=workspace.CurrentCamera
    local vp=cam and cam.ViewportSize
    if not vp then return nil,nil end
    local cx,cy=vp.X*0.5,vp.Y*0.5
    local mejor,mejorParte,mejorD=nil,nil,335*335
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local parte=parteObjetivo(p.Character)
            if parte then
                local sp,en=WorldToScreen(parte.Position)
                if en then
                    local dx,dy=sp.X-cx,sp.Y-cy
                    local d=dx*dx+dy*dy
                    if d<mejorD then mejor=p; mejorParte=parte; mejorD=d end
                end
            end
        end
    end
    return mejor,mejorParte
end
local function predictionActivoPorTecla()
    if not CFG.predictionAim then return false end
    local modo=CFG.predictionAimModo or 0
    if modo==2 then return true end
    local tecla=CFG.predictionAimTecla or 106
    local presionada=iskeypressed(tecla)
    if modo==1 then return presionada end
    if presionada and not PRED_KEY_ANTERIOR then PRED_KEY_TOGGLE=not PRED_KEY_TOGGLE end
    PRED_KEY_ANTERIOR=presionada
    return PRED_KEY_TOGGLE
end
local function ejecutarPredictionAim()
    if not predictionActivoPorTecla() then return end
    if type(mousemoverel)~="function" then return end
    local ahora=os.clock()
    if ahora-PRED_ULTIMO_ENVIO<0.012 then return end
    local objetivo,parte=mejorObjetivoPrediction()
    if not objetivo or not parte then return end
    local muzzle=recapturarNoSpread(false)
    local origen=(muzzle and muzzle.Position) or (parteLocal() and parteLocal().Position)
    if not origen then return end
    local arma=armaEquipada()
    local studsPorSegundo=velocidadArmaMps(arma)/0.28
    local distanciaVec=parte.Position-origen
    local distancia=math.sqrt(distanciaVec.X*distanciaVec.X+distanciaVec.Y*distanciaVec.Y+distanciaVec.Z*distanciaVec.Z)
    local tiempo=distancia/studsPorSegundo
    local vel=calcularVelocidadObjetivo(objetivo.Name,parte)
    local dropStuds=(9.81/(0.28))*tiempo*tiempo*0.5
    local pred=parte.Position+Vector3.new(vel.X*tiempo,dropStuds,vel.Z*tiempo)
    local cam=workspace.CurrentCamera
    local vp=cam and cam.ViewportSize
    if not vp then return end
    local sp,en=WorldToScreen(pred)
    if not en then return end
    local dx=(sp.X-vp.X*0.5)*0.24
    local dy=(sp.Y-vp.Y*0.5)*0.24
    dx=limitar(dx,-30,30); dy=limitar(dy,-30,30)
    if math.abs(dx)<1.25 then dx=0 end
    if math.abs(dy)<1.25 then dy=0 end
    if dx~=0 or dy~=0 then
        pcall(mousemoverel,dx,dy)
        PRED_ULTIMO_ENVIO=ahora
    end
end

-- =========================================================
-- MODULE: FEATURE / MAP ESP
-- =========================================================
local MAP_SX=0.133647; local MAP_SY=0.133905
local MAP_OX=933.08;   local MAP_OY=556.44
local mapaPuntos={}; local mapaUltPos={}; local mapaUltChar={}
local MAP_C_EXIT=Color3.fromRGB(0,255,128)
local mapaExits={}

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
    for _,s in pairs(mapaExits) do s.punto.Visible=false; s.etiqueta.Visible=false end
end

local function mapaCargarExits()
    -- Clear previous exits
    for _,s in pairs(mapaExits) do
        pcall(function() s.punto:Remove() end)
        pcall(function() s.etiqueta:Remove() end)
    end
    mapaExits={}
    local nc=workspace:FindFirstChild("NoCollision")
    if not nc then return end
    local folder=nc:FindFirstChild("ExitLocations")
    if not folder then return end
    for _,part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") then
            local punto=Drawing.new("Circle")
            punto.Radius=6; punto.Filled=true; punto.Color=MAP_C_EXIT
            punto.Transparency=1; punto.NumSides=12; punto.Visible=false

            local etiqueta=Drawing.new("Text")
            etiqueta.Color=MAP_C_EXIT; etiqueta.Size=10; etiqueta.Outline=true
            etiqueta.Center=true; etiqueta.Font=Drawing.Fonts.SystemBold; etiqueta.Visible=false

            local px,py=MAP_OX+part.Position.X*MAP_SX, MAP_OY+part.Position.Z*MAP_SY
            punto.Position=Vector2.new(px,py)
            etiqueta.Text="[EXIT]"
            etiqueta.Position=Vector2.new(px,py-12)

            table.insert(mapaExits,{punto=punto,etiqueta=etiqueta})
        end
    end
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
            -- Reload exits whenever the map opens
            if not estabaAbierto then pcall(mapaCargarExits) end
            for _,s in pairs(mapaExits) do
                s.punto.Visible=true; s.etiqueta.Visible=true
            end
            local actual={}
            for _,p in ipairs(Players:GetPlayers()) do actual[p.Name]=p end
            for nombre in pairs(mapaPuntos) do
                if not actual[nombre] then mapaEliminar(nombre) end
            end
            for nombre,p in pairs(actual) do
                if not LocalPlayer then break end
                local esYo=(nombre==LocalPlayer.Name)
                local col=esYo and C_ACCENT or MAP_C_ENEMIGO
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
                    s.etiqueta.Text=esYo and "[ you ]" or nombre
                    s.etiqueta.Position=Vector2.new(px,py-12); s.etiqueta.Visible=true
                elseif mapaPuntos[nombre] then
                    mapaPuntos[nombre].punto.Visible=false; mapaPuntos[nombre].etiqueta.Visible=false
                end
            end
        end
        estabaAbierto=abierto
    end
end)

-- =========================================================
-- MODULE: BOOTSTRAP / MATCHA WAIT
-- =========================================================
notify("Project Delta loading in 10s...","PD v5.3",4)
task.spawn(function()
    task.wait(10)
    if not esperarUI(20) then notify("Matcha not found","PD v5.3",5); return end
    autoCargarCFG()
    CFG.noRetroceso=false; CFG.noSpread=false; CFG.predictionAim=false
    actualizarAccent()
    pcall(mapaCargarExits)

    local Camara=workspace.CurrentCamera
    local DH=14; local MARG=8; local ZONA_RESIZE=12
    local LP={a=185,h=200}; local RP={a=215,h=300}
    local INV={cursor=1,seleccionado=nil,jugadores={},ultimoN=0,sucio=false,lx=CFG.lx,ly=CFG.ly,rx=CFG.rx,ry=CFG.ry}
    local MAX_J=20; local MAX_I=15
    local ultimoNombreMira=nil; local UMBRAL2=350*350; local pDerVisible=false
    local miraRx=0; local miraRy=CFG.ry
    local predictionKeybind=nil

    -- =========================================================
    -- MODULE: FEATURE / INVENTORY PANELS
    -- =========================================================
    local lArrastrar=mkSq(0,0,LP.a,DH,C_DRAG,7,1,3); local lBorde=mkSqO(0,0,LP.a,DH,C_BORDER,7,3)
    local lEtiq=mkTx(0,0,"PLAYERS",C_ACCENT,11,8); local lFondo=mkSq(0,0,LP.a,20,C_PANEL_INNER,8,1,3)
    local lContorno=mkSqO(0,0,LP.a,20,C_BORDER,8,3); local lSep=mkLn(0,0,0,0,C_BORDER,0.3,9)
    local lResizeA=mkLn(0,0,0,0,C_ACCENT,0.3,10); local lResizeB=mkLn(0,0,0,0,C_ACCENT,0.3,10)
    local filasJ={}; for i=1,MAX_J do filasJ[i]=mkTx(0,0,"",C_DIM,12,10) end
    local rFondo=mkSq(0,0,RP.a,20,C_PANEL_INNER,8,1,3); local rContorno=mkSqO(0,0,RP.a,20,C_BORDER,8,3)
    local rArrastrar=mkSq(0,0,RP.a,DH,C_DRAG,9,1,3); local rBorde=mkSqO(0,0,RP.a,DH,C_BORDER,9,3)
    local rEtiq=mkTx(0,0,"INVENTORY",C_DIM,11,10); local rTitulo=mkTx(0,0,"",C_ACCENT,12,10)
    local rSep=mkLn(0,0,0,0,C_BORDER,0.3,10); local rResizeA=mkLn(0,0,0,0,C_ACCENT,0.3,11)
    local rResizeB=mkLn(0,0,0,0,C_ACCENT,0.3,11)
    local filasI={}; for i=1,MAX_I do filasI[i]=mkTx(0,0,"",C_TEXT,12,11) end
    local rVacio=mkTx(0,0,"  (empty)",C_DIM,12,11); local rMas=mkTx(0,0,"",C_DIM,12,11)
    local MAX_RAYAS_PANEL=10
    local lRayas={}; for i=1,MAX_RAYAS_PANEL do lRayas[i]=mkLn(0,0,0,0,C_STRIPE,0.12,9) end
    local rRayas={}; for i=1,MAX_RAYAS_PANEL do rRayas[i]=mkLn(0,0,0,0,C_STRIPE,0.12,10) end

    local function guardarCFGActual()
        CFG.lx=INV.lx; CFG.ly=INV.ly; CFG.rx=INV.rx; CFG.ry=INV.ry
        autoGuardarCFG()
    end
    local function aplicarRayas(rayitas,x,y,w,h,visible)
        local mostrar=visible and CFG.panelStripes
        local ancho=math.max(1,w-(MARG*2))
        local paso=math.max(18,math.floor(ancho/#rayitas))
        for i,linea in ipairs(rayitas) do
            if mostrar then
                local inicio=x+MARG+(((i-1)*paso)%ancho)
                local largo=math.min(30,(x+w-MARG)-inicio)
                if largo<8 then inicio=x+MARG; largo=math.min(30,ancho) end
                local y1=y+h-MARG
                local y2=math.max(y+MARG,y1-largo)
                linea.From=Vector2.new(inicio,y1)
                linea.To=Vector2.new(inicio+largo,y2)
                linea.Visible=true
            else
                linea.Visible=false
            end
        end
    end
    local function aplicarAccentVisual()
        actualizarAccent()
        lEtiq.Color=C_ACCENT; rTitulo.Color=C_ACCENT
        lResizeA.Color=C_ACCENT; lResizeB.Color=C_ACCENT
        rResizeA.Color=C_ACCENT; rResizeB.Color=C_ACCENT
        for i=1,MAX_J do
            if i==INV.cursor then filasJ[i].Color=C_ACCENT end
        end
    end
    local function aplicarOpacidadLista() local tr=1-CFG.opacidadLista; lFondo.Transparency=tr; lArrastrar.Transparency=tr end
    local function aplicarOpacidadDerecha() local tr=1-CFG.opacidadDerecha; rFondo.Transparency=tr; rArrastrar.Transparency=tr end
    local function aplicarPosList(x,y)
        lArrastrar.Position=Vector2.new(x,y-DH); lArrastrar.Size=Vector2.new(LP.a,DH)
        lBorde.Position=Vector2.new(x,y-DH); lBorde.Size=Vector2.new(LP.a,DH)
        lEtiq.Position=Vector2.new(x+MARG,y-DH+2)
        lFondo.Position=Vector2.new(x,y); lContorno.Position=Vector2.new(x,y)
        lSep.From=Vector2.new(x+MARG,y+18); lSep.To=Vector2.new(x+LP.a-MARG,y+18)
        aplicarRayas(lRayas,x,y,LP.a,LP.h,CFG.invEsp and CFG.mostrarLista)
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
        aplicarRayas(rRayas,x,by,RP.a,h,pDerVisible)
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
        aplicarRayas(lRayas,0,0,1,1,false)
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
        aplicarRayas(rRayas,0,0,1,1,false)
        for i=1,MAX_I do sv(filasI[i],false) end; pDerVisible=false
    end
    local function mostrarDerecha(titulo,items)
        local x,y=INV.rx,INV.ry; local fs=tamanoFuente(RP.a); local altFila=fs+6
        local n=#items; local vis=math.min(n,MAX_I); local ext=math.max(n-MAX_I,0)
        local H=26+math.max(vis,1)*altFila+MARG+(ext>0 and altFila or 0)+MARG
        RP.h=H; aplicarPosDerecha(x,y,H); rTitulo.Text=string.upper(tostring(titulo))
        sv(rArrastrar,true); sv(rBorde,true); sv(rEtiq,true)
        sv(rFondo,true); sv(rContorno,true); sv(rTitulo,true)
        sv(rSep,true); sv(rResizeA,true); sv(rResizeB,true)
        aplicarRayas(rRayas,x,y+DH,RP.a,H,true)
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

    -- =========================================================
    -- MODULE: FEATURE / WORLD ESP
    -- =========================================================
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

    -- =========================================================
    -- MODULE: MATCHA UI
    -- =========================================================
    UI.AddTab("Project Delta",function(tab)
        local secInv=tab:Section("Inv ESP","Left")
        secInv:Toggle("invEsp","Inv ESP",CFG.invEsp,function(estado)
            CFG.invEsp=estado
            if estado then construirLista() else ocultarLista(); ocultarDerecha(); INV.seleccionado=nil end
            guardarCFGActual()
        end)
        secInv:Toggle("mostrarLista","Player list",CFG.mostrarLista,function(estado)
            CFG.mostrarLista=estado
            if CFG.invEsp then if estado then construirLista() else ocultarLista(); ocultarInv() end end
            guardarCFGActual()
        end)
        secInv:Toggle("miraOn","Aim panel",CFG.miraOn,function(estado)
            CFG.miraOn=estado; if not estado and not INV.seleccionado then ocultarDerecha() end
            guardarCFGActual()
        end)

        local secMundo=tab:Section("World ESP","Left")
        secMundo:Toggle("cuerpoEsp","Corpse ESP",CFG.cuerpoEsp,function(estado) CFG.cuerpoEsp=estado; guardarCFGActual() end)
        secMundo:Toggle("mapaOn","Map ESP",CFG.mapaOn,function(estado)
            CFG.mapaOn=estado; if not estado then mapaOcultar() end
            guardarCFGActual()
        end)

        local secCombate=tab:Section("Combat","Left")
        secCombate:Toggle("noRetroceso","No recoil",CFG.noRetroceso,function(estado)
            CFG.noRetroceso=estado
            if estado then
                pcall(activarNoRetroceso)
                notify("No recoil enabled","Project Delta",3)
            else
                local restaurados,fallidos=desactivarNoRetroceso()
                if restaurados>0 and fallidos==0 then
                    notify("No recoil restored in this session","Project Delta",3)
                elseif restaurados>0 then
                    notify("Partial restore; restart the match/script if recoil feels odd","Project Delta",4)
                else
                    notify("No complete safe restore available; restart the match/script if it was already applied","Project Delta",4)
                end
            end
            guardarCFGActual()
        end)
        secCombate:Toggle("noSpread","No spread",CFG.noSpread,function(estado)
            CFG.noSpread=estado
            if estado then
                recapturarNoSpread(true)
                notify("No spread enabled","Project Delta",3)
            else
                desactivarNoSpread()
                notify("No spread disabled","Project Delta",3)
            end
            guardarCFGActual()
        end)
        secCombate:Spacing()
        secCombate:Toggle("predictionAim","Predictive aim BETA",CFG.predictionAim,function(estado)
            CFG.predictionAim=estado
            PRED_KEY_TOGGLE=false
            notify(estado and "Predictive aim BETA enabled" or "Predictive aim BETA disabled","Project Delta",3)
            guardarCFGActual()
        end)
        local predictionTipoInicial=(CFG.predictionAimModo==1 and "hold") or (CFG.predictionAimModo==2 and "always") or "toggle"
        predictionKeybind=secCombate:Keybind("predictionAimTecla",CFG.predictionAimTecla or 106,predictionTipoInicial)
        secCombate:Combo("predictionAimModo","Key mode",{"Toggle","Hold","Always"},CFG.predictionAimModo or 0,function(indice)
            CFG.predictionAimModo=indice or 0
            if predictionKeybind then
                local tipo=(CFG.predictionAimModo==1 and "hold") or (CFG.predictionAimModo==2 and "always") or "toggle"
                pcall(function() predictionKeybind:SetType(tipo) end)
            end
            PRED_KEY_TOGGLE=false
            guardarCFGActual()
        end)
      
        local secOpac=tab:Section("Opacity","Right")
        secOpac:SliderFloat("opacidadLista","List panel",0.0,1.0,CFG.opacidadLista,"%.2f",function(val)
            CFG.opacidadLista=val; lFondo.Transparency=1-val; lArrastrar.Transparency=1-val
            guardarCFGActual()
        end)
        secOpac:SliderFloat("opacidadDerecha","Inv / Aim panel",0.0,1.0,CFG.opacidadDerecha,"%.2f",function(val)
            CFG.opacidadDerecha=val; rFondo.Transparency=1-val; rArrastrar.Transparency=1-val
            guardarCFGActual()
        end)

        local secTema=tab:Section("Theme","Right")
        local function cambiarAccent(r,g,b)
            CFG.accentR=r or CFG.accentR; CFG.accentG=g or CFG.accentG; CFG.accentB=b or CFG.accentB
            aplicarAccentVisual()
            guardarCFGActual()
        end
        local function aplicarColorPicker(col)
            if not col then return end
            local ok,r,g,b=pcall(function()
                return col.R or col.r or CFG.accentR, col.G or col.g or CFG.accentG, col.B or col.b or CFG.accentB
            end)
            if not ok then return end
            if r<=1 and g<=1 and b<=1 then r=r*255; g=g*255; b=b*255 end
            cambiarAccent(r,g,b)
        end
        if type(secTema.ColorPicker)=="function" then
            pcall(function()
                secTema:ColorPicker("accentColor","Accent color",C_ACCENT,function(col)
                    aplicarColorPicker(col)
                end)
            end)
        end
        secTema:SliderInt("accentR","Accent R",0,255,CFG.accentR,function(val) cambiarAccent(val,nil,nil) end)
        secTema:SliderInt("accentG","Accent G",0,255,CFG.accentG,function(val) cambiarAccent(nil,val,nil) end)
        secTema:SliderInt("accentB","Accent B",0,255,CFG.accentB,function(val) cambiarAccent(nil,nil,val) end)
        secTema:Toggle("panelStripes","Panel stripes",CFG.panelStripes,function(estado)
            CFG.panelStripes=estado
            aplicarRayas(lRayas,INV.lx,INV.ly,LP.a,LP.h,CFG.invEsp and CFG.mostrarLista)
            aplicarRayas(rRayas,INV.rx,INV.ry+DH,RP.a,RP.h,pDerVisible)
            guardarCFGActual()
        end)

        local secGuardar=tab:Section("Config","Right")
        secGuardar:Text("Export copies your config to the clipboard.")
        secGuardar:Text("Paste it in the import field to restore it.")
        secGuardar:Spacing()
        secGuardar:Button("Export config",function()
            CFG.lx=INV.lx; CFG.ly=INV.ly; CFG.rx=INV.rx; CFG.ry=INV.ry
            autoGuardarCFG()
            copiarPortapapeles(exportarCFG()); notify("Config copied!","Project Delta",3)
        end)
        secGuardar:Spacing()
        secGuardar:InputText("cfgImportar","Paste config here","",function(texto)
            if importarCFG(texto) then
                CFG.noRetroceso=false; CFG.noSpread=false; CFG.predictionAim=false
                UI.SetValue("invEsp",CFG.invEsp); UI.SetValue("mostrarLista",CFG.mostrarLista)
                UI.SetValue("miraOn",CFG.miraOn); UI.SetValue("cuerpoEsp",CFG.cuerpoEsp)
                UI.SetValue("mapaOn",CFG.mapaOn); UI.SetValue("noRetroceso",CFG.noRetroceso)
                UI.SetValue("noSpread",CFG.noSpread); UI.SetValue("predictionAim",CFG.predictionAim)
                UI.SetValue("predictionAimModo",CFG.predictionAimModo)
                UI.SetValue("opacidadLista",CFG.opacidadLista); UI.SetValue("opacidadDerecha",CFG.opacidadDerecha)
                UI.SetValue("accentR",CFG.accentR); UI.SetValue("accentG",CFG.accentG); UI.SetValue("accentB",CFG.accentB)
                UI.SetValue("panelStripes",CFG.panelStripes)
                lFondo.Transparency=1-CFG.opacidadLista; lArrastrar.Transparency=1-CFG.opacidadLista
                rFondo.Transparency=1-CFG.opacidadDerecha; rArrastrar.Transparency=1-CFG.opacidadDerecha
                INV.lx=CFG.lx; INV.ly=CFG.ly; INV.rx=CFG.rx; INV.ry=CFG.ry
                aplicarPosList(INV.lx,INV.ly)
                aplicarAccentVisual()
                if CFG.invEsp then construirLista() else ocultarLista(); ocultarDerecha(); INV.seleccionado=nil end
                pcall(desactivarNoRetroceso); pcall(desactivarNoSpread)
                guardarCFGActual()
                UI.SetValue("cfgImportar",""); notify("Config loaded!","Project Delta",3)
            else notify("Invalid string.","Project Delta",3) end
        end)
        secGuardar:Spacing()

        local secMisc=tab:Section("Misc","Right")
        secMisc:Button("Reset to defaults",function()
            for k,v in pairs(CFG_DEFECTO) do CFG[k]=v end
            UI.SetValue("invEsp",CFG.invEsp); UI.SetValue("mostrarLista",CFG.mostrarLista)
            UI.SetValue("miraOn",CFG.miraOn); UI.SetValue("cuerpoEsp",CFG.cuerpoEsp)
            UI.SetValue("mapaOn",CFG.mapaOn); UI.SetValue("noRetroceso",CFG.noRetroceso)
            UI.SetValue("noSpread",CFG.noSpread); UI.SetValue("predictionAim",CFG.predictionAim)
            UI.SetValue("predictionAimModo",CFG.predictionAimModo)
            UI.SetValue("opacidadLista",CFG.opacidadLista); UI.SetValue("opacidadDerecha",CFG.opacidadDerecha)
            UI.SetValue("accentR",CFG.accentR); UI.SetValue("accentG",CFG.accentG); UI.SetValue("accentB",CFG.accentB)
            UI.SetValue("panelStripes",CFG.panelStripes)
            INV.lx=CFG.lx; INV.ly=CFG.ly; INV.rx=CFG.rx; INV.ry=CFG.ry
            lFondo.Transparency=1-CFG.opacidadLista; lArrastrar.Transparency=1-CFG.opacidadLista
            rFondo.Transparency=1-CFG.opacidadDerecha; rArrastrar.Transparency=1-CFG.opacidadDerecha
            aplicarAccentVisual()
            if not CFG.noRetroceso then pcall(desactivarNoRetroceso) end
            if not CFG.noSpread then pcall(desactivarNoSpread) end
            guardarCFGActual()
            ocultarLista(); ocultarDerecha(); INV.seleccionado=nil; construirLista()
        end)
    end)

    -- =========================================================
    -- MODULE: BOOTSTRAP / INIT
    -- =========================================================
    INV.rx=Camara.ViewportSize.X-RP.a-10
    miraRx=INV.rx; miraRy=INV.ry
    aplicarPosList(INV.lx,INV.ly); aplicarOpacidadDerecha()
    pcall(function()
        UI.SetValue("invEsp",CFG.invEsp); UI.SetValue("mostrarLista",CFG.mostrarLista)
        UI.SetValue("miraOn",CFG.miraOn); UI.SetValue("cuerpoEsp",CFG.cuerpoEsp)
        UI.SetValue("mapaOn",CFG.mapaOn); UI.SetValue("noRetroceso",CFG.noRetroceso)
        UI.SetValue("noSpread",CFG.noSpread); UI.SetValue("predictionAim",CFG.predictionAim)
        UI.SetValue("predictionAimModo",CFG.predictionAimModo)
        UI.SetValue("opacidadLista",CFG.opacidadLista); UI.SetValue("opacidadDerecha",CFG.opacidadDerecha)
        UI.SetValue("accentR",CFG.accentR); UI.SetValue("accentG",CFG.accentG); UI.SetValue("accentB",CFG.accentB)
        UI.SetValue("panelStripes",CFG.panelStripes)
    end)
    if CFG.invEsp then construirLista() end

    -- =========================================================
    -- MODULE: LOOPS / COMBAT
    -- =========================================================
    task.spawn(function()
        while true do
            local ok=pcall(function()
                task.wait(0.02)
                if CFG.noSpread then aplicarNoSpread() end
            end)
            if not ok then task.wait(0.1) end
        end
    end)
    task.spawn(function()
        while true do
            local ok=pcall(function()
                task.wait(0.012)
                if predictionKeybind then
                    local okKey,key=pcall(function() return predictionKeybind:GetKey() end)
                    if okKey and key then CFG.predictionAimTecla=key end
                    local okTipo,tipo=pcall(function() return predictionKeybind:GetType() end)
                    if okTipo and tipo then
                        if tipo=="hold" then CFG.predictionAimModo=1
                        elseif tipo=="always" then CFG.predictionAimModo=2
                        elseif tipo=="toggle" then CFG.predictionAimModo=0 end
                    end
                end
                ejecutarPredictionAim()
            end)
            if not ok then task.wait(0.1) end
        end
    end)

    -- =========================================================
    -- MODULE: LOOPS / DRAG AND KEYBOARD
    -- =========================================================
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
                if not raton1 and objetoArrastre then guardarCFGActual(); objetoArrastre=nil end
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

    -- =========================================================
    -- MODULE: LOOPS / AIM PANEL
    -- =========================================================
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

    -- =========================================================
    -- MODULE: LOOPS / CORPSE SCAN
    -- =========================================================
    task.spawn(function()
        while true do
            task.wait(0.5)
            local activos={}
            -- slots is kept because corpse ESP reuses Drawing labels.
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
                        ranura.texto=(esJugador and "[DEAD] " or "[NPC] ")..modelo.Name
                        ranura.col=col; ranura.etiqueta.Color=col
                    end
                end
            end
            for modelo in pairs(ranuras) do
                if not activos[modelo] then espEliminar(modelo) end
            end
        end
    end)

    -- =========================================================
    -- MODULE: LOOPS / WORLD ESP RENDER
    -- =========================================================
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
                    local esCadaver=ranura.col==C_CORPSE or ranura.col==C_CORPSE_NPC
                    local mostrar=esCadaver and CFG.cuerpoEsp
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

    -- =========================================================
    -- MODULE: LOOPS / PLAYER COUNT
    -- =========================================================
    task.spawn(function()
        while true do
            task.wait(0.1)
            if CFG.invEsp then
                local n=#Players:GetPlayers()
                if n~=INV.ultimoN then INV.ultimoN=n; construirLista() end
            end
        end
    end)


    notify("Project Delta ready - open Matcha to configure","PD v5.3",4)
end)
