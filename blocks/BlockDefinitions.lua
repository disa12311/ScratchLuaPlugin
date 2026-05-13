--[[
    BlockDefinitions.lua  (v2 — thêm Tween, RemoteEvent, GUI, Humanoid)
--]]

local C = Color3.fromRGB

local COLORS = {
    events    = C(255, 170,  0),
    control   = C(255, 140,  0),
    motion    = C( 74, 108, 212),
    looks     = C(138,  80, 180),
    variables = C(255, 140,  40),
    operators = C( 89, 192,  89),
    myblocks  = C(214,  73,  73),
    output    = C( 80, 160,  80),
    tween     = C( 30, 160, 190),
    remote    = C(190,  80, 160),
    gui       = C(200, 120,  40),
    humanoid  = C( 60, 180, 120),
}

local BlockDefinitions = {}

BlockDefinitions.categories = {

    -- ── EVENTS ────────────────────────────────────────────────
    {
        label = "⚡ Events", color = COLORS.events,
        blocks = {
            { id="event_gamestart",   label="🚀 When game starts",         shape="hat",   color=COLORS.events, inputs={},
              codeTemplate="game:GetService('RunService').Heartbeat:Once(function()", closeTemplate="end)", height=36, isContainer=true },
            { id="event_playerjoin",  label="👤 When player joins",        shape="hat",   color=COLORS.events,
              inputs={{name="playerVar",type="text",default="player",label="save as"}},
              codeTemplate="game:GetService('Players').PlayerAdded:Connect(function({playerVar})", closeTemplate="end)", height=44, isContainer=true },
            { id="event_playerleave", label="🚪 When player leaves",       shape="hat",   color=COLORS.events,
              inputs={{name="playerVar",type="text",default="player",label="save as"}},
              codeTemplate="game:GetService('Players').PlayerRemoving:Connect(function({playerVar})", closeTemplate="end)", height=44, isContainer=true },
            { id="event_touched",     label="✋ When part touched",        shape="hat",   color=COLORS.events,
              inputs={{name="partVar",type="text",default="hit",label="hit var"}},
              codeTemplate="script.Parent.Touched:Connect(function({partVar})", closeTemplate="end)", height=44, isContainer=true },
            { id="event_keydown",     label="⌨️ When key pressed",         shape="hat",   color=COLORS.events,
              inputs={{name="key",type="text",default="E",label="key"}},
              codeTemplate="game:GetService('UserInputService').InputBegan:Connect(function(input, processed)\n\tif processed then return end\n\tif input.KeyCode == Enum.KeyCode.{key} then",
              closeTemplate="\tend\nend)", height=44, isContainer=true },
            { id="event_heartbeat",   label="💓 Every frame (Heartbeat)",  shape="hat",   color=COLORS.events,
              inputs={{name="dtVar",type="text",default="dt",label="delta time"}},
              codeTemplate="game:GetService('RunService').Heartbeat:Connect(function({dtVar})", closeTemplate="end)", height=44, isContainer=true },
        },
    },

    -- ── CONTROL ───────────────────────────────────────────────
    {
        label = "🔁 Control", color = COLORS.control,
        blocks = {
            { id="control_wait",    label="⏱️ Wait [sec] seconds",           shape="stack", color=COLORS.control, inputs={{name="seconds",type="number",default="1",label="secs"}}, codeTemplate="task.wait({seconds})", height=32 },
            { id="control_repeat",  label="🔄 Repeat [n] times",             shape="stack", color=COLORS.control, inputs={{name="n",type="number",default="10",label="times"}},     codeTemplate="for _i = 1, {n} do", closeTemplate="end", height=32, isContainer=true },
            { id="control_for",     label="🔢 For [i] = [a] to [b]",         shape="stack", color=COLORS.control,
              inputs={{name="var",type="text",default="i",label="var"},{name="from",type="number",default="1",label="from"},{name="to",type="number",default="10",label="to"}},
              codeTemplate="for {var} = {from}, {to} do", closeTemplate="end", height=44, isContainer=true },
            { id="control_while",   label="♾️ While [cond]",                 shape="stack", color=COLORS.control, inputs={{name="cond",type="text",default="true",label="cond"}},   codeTemplate="while {cond} do", closeTemplate="\ttask.wait()\nend", height=32, isContainer=true },
            { id="control_if",      label="❓ If [cond] then",               shape="stack", color=COLORS.control, inputs={{name="cond",type="text",default="true",label="cond"}},   codeTemplate="if {cond} then", closeTemplate="end", height=32, isContainer=true },
            { id="control_ifelse",  label="❓ If [cond] else",               shape="stack", color=COLORS.control, inputs={{name="cond",type="text",default="true",label="cond"}},   codeTemplate="if {cond} then", midTemplate="else", closeTemplate="end", height=32, isContainer=true },
            { id="control_break",   label="⛔ Break",                         shape="stack", color=COLORS.control, inputs={}, codeTemplate="break", height=28 },
            { id="control_continue",label="↪️ Continue",                     shape="stack", color=COLORS.control, inputs={}, codeTemplate="continue", height=28 },
            { id="control_return",  label="↩️ Return [value]",               shape="cap",   color=COLORS.control, inputs={{name="value",type="text",default="nil",label="value"}},  codeTemplate="return {value}", height=32 },
            { id="control_spawn",   label="🧵 Spawn (new thread)",           shape="stack", color=COLORS.control, inputs={}, codeTemplate="task.spawn(function()", closeTemplate="end)", height=32, isContainer=true },
            { id="control_defer",   label="⏳ Defer (next frame)",           shape="stack", color=COLORS.control, inputs={}, codeTemplate="task.defer(function()", closeTemplate="end)", height=32, isContainer=true },
        },
    },

    -- ── VARIABLES ─────────────────────────────────────────────
    {
        label = "📦 Variables", color = COLORS.variables,
        blocks = {
            { id="var_local",  label="📝 Local [name] = [value]",       shape="stack", color=COLORS.variables,
              inputs={{name="name",type="text",default="myVar",label="name"},{name="value",type="text",default="0",label="value"}},
              codeTemplate="local {name} = {value}", height=44 },
            { id="var_assign", label="🔀 Set [name] = [value]",         shape="stack", color=COLORS.variables,
              inputs={{name="name",type="text",default="myVar",label="name"},{name="value",type="text",default="0",label="value"}},
              codeTemplate="{name} = {value}", height=44 },
            { id="var_change", label="➕ Change [name] by [n]",         shape="stack", color=COLORS.variables,
              inputs={{name="name",type="text",default="myVar",label="name"},{name="amount",type="number",default="1",label="by"}},
              codeTemplate="{name} = {name} + ({amount})", height=44 },
            { id="var_table",  label="📋 Create table [name]",          shape="stack", color=COLORS.variables, inputs={{name="name",type="text",default="myTable",label="name"}}, codeTemplate="local {name} = {}", height=32 },
            { id="var_insert", label="➕ Insert [value] into [tbl]",    shape="stack", color=COLORS.variables,
              inputs={{name="tbl",type="text",default="myTable",label="table"},{name="value",type="text",default="\"item\"",label="value"}},
              codeTemplate="table.insert({tbl}, {value})", height=44 },
        },
    },

    -- ── PARTS ─────────────────────────────────────────────────
    {
        label = "🎮 Parts", color = COLORS.motion,
        blocks = {
            { id="part_move",         label="🏃 Move [part] by XYZ",          shape="stack", color=COLORS.motion,
              inputs={{name="part",type="text",default="workspace.Part",label="part"},{name="x",type="number",default="0",label="X"},{name="y",type="number",default="5",label="Y"},{name="z",type="number",default="0",label="Z"}},
              codeTemplate="{part}.CFrame = {part}.CFrame + Vector3.new({x}, {y}, {z})", height=52 },
            { id="part_setpos",       label="📍 Set position [part]",         shape="stack", color=COLORS.motion,
              inputs={{name="part",type="text",default="workspace.Part",label="part"},{name="x",type="number",default="0",label="X"},{name="y",type="number",default="10",label="Y"},{name="z",type="number",default="0",label="Z"}},
              codeTemplate="{part}.CFrame = CFrame.new({x}, {y}, {z})", height=52 },
            { id="part_setcolor",     label="🎨 Set color [part] RGB",        shape="stack", color=COLORS.motion,
              inputs={{name="part",type="text",default="workspace.Part",label="part"},{name="r",type="number",default="255",label="R"},{name="g",type="number",default="0",label="G"},{name="b",type="number",default="0",label="B"}},
              codeTemplate="{part}.BrickColor = BrickColor.new(Color3.fromRGB({r}, {g}, {b}))", height=52 },
            { id="part_transparency", label="👻 Transparency [part] [n]",     shape="stack", color=COLORS.motion,
              inputs={{name="part",type="text",default="workspace.Part",label="part"},{name="n",type="number",default="0.5",label="0~1"}},
              codeTemplate="{part}.Transparency = {n}", height=44 },
            { id="part_anchored",     label="⚓ Set anchored [part] [bool]",  shape="stack", color=COLORS.motion,
              inputs={{name="part",type="text",default="workspace.Part",label="part"},{name="val",type="text",default="true",label="true/false"}},
              codeTemplate="{part}.Anchored = {val}", height=44 },
            { id="part_destroy",      label="💥 Destroy [part]",              shape="stack", color=COLORS.motion, inputs={{name="part",type="text",default="workspace.Part",label="part"}}, codeTemplate="{part}:Destroy()", height=32 },
            { id="part_clone",        label="📋 Clone [part] as [name]",      shape="stack", color=COLORS.motion,
              inputs={{name="part",type="text",default="workspace.Part",label="part"},{name="newVar",type="text",default="clone",label="save as"}},
              codeTemplate="local {newVar} = {part}:Clone()\n{newVar}.Parent = workspace", height=44 },
            { id="part_find",         label="🔍 Find [name] in [parent]",     shape="stack", color=COLORS.motion,
              inputs={{name="varName",type="text",default="found",label="save as"},{name="name",type="text",default="Part",label="name"},{name="parent",type="text",default="workspace",label="in"}},
              codeTemplate="local {varName} = {parent}:FindFirstChild(\"{name}\")", height=52 },
        },
    },

    -- ── TWEEN ─────────────────────────────────────────────────
    {
        label = "🎬 Tween", color = COLORS.tween,
        blocks = {
            { id="tween_move",     label="🎬 Tween move [part] to XYZ",      shape="stack", color=COLORS.tween,
              inputs={{name="part",type="text",default="workspace.Part",label="part"},{name="x",type="number",default="0",label="X"},{name="y",type="number",default="10",label="Y"},{name="z",type="number",default="0",label="Z"},{name="dur",type="number",default="1",label="secs"},{name="style",type="text",default="Quad",label="style"}},
              codeTemplate="local _ts=game:GetService(\"TweenService\")\n_ts:Create({part},TweenInfo.new({dur},Enum.EasingStyle.{style}),{{CFrame=CFrame.new({x},{y},{z})}}):Play()",
              height=60 },
            { id="tween_property", label="🎬 Tween [part].[prop] → [val]",   shape="stack", color=COLORS.tween,
              inputs={{name="part",type="text",default="workspace.Part",label="part"},{name="prop",type="text",default="Transparency",label="prop"},{name="val",type="text",default="1",label="to"},{name="dur",type="number",default="1",label="secs"},{name="style",type="text",default="Quad",label="style"}},
              codeTemplate="game:GetService(\"TweenService\"):Create({part},TweenInfo.new({dur},Enum.EasingStyle.{style}),{{{prop}={val}}}):Play()",
              height=60 },
        },
    },

    -- ── REMOTE EVENTS ─────────────────────────────────────────
    {
        label = "📡 Remote", color = COLORS.remote,
        blocks = {
            { id="remote_fire_server", label="📡 FireServer [remote] [data]",      shape="stack", color=COLORS.remote,
              inputs={{name="remote",type="text",default="game.ReplicatedStorage.MyEvent",label="remote"},{name="data",type="text",default="nil",label="data"}},
              codeTemplate="{remote}:FireServer({data})", height=44 },
            { id="remote_fire_client", label="📡 FireClient [remote] [plr] [data]",shape="stack", color=COLORS.remote,
              inputs={{name="remote",type="text",default="game.ReplicatedStorage.MyEvent",label="remote"},{name="player",type="text",default="player",label="player"},{name="data",type="text",default="nil",label="data"}},
              codeTemplate="{remote}:FireClient({player}, {data})", height=52 },
            { id="remote_on_server",   label="📡 OnServerEvent [remote]",          shape="hat",   color=COLORS.remote,
              inputs={{name="remote",type="text",default="game.ReplicatedStorage.MyEvent",label="remote"},{name="playerVar",type="text",default="player",label="player"},{name="dataVar",type="text",default="data",label="data var"}},
              codeTemplate="{remote}.OnServerEvent:Connect(function({playerVar}, {dataVar})", closeTemplate="end)", height=52, isContainer=true },
            { id="remote_on_client",   label="📡 OnClientEvent [remote]",          shape="hat",   color=COLORS.remote,
              inputs={{name="remote",type="text",default="game.ReplicatedStorage.MyEvent",label="remote"},{name="dataVar",type="text",default="data",label="data var"}},
              codeTemplate="{remote}.OnClientEvent:Connect(function({dataVar})", closeTemplate="end)", height=44, isContainer=true },
        },
    },

    -- ── GUI ───────────────────────────────────────────────────
    {
        label = "🖼️ GUI", color = COLORS.gui,
        blocks = {
            { id="gui_set_text",      label="🔤 Set text [label] = [text]",  shape="stack", color=COLORS.gui,
              inputs={{name="label",type="text",default="script.Parent.TextLabel",label="label"},{name="text",type="text",default="Hello!",label="text"}},
              codeTemplate="{label}.Text = \"{text}\"", height=44 },
            { id="gui_set_visible",   label="👁️ Set visible [gui] [bool]",   shape="stack", color=COLORS.gui,
              inputs={{name="gui",type="text",default="script.Parent.Frame",label="gui"},{name="val",type="text",default="true",label="bool"}},
              codeTemplate="{gui}.Visible = {val}", height=44 },
            { id="gui_tween_pos",     label="🎬 Slide [gui] to [Xs,Ys]",     shape="stack", color=COLORS.gui,
              inputs={{name="gui",type="text",default="script.Parent.Frame",label="gui"},{name="xs",type="number",default="0.5",label="X%"},{name="ys",type="number",default="0.5",label="Y%"},{name="dur",type="number",default="0.5",label="secs"}},
              codeTemplate="game:GetService(\"TweenService\"):Create({gui},TweenInfo.new({dur}),{{Position=UDim2.fromScale({xs},{ys})}}):Play()", height=52 },
            { id="gui_on_click",      label="🖱️ When [btn] clicked",         shape="hat",   color=COLORS.gui,
              inputs={{name="btn",type="text",default="script.Parent.TextButton",label="button"}},
              codeTemplate="{btn}.MouseButton1Click:Connect(function()", closeTemplate="end)", height=36, isContainer=true },
            { id="gui_notify",        label="🔔 Notify [title] [msg] [dur]", shape="stack", color=COLORS.gui,
              inputs={{name="title",type="text",default="Notice",label="title"},{name="msg",type="text",default="Hello!",label="msg"},{name="dur",type="number",default="5",label="secs"}},
              codeTemplate="game:GetService(\"StarterGui\"):SetCore(\"SendNotification\",{{Title=\"{title}\",Text=\"{msg}\",Duration={dur}}})", height=52 },
        },
    },

    -- ── HUMANOID ──────────────────────────────────────────────
    {
        label = "🧍 Humanoid", color = COLORS.humanoid,
        blocks = {
            { id="hum_get",      label="🧍 Get humanoid of [char]",      shape="stack", color=COLORS.humanoid,
              inputs={{name="varName",type="text",default="hum",label="save as"},{name="char",type="text",default="character",label="char"}},
              codeTemplate="local {varName} = {char}:FindFirstChildOfClass(\"Humanoid\")", height=44 },
            { id="hum_sethealth",label="❤️ Set health [hum] = [hp]",    shape="stack", color=COLORS.humanoid,
              inputs={{name="hum",type="text",default="hum",label="humanoid"},{name="hp",type="number",default="100",label="hp"}},
              codeTemplate="if {hum} then {hum}.Health = {hp} end", height=44 },
            { id="hum_setspeed", label="🏃 Walk speed [hum] = [n]",     shape="stack", color=COLORS.humanoid,
              inputs={{name="hum",type="text",default="hum",label="humanoid"},{name="n",type="number",default="16",label="speed"}},
              codeTemplate="if {hum} then {hum}.WalkSpeed = {n} end", height=44 },
            { id="hum_setjump",  label="⬆️ Jump power [hum] = [n]",    shape="stack", color=COLORS.humanoid,
              inputs={{name="hum",type="text",default="hum",label="humanoid"},{name="n",type="number",default="50",label="power"}},
              codeTemplate="if {hum} then {hum}.JumpPower = {n} end", height=44 },
            { id="hum_moveto",   label="📍 MoveTo [hum] [pos]",         shape="stack", color=COLORS.humanoid,
              inputs={{name="hum",type="text",default="hum",label="humanoid"},{name="pos",type="text",default="Vector3.new(0,0,0)",label="pos"}},
              codeTemplate="if {hum} then {hum}:MoveTo({pos}) end", height=44 },
            { id="hum_on_died",  label="💀 When [hum] dies",            shape="hat",   color=COLORS.humanoid,
              inputs={{name="hum",type="text",default="hum",label="humanoid"}},
              codeTemplate="if {hum} then\n\t{hum}.Died:Connect(function()", closeTemplate="\tend)\nend", height=36, isContainer=true },
        },
    },

    -- ── PLAYER ────────────────────────────────────────────────
    {
        label = "👤 Player", color = COLORS.looks,
        blocks = {
            { id="player_get_char",  label="👤 Get character of [player]",   shape="stack", color=COLORS.looks,
              inputs={{name="varName",type="text",default="char",label="save as"},{name="player",type="text",default="player",label="player"}},
              codeTemplate="local {varName} = {player}.Character or {player}.CharacterAdded:Wait()", height=44 },
            { id="player_teleport",  label="⚡ Teleport [player] to XYZ",    shape="stack", color=COLORS.looks,
              inputs={{name="player",type="text",default="player",label="player"},{name="x",type="number",default="0",label="X"},{name="y",type="number",default="10",label="Y"},{name="z",type="number",default="0",label="Z"}},
              codeTemplate="local _c={player}.Character\nif _c and _c:FindFirstChild(\"HumanoidRootPart\") then\n\t_c.HumanoidRootPart.CFrame=CFrame.new({x},{y},{z})\nend", height=52 },
            { id="player_kick",      label="🦶 Kick [player] [reason]",      shape="stack", color=COLORS.looks,
              inputs={{name="player",type="text",default="player",label="player"},{name="msg",type="text",default="Kicked",label="reason"}},
              codeTemplate="{player}:Kick(\"{msg}\")", height=44 },
            { id="player_give_tool", label="🗡️ Give [tool] to [player]",     shape="stack", color=COLORS.looks,
              inputs={{name="tool",type="text",default="tool",label="tool"},{name="player",type="text",default="player",label="player"}},
              codeTemplate="local _t={tool}:Clone()\n_t.Parent={player}.Backpack", height=44 },
        },
    },

    -- ── OUTPUT ────────────────────────────────────────────────
    {
        label = "📢 Output", color = COLORS.output,
        blocks = {
            { id="output_print",    label="🖨️ Print [message]",      shape="stack", color=COLORS.output, inputs={{name="message",type="text",default="Hello!",label="msg"}},   codeTemplate="print(\"{message}\")",  height=32 },
            { id="output_printvar", label="🖨️ Print variable [var]", shape="stack", color=COLORS.output, inputs={{name="var",type="text",default="myVar",label="var"}},        codeTemplate="print({var})",          height=32 },
            { id="output_warn",     label="⚠️ Warn [message]",       shape="stack", color=COLORS.output, inputs={{name="message",type="text",default="Warning!",label="msg"}}, codeTemplate="warn(\"{message}\")",   height=32 },
            { id="output_error",    label="🚨 Error [message]",      shape="stack", color=COLORS.output, inputs={{name="message",type="text",default="Error!",label="msg"}},   codeTemplate="error(\"{message}\")",  height=32 },
        },
    },

    -- ── MATH ──────────────────────────────────────────────────
    {
        label = "🔢 Math", color = COLORS.operators,
        blocks = {
            { id="math_random", label="🎲 Random [min] to [max]",          shape="stack", color=COLORS.operators,
              inputs={{name="varName",type="text",default="rand",label="save as"},{name="min",type="number",default="1",label="min"},{name="max",type="number",default="10",label="max"}},
              codeTemplate="local {varName} = math.random({min}, {max})", height=44 },
            { id="math_abs",    label="| abs | [value]",                   shape="stack", color=COLORS.operators,
              inputs={{name="varName",type="text",default="result",label="save as"},{name="value",type="text",default="x",label="value"}},
              codeTemplate="local {varName} = math.abs({value})", height=32 },
            { id="math_floor",  label="⬇️ Floor [value]",                  shape="stack", color=COLORS.operators,
              inputs={{name="varName",type="text",default="result",label="save as"},{name="value",type="text",default="x",label="value"}},
              codeTemplate="local {varName} = math.floor({value})", height=32 },
            { id="math_clamp",  label="📐 Clamp [v] min [a] max [b]",      shape="stack", color=COLORS.operators,
              inputs={{name="varName",type="text",default="result",label="save as"},{name="v",type="text",default="x",label="value"},{name="a",type="number",default="0",label="min"},{name="b",type="number",default="100",label="max"}},
              codeTemplate="local {varName} = math.clamp({v}, {a}, {b})", height=52 },
            { id="math_lerp",   label="🔀 Lerp [a] → [b] at [t]",          shape="stack", color=COLORS.operators,
              inputs={{name="varName",type="text",default="result",label="save as"},{name="a",type="text",default="0",label="from"},{name="b",type="text",default="100",label="to"},{name="t",type="text",default="0.5",label="t"}},
              codeTemplate="local {varName} = {a} + ({b} - {a}) * {t}", height=52 },
        },
    },

    -- ── FUNCTIONS ─────────────────────────────────────────────
    {
        label = "🧩 Functions", color = COLORS.myblocks,
        blocks = {
            { id="func_define",  label="🔧 Define function [name]([args])", shape="hat",   color=COLORS.myblocks,
              inputs={{name="name",type="text",default="myFunction",label="name"},{name="args",type="text",default="",label="args"}},
              codeTemplate="local function {name}({args})", closeTemplate="end", height=44, isContainer=true },
            { id="func_call",    label="▶️ Call [name]([args])",            shape="stack", color=COLORS.myblocks,
              inputs={{name="name",type="text",default="myFunction",label="name"},{name="args",type="text",default="",label="args"}},
              codeTemplate="{name}({args})", height=32 },
            { id="func_comment", label="💬 Comment [text]",                shape="stack", color=C(150,150,150), inputs={{name="text",type="text",default="comment here",label="text"}}, codeTemplate="-- {text}", height=32 },
            { id="func_section", label="📌 Section [title]",               shape="stack", color=C(100,100,110), inputs={{name="title",type="text",default="SECTION",label="title"}}, codeTemplate="-- ══════ {title} ══════", height=28 },
        },
    },
}

BlockDefinitions.byId = {}
for _, cat in ipairs(BlockDefinitions.categories) do
    for _, def in ipairs(cat.blocks) do
        BlockDefinitions.byId[def.id] = def
    end
end

return BlockDefinitions
