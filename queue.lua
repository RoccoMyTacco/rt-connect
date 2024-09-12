Queue = {}

Queue.playerQueue = {}
Queue.playerPriorities = {}
Queue.reconnectTimes = {} -- Store reconnect times for crash and leave protection

-- Function to add a player to the queue
function Queue:addPlayerToQueue(name, fivemLicense, steamIdentifier, deferrals)
    if not self:isPlayerInQueue(fivemLicense) then
        -- Check for reconnect after crash or leave
        local currentTime = GetGameTimer()
        local priority = Config.DefaultPriority -- Initialize default priority

        if Config.CrashProtectionEnabled and self.reconnectTimes[fivemLicense] then
            if currentTime - self.reconnectTimes[fivemLicense].time <= Config.CrashReconnectTime and self.reconnectTimes[fivemLicense].type == 'crash' then
                if Config.DeveloperMode then
                    print(Config.Messages.ReconnectingAfterCrash) -- Debug print
                end
                priority = Config.CrashPriorityBoost
            elseif currentTime - self.reconnectTimes[fivemLicense].time <= Config.LeaveReconnectTime and self.reconnectTimes[fivemLicense].type == 'leave' then
                if Config.DeveloperMode then
                    print(Config.Messages.ReconnectingAfterLeave) -- Debug print
                end
                priority = Config.LeavePriorityBoost
            else
                priority = Config.DefaultPriority
                self.reconnectTimes[fivemLicense] = nil -- Clear expired reconnect records
            end
        else
            priority = Config.DefaultPriority
        end

        -- Fetch player priority from the database
        MySQL.Async.fetchScalar('SELECT priority FROM player_priorities WHERE fivemLicense = @fivemLicense', {
            ['@fivemLicense'] = fivemLicense
        }, function(dbPriority)
            if Config.DeveloperMode then
                if dbPriority then
                    print("Fetched priority from database for player:", fivemLicense, "Priority:", dbPriority) -- Debug print
                else
                    print("No priority found for player, defaulting to 0:", fivemLicense)                      -- Debug print
                end
            end
            priority = dbPriority or priority
            self.playerPriorities[fivemLicense] = priority
            table.insert(self.playerQueue, fivemLicense)
            self:sortQueue()

            -- If player doesn't exist in the database, insert them
            MySQL.Async.fetchScalar('SELECT COUNT(*) FROM player_priorities WHERE fivemLicense = @fivemLicense', {
                ['@fivemLicense'] = fivemLicense
            }, function(count)
                if count == 0 then
                    MySQL.Async.execute(
                        'INSERT INTO player_priorities (fivemLicense, steamIdentifier, priority) VALUES (@fivemLicense, @steamIdentifier, @priority)',
                        {
                            ['@fivemLicense'] = fivemLicense,
                            ['@steamIdentifier'] = steamIdentifier,
                            ['@priority'] = priority
                        })
                end

                -- After inserting or fetching the priority, update the card
                updatePlayerCard(name, fivemLicense, priority, deferrals)
            end)
        end)
    end
end

