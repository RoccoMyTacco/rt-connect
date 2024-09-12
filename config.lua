-- config.lua

Config = {}

-- Queue and Priority Settings
Config.DefaultPriority = 0       -- Default priority level for players not in the database
Config.WhitelistPriority = 100   -- Priority level for whitelisted players
Config.QueueCheckInterval = 1000 -- Interval in milliseconds for checking the queue (e.g., 1000 = 1 second)

-- Crash and Leave Protection
Config.CrashProtectionEnabled = true -- Enable crash protection
Config.CrashReconnectTime = 300000   -- Time in milliseconds within which a player can reconnect after a crash with higher priority (e.g., 300000 = 5 minutes)
Config.CrashPriorityBoost = 10       -- Priority boost for players reconnecting after a crash

Config.LeaveProtectionEnabled = true -- Enable leave protection
Config.LeaveReconnectTime = 60000    -- Time in milliseconds within which a player can reconnect after leaving the queue voluntarily (e.g., 60000 = 1 minute)
Config.LeavePriorityBoost = 5        -- Priority boost for players reconnecting after leaving

-- Messages
Config.Messages = {
    ThankYou = "Thank you for your patience. We are processing your connection request.",
    AlreadyInQueue = "You are already in the queue. Please wait for your turn.",
    Timeout = "Connection timed out. Please try again later.",
    ConnectionCancelled = "You have canceled your connection.",
    Connecting = "Connecting... Please wait while we process your connection.",
    ReconnectingAfterCrash = "You reconnected after a crash, providing you with higher priority.",
    ReconnectingAfterLeave = "You reconnected after leaving, providing you with slight priority boost."
}

-- Adaptive Card Configuration
Config.AdaptiveCard = {
    Title = "Flight Update",
    Flight = "FIVEM001",  -- Default flight number
    Gate = "A1",          -- Default gate
    SeatPrefix = "Queue", -- Prefix for seat display
    DepartureTime = "6:00AM",
    ArrivalTime = "4:00PM",
    PlaneIconUrl = "https://adaptivecards.io/content/airplane.png", -- URL for the plane icon
    FlightStatus = {
        Boarding = "Boarding",
        Delayed = "Delayed"
    },
    ButtonLabels = {
        Continue = "Continue",
        Cancel = "Cancel"
    }
}

-- Whitelist Configuration
Config.Whitelist = {
    -- Example: ['license:abcd1234'] = true
}

-- Priority List (Static)
Config.PriorityList = {
    -- Example: ['license:abcd1234'] = 10
}

-- Developer Mode
Config.DeveloperMode = true -- Set to true to simulate the queue being full
Config.DevQueueSize = 125   -- Number of players to simulate in the queue when in developer mode
