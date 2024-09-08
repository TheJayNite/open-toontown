package.path = package.path .. ";lua/?.lua"

local date = require('date')

function table.shallow_copy(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end

-- Read vismap:
function readVismap()
    local json = require("json")
    local io = require("io")

    -- TODO: Custom path.
    f, err = io.open("config/vismap.json", "r")
    assert(not err, err)

    decoder = json.new_decoder(f)
    result, err = decoder:decode()
    f:close()
    assert(not err, err)
    return result
end

VISMAP = readVismap()
print("ToontownClient: Vismap successfully loaded.")

-- Read account bridge:
function readAccountBridge()
    local json = require("json")
    local io = require("io")

    -- TODO: Custom path.
    f, err = io.open("databases/accounts.json", "r")
    if err then
        print("ToontownClient: Returning empty table for account bridge")
        return {}
    end

    decoder = json.new_decoder(f)
    result, err = decoder:decode()
    f:close()
    assert(not err, err)
    print("ToontownClient: Account bridge successfully loaded.")
    return result
end

ACCOUNT_BRIDGE = readAccountBridge()

function saveAccountBridge()
    local json = require("json")
    local io = require("io")

    -- TODO: Custom path.
    f, err = io.open("databases/accounts.json", "w")
    assert(not err, err)
    encoder = json.new_encoder(f)
    err = encoder:encode(ACCOUNT_BRIDGE)
    assert(not err, err)
end

-- Load message types:
dofile("lua/MsgTypes.lua")

function receiveDatagram(client, dgi)
    -- Client received datagrams
    msgType = dgi:readUint16()

    if msgType == CLIENT_HEARTBEAT then
        client:handleHeartbeat()
    elseif msgType == CLIENT_DISCONNECT then
        client:handleDisconnect()
    elseif msgType == CLIENT_LOGIN_TOONTOWN then
        handleLoginToontown(client, dgi)
    -- We have reached the only message types unauthenticated clients can use.
    elseif not client:authenticated() then
        client:sendDisconnect(CLIENT_DISCONNECT_GENERIC, "First datagram is not CLIENT_LOGIN_TOONTOWN", true)
    elseif msgType == CLIENT_ADD_INTEREST then
        handleAddInterest(client, dgi)
    elseif msgType == CLIENT_REMOVE_INTEREST then
        client:handleRemoveInterest(dgi)
    else
        client:sendDisconnect(CLIENT_DISCONNECT_GENERIC, string.format("Unknown message type: %d", msgType), true)
    end

    if dgi:getRemainingSize() ~= 0 then
        client:sendDisconnect(CLIENT_DISCONNECT_OVERSIZED_DATAGRAM, string.format("Datagram contains excess data.\n%s", tostring(dgi)), true)
    end
end

function handleLoginToontown(client, dgi)
    local playToken = dgi:readString()
    local version = dgi:readString()
    local hash = dgi:readUint32()
    local tokenType = dgi:readInt32()
    local wantMagicWords = dgi:readString()

    if client:authenticated() then
        client:sendDisconnect(CLIENT_DISCONNECT_RELOGIN, "Authenticated client tried to login twice!", true)
        return
    end

    -- Check if version and hash matches
    if version ~= SERVER_VERSION then
        client:sendDisconnect(CLIENT_DISCONNECT_BAD_VERSION, string.format("Client version mismatch: client=%s, server=%s", version, SERVER_VERSION), true)
        return
    end

    if hash ~= DC_HASH then
        client:sendDisconnect(CLIENT_DISCONNECT_BAD_VERSION, string.format("Client DC hash mismatch: client=%d, server=%d", hash, DC_HASH), true)
        return
    end

    -- TODO: Make these configurable.
    local speedChatPlus = true
    local openChat = true
    local isPaid = true
    local dislId = 1
    local linkedToParent = false

    local accountId = ACCOUNT_BRIDGE[playToken]
    if accountId ~= nil then
        -- Query the account object
        client:getDatabaseValues(accountId, "Account", {"ACCOUNT_AV_SET", "CREATED", "LAST_LOGIN"}, function (doId, success, fields)
            if not success then
                client:sendDisconnect(CLIENT_DISCONNECT_ACCOUNT_ERROR, "The Account object was unable to be queried.", true)
                return
            end

            -- Update LAST_LOGIN
            fields.LAST_LOGIN = os.date("%a %b %d %H:%M:%S %Y")
            client:setDatabaseValues(accountId, "Account", {
                LAST_LOGIN = fields.LAST_LOGIN,
            })

            loginAccount(client, fields, accountId, playToken, openChat, isPaid, dislId, linkedToParent, speedChatPlus)
        end)
    else
        -- Create a new account object
        local account = {
            -- The rest of the values are defined in the dc file.
            CREATED = os.date("%a %b %d %H:%M:%S %Y"),
            LAST_LOGIN = os.date("%a %b %d %H:%M:%S %Y"),
        }

        client:createDatabaseObject("Account", account, DATABASE_OBJECT_TYPE_ACCOUNT, function (accountId)
            if accountId == 0 then
                client:sendDisconnect(CLIENT_DISCONNECT_ACCOUNT_ERROR, "The Account object was unable to be created.", false)
                return
            end

            -- Store the account into the bridge
            ACCOUNT_BRIDGE[playToken] = accountId
            saveAccountBridge()

            account.ACCOUNT_AV_SET = {0, 0, 0, 0, 0, 0}

            client:writeServerEvent("account-created", "ToontownClient", string.format("%d", accountId))

            loginAccount(client, account, accountId, playToken, openChat, isPaid, dislId, linkedToParent, speedChatPlus)
        end)
    end
end

function loginAccount(client, account, accountId, playToken, openChat, isPaid, dislId, linkedToParent, speedChatPlus)
    -- Eject other client if already logged in.
    local ejectDg = datagram:new()
    client:addServerHeaderWithAccountId(ejectDg, accountId, CLIENTAGENT_EJECT)
    ejectDg:addUint16(100)
    ejectDg:addString("You have been disconnected because someone else just logged in using your account on another computer.")
    client:routeDatagram(ejectDg)

    -- Subscribe to our puppet channel.
    client:subscribePuppetChannel(accountId, 3)

    -- Set our channel containing our account id
    client:setChannel(accountId, 0)

    client:authenticated(true)

    -- Store the account id and avatar list into our client's user table:
    local userTable = client:userTable()
    userTable.accountId = accountId
    userTable.avatars = account.ACCOUNT_AV_SET
    userTable.playToken = playToken
    userTable.isPaid = isPaid
    userTable.speedChatPlus = speedChatPlus
    userTable.openChat = openChat
    client:userTable(userTable)

    -- Log the event
    client:writeServerEvent("account-login", "ToontownClient", string.format("%d", accountId))

    -- Prepare the login response.
    local resp = datagram:new()
    resp:addUint16(CLIENT_LOGIN_TOONTOWN_RESP)
    resp:addUint8(0) -- Return code
    resp:addString("All Ok")
    resp:addUint32(dislId) -- accountNumber
    resp:addString(playToken) -- accountName
    resp:addUint8(1) -- accountNameApproved

    if openChat then
        resp:addString('YES') -- openChatEnabled, does not seem to be used
    else
        resp:addString('NO') -- openChatEnabled, does not seem to be used
    end

    resp:addString('YES') -- createFriendsWithChat
    resp:addString('YES') -- chatCodeCreationRule
    resp:addUint32(os.time()) -- sec
    resp:addUint32(os.clock()) -- usec

    if isPaid then
        resp:addString("FULL") -- access
    else
        resp:addString("VELVET") -- access
    end

    if speedChatPlus then
        resp:addString("YES") -- WhiteListResponse
    else
        resp:addString("NO") -- WhiteListResponse
    end

    resp:addString(os.date("%Y-%m-%d %H:%M:%S")) -- lastLoggedInStr
    resp:addInt32(math.floor(date.diff(account.LAST_LOGIN, account.CREATED):spandays())) -- accountDays

    if linkedToParent then
        resp:addString("WITH_PARENT_ACCOUNT") -- toonAccountType
    else
        resp:addString("NO_PARENT_ACCOUNT") -- toonAccountType
    end

    resp:addString(playToken) -- userName

    -- Dispatch the response to the client.
    client:sendDatagram(resp)
end

function handleAddInterest(client, dgi)
    local handle = dgi:readUint16()
    local context = dgi:readUint32()
    local parent = dgi:readUint32()
    local zones = {}
    while dgi:getRemainingSize() > 0 do
        local zone = dgi:readUint32()
        if zone == 1 then
            -- We don't want quiet zone.
            goto continue
        end

        table.insert(zones, zone)
        ::continue::
    end

    -- Replace street zone with vismap if exists
    if #zones == 1 then
        if VISMAP[tostring(zones[1])] ~= nil then
            zones = VISMAP[tostring(zones[1])]
        elseif zones[1] >= 22000 and zones[1] < 61000 then
            -- Handle Welcome Valley zones
            local welcomeValleyZone = zones[1]
            local hoodId = zones[1] - math.fmod(zones[1], 1000)
            local offset = math.fmod(welcomeValleyZone, 2000)
            -- Get original vismap
            if VISMAP[tostring(offset + 2000)] ~= nil then
                zones = table.shallow_copy(VISMAP[tostring(offset + 2000)])
                for i, v in ipairs(zones) do
                    local offset = math.fmod(zones[i], 2000)
                    zones[i] = offset + hoodId
                end
            end
        end
    end

    client:handleAddInterest(handle, context, parent, zones)
end