-- Function to update the player's adaptive card
function updatePlayerCard(name, fivemLicense, priority, deferrals)
    local queuePosition = Queue:getPlayerQueuePosition(fivemLicense) or 0
    local function createCard()
        local passengers = {}
        local maxDisplayPassengers = 5

        -- Determine passengers in front of the player
        for i = math.max(1, queuePosition - maxDisplayPassengers), queuePosition - 1 do
            table.insert(passengers, Queue.playerQueue[i] or "N/A")
        end

        local passengerItems = {}
        local seatItems = {}

        -- Add the user's information first with green highlight
        table.insert(passengerItems, {
            ["type"] = "TextBlock",
            ["text"] = name,
            ["spacing"] = "small",
            ["wrap"] = true,
            ["color"] = "Good",   -- Green color for the user's name
            ["weight"] = "Bolder" -- Make it bold for emphasis
        })

        table.insert(seatItems, {
            ["type"] = "TextBlock",
            ["text"] = Config.AdaptiveCard.SeatPrefix .. " " .. tostring(queuePosition),
            ["horizontalAlignment"] = "right",
            ["spacing"] = "small",
            ["wrap"] = true,
            ["color"] = "Good",   -- Green color for the user's queue position
            ["weight"] = "Bolder" -- Make it bold for emphasis
        })

        -- Add other passengers' information
        for index, passenger in ipairs(passengers) do
            table.insert(passengerItems, {
                ["type"] = "TextBlock",
                ["text"] = passenger,
                ["spacing"] = "small",
                ["wrap"] = true
            })

            table.insert(seatItems, {
                ["type"] = "TextBlock",
                ["text"] = "Queue " .. tostring(queuePosition - #passengers + index - 1),
                ["horizontalAlignment"] = "right",
                ["spacing"] = "small",
                ["wrap"] = true
            })
        end

        -- Determine flight status based on queue position
        local flightStatusText = "On Time"
        local flightStatusColor = "Good"
        if queuePosition > maxDisplayPassengers then
            flightStatusText = Config.AdaptiveCard.FlightStatus.Delayed
            flightStatusColor = "Attention"
        end

        return {
            ["type"] = "AdaptiveCard",
            ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
            ["version"] = "1.3",
            ["body"] = {
                {
                    ["type"] = "TextBlock",
                    ["text"] = "Your Flight Update",
                    ["weight"] = "Bolder",
                    ["size"] = "Medium",
                    ["wrap"] = true
                },
                {
                    ["type"] = "ColumnSet",
                    ["columns"] = {
                        {
                            ["type"] = "Column",
                            ["width"] = "auto",
                            ["items"] = {
                                {
                                    ["type"] = "Image",
                                    ["url"] = Config.AdaptiveCard.PlaneIconUrl,
                                    ["size"] = "Small",
                                    ["altText"] = "Airplane"
                                }
                            }
                        },
                        {
                            ["type"] = "Column",
                            ["width"] = "stretch",
                            ["items"] = {
                                {
                                    ["type"] = "TextBlock",
                                    ["text"] = "Flight Status",
                                    ["horizontalAlignment"] = "right",
                                    ["isSubtle"] = true,
                                    ["wrap"] = true
                                },
                                {
                                    ["type"] = "TextBlock",
                                    ["text"] = flightStatusText,
                                    ["horizontalAlignment"] = "right",
                                    ["spacing"] = "none",
                                    ["size"] = "Large",
                                    ["color"] = flightStatusColor,
                                    ["weight"] = "Bolder",
                                    ["wrap"] = true
                                }
                            }
                        }
                    }
                },
                {
                    ["type"] = "ColumnSet",
                    ["separator"] = true,
                    ["spacing"] = "Medium",
                    ["columns"] = {
                        {
                            ["type"] = "Column",
                            ["width"] = "stretch",
                            ["items"] = passengerItems
                        },
                        {
                            ["type"] = "Column",
                            ["width"] = "auto",
                            ["items"] = seatItems
                        }
                    }
                },
                {
                    ["type"] = "ColumnSet",
                    ["separator"] = true,
                    ["spacing"] = "Medium",
                    ["columns"] = {
                        {
                            ["type"] = "Column",
                            ["width"] = "stretch",
                            ["items"] = {
                                {
                                    ["type"] = "TextBlock",
                                    ["text"] = "Flight",
                                    ["isSubtle"] = true,
                                    ["weight"] = "Bolder",
                                    ["wrap"] = true
                                },
                                {
                                    ["type"] = "TextBlock",
                                    ["text"] = Config.AdaptiveCard.Flight,
                                    ["spacing"] = "small",
                                    ["wrap"] = true
                                }
                            }
                        },
                        {
                            ["type"] = "Column",
                            ["width"] = "stretch",
                            ["items"] = {
                                {
                                    ["type"] = "TextBlock",
                                    ["text"] = "Departs",
                                    ["isSubtle"] = true,
                                    ["horizontalAlignment"] = "center",
                                    ["weight"] = "Bolder",
                                    ["wrap"] = true
                                },
                                {
                                    ["type"] = "TextBlock",
                                    ["text"] = Config.AdaptiveCard.DepartureTime,
                                    ["color"] = "Attention",
                                    ["weight"] = "Bolder",
                                    ["horizontalAlignment"] = "center",
                                    ["spacing"] = "small",
                                    ["wrap"] = true
                                }
                            }
                        },
                        {
                            ["type"] = "Column",
                            ["width"] = "stretch",
                            ["items"] = {
                                {
                                    ["type"] = "TextBlock",
                                    ["text"] = "Arrives",
                                    ["isSubtle"] = true,
                                    ["horizontalAlignment"] = "right",
                                    ["weight"] = "Bolder",
                                    ["wrap"] = true
                                },
                                {
                                    ["type"] = "TextBlock",
                                    ["text"] = Config.AdaptiveCard.ArrivalTime,
                                    ["color"] = "Attention",
                                    ["horizontalAlignment"] = "right",
                                    ["weight"] = "Bolder",
                                    ["spacing"] = "small",
                                    ["wrap"] = true
                                }
                            }
                        }
                    }
                }
            },
            ["actions"] = {
                {
                    ["type"] = "Action.Submit",
                    ["title"] = Config.AdaptiveCard.ButtonLabels.Cancel,
                    ["data"] = {
                        ["action"] = "cancel"
                    }
                }
            }
        }
    end


    CreateThread(function()
        local startTime = GetGameTimer()
        local showCardTime = 5000     -- Show the card for 5 seconds
        local updateInterval = 500    -- Update the card every 0.5 seconds
        local devLeaveInterval = 3000 -- Time interval for dummy players to leave the queue (in milliseconds)

        while true do
            -- Recalculate queue position after any changes
            queuePosition = Queue:getPlayerQueuePosition(fivemLicense) or 0

            -- Create and present the updated card
            local card = createCard()

            -- Present or update the card to the player
            deferrals.presentCard(json.encode(card), function(response)
                if response and response.action == "cancel" then
                    Queue:removePlayerFromQueue(fivemLicense)
                    Queue.reconnectTimes[fivemLicense] = { time = GetGameTimer(), type = 'leave' } -- Record the leave time
                    deferrals.done(Config.Messages.ConnectionCancelled)
                    return
                end
            end)

            -- Allow connection after a short delay
            if GetGameTimer() - startTime >= showCardTime then
                if Queue.playerQueue[1] == fivemLicense then
                    -- If the player is at the front of the queue, allow them to join
                    Queue:removePlayerFromQueue(fivemLicense)
                    deferrals.done()
                    break
                elseif Config.DeveloperMode then
                    -- In developer mode, simulate that the player needs to wait indefinitely unless they are at the front
                    Wait(1000)

                    -- Simulate a dummy player leaving the queue
                    if GetGameTimer() - startTime > devLeaveInterval then
                        -- Remove a dummy player from the queue
                        for i, id in ipairs(Queue.playerQueue) do
                            if string.sub(id, 1, 9) == "dev:dummy" then
                                table.remove(Queue.playerQueue, i)
                                Queue.playerPriorities[id] = nil
                                print("Dummy player left the queue: " .. id) -- Debug print
                                break
                            end
                        end
                        -- Reset the leave interval timer
                        startTime = GetGameTimer()

                        -- Recalculate queue position after dummy player leaves
                        queuePosition = Queue:getPlayerQueuePosition(fivemLicense) or 0
                    end
                else
                    -- If not in developer mode, allow the connection if player is whitelisted or queue is empty
                    if queuePosition == 0 or Config.Whitelist[fivemLicense] then
                        Queue:removePlayerFromQueue(fivemLicense)
                        deferrals.done()
                        break
                    end
                end
            end

            Wait(updateInterval) -- Wait 0.5 seconds before updating again
        end
    end)
end

-- Function to simulate a full queue in developer mode
function Queue:simulateFullQueue()
    if Config.DeveloperMode then
        for i = 1, Config.DevQueueSize do
            local dummyLicense = "dev:dummy" .. i
            if not self:isPlayerInQueue(dummyLicense) then
                table.insert(self.playerQueue, dummyLicense)
                self.playerPriorities[dummyLicense] = 0 -- All dummy players have default priority
            end
        end
        self:sortQueue()
    end
end

-- Function to remove a player from the queue
function Queue:removePlayerFromQueue(fivemLicense)
    for i, id in ipairs(self.playerQueue) do
        if id == fivemLicense then
            table.remove(self.playerQueue, i)
            self.playerPriorities[fivemLicense] = nil
            break
        end
    end
end

-- Function to check if a player is in the queue
function Queue:isPlayerInQueue(fivemLicense)
    for _, id in ipairs(self.playerQueue) do
        if id == fivemLicense then
            return true
        end
    end
    return false
end

-- Function to sort queue by priority
function Queue:sortQueue()
    table.sort(self.playerQueue, function(a, b)
        local aPriority = self.playerPriorities[a] or 0
        local bPriority = self.playerPriorities[b] or 0
        return aPriority > bPriority
    end)
end

-- Function to get the position of a player in the queue
function Queue:getPlayerQueuePosition(fivemLicense)
    for i, id in ipairs(self.playerQueue) do
        if id == fivemLicense then
            return i
        end
    end
    return nil
end

-- Function to change player priority
function Queue:changePlayerPriority(fivemLicense, newPriority)
    if self.playerPriorities[fivemLicense] then
        self.playerPriorities[fivemLicense] = newPriority
        MySQL.Async.execute('UPDATE player_priorities SET priority = @priority WHERE fivemLicense = @fivemLicense', {
            ['@priority'] = newPriority,
            ['@fivemLicense'] = fivemLicense
        })
        self:sortQueue()
    end
end

-- Event handler for player disconnecting to handle crash/leave protection
AddEventHandler('playerDropped', function(reason)
    local player = source
    local fivemLicense

    -- Get the player's identifiers
    for _, id in ipairs(GetPlayerIdentifiers(player)) do
        if string.match(id, 'license:') then
            fivemLicense = id
            break
        end
    end

    -- Store the disconnect time for crash/leave protection
    if fivemLicense and not Queue:isPlayerInQueue(fivemLicense) then
        Queue.reconnectTimes[fivemLicense] = { time = GetGameTimer(), type = 'crash' }
    end
end)

-- Event handler for player connecting
AddEventHandler('playerConnecting', function(name, setCallback, deferrals)
    local player = source
    deferrals.defer()

    -- Wait for at least a tick before calling update, presentCard, or done
    Wait(0)

    local fivemLicense
    local steamIdentifier

    -- Get the player's identifiers
    for _, id in ipairs(GetPlayerIdentifiers(player)) do
        if string.match(id, 'license:') then
            fivemLicense = id
        elseif string.match(id, 'steam:') then
            steamIdentifier = id
        end
    end

    -- If no FiveM license, assign a dummy ID (for testing purposes)
    if not fivemLicense then
        fivemLicense = 'license:dummy'
    end

    -- Simulate a full queue if in developer mode
    if Config.DeveloperMode then
        Queue:simulateFullQueue()
    end

    -- Add player to the queue with priority, if applicable
    Queue:addPlayerToQueue(name, fivemLicense, steamIdentifier, deferrals)
end)
