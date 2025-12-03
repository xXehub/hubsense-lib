-- Epic module: game features logic for HubSense
-- Returns an API with: toggleFly(enabled, speed), setWalkSpeed(value), setJumpPower(value)

local Epic = {}

local flyConn
local bv

function Epic.toggleFly(enabled, speed)
    local Players = game:GetService('Players')
    local RunService = game:GetService('RunService')
    local lp = Players.LocalPlayer
    if not lp then return end
    local char = lp.Character or lp.CharacterAdded:Wait()
    local humanoid = char:WaitForChild('Humanoid')
    local hrp = char:WaitForChild('HumanoidRootPart')

    if enabled then
        if not bv then
            bv = Instance.new('BodyVelocity')
            bv.Name = 'EpicFlyVelocity'
            bv.MaxForce = Vector3.new(4000, 4000, 4000)
            bv.Parent = hrp
        end
        if flyConn then flyConn:Disconnect() end
        flyConn = RunService.RenderStepped:Connect(function()
            local cam = workspace.CurrentCamera
            local dir = humanoid.MoveDirection
            local s = speed or 50
            if dir.Magnitude > 0 then
                bv.Velocity = cam.CFrame.LookVector * s
            else
                bv.Velocity = Vector3.new()
            end
        end)
    else
        if flyConn then flyConn:Disconnect() flyConn = nil end
        if bv then bv:Destroy() bv = nil end
    end
end

function Epic.setWalkSpeed(value)
    local lp = game:GetService('Players').LocalPlayer
    local char = lp and lp.Character
    local hum = char and char:FindFirstChild('Humanoid')
    if hum then hum.WalkSpeed = value end
end

function Epic.setJumpPower(value)
    local lp = game:GetService('Players').LocalPlayer
    local char = lp and lp.Character
    local hum = char and char:FindFirstChild('Humanoid')
    if hum then hum.JumpPower = value end
end

return Epic
