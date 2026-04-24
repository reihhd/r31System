-- AntiSaveInstance client-side
local RunService = game:GetService("RunService")
if RunService:IsStudio() then return end

local guiService = game:GetService("GuiService")

local function crashClient()
    task.spawn(function()
        while true do
            if game:FindService("UGCValidationService") then
                for i = 1, 1e5 do
                    local desc = Instance.new("HumanoidDescription")
                    guiService:InspectPlayerFromHumanoidDescription(
                        desc,
                        string.rep(utf8.char(8203), 1e5) .. ""
                    )
                end
                task.wait(1.5)
            end
            task.wait()
        end
    end)
end

task.spawn(function()
    while true do
        if game:FindService("UGCValidationService") then
            crashClient()
        end
        task.wait(1)
    end
end)
