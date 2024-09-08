package.path = package.path .. ";lua/?.lua"

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

-- Load message types
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
    else
        client:sendDisconnect(CLIENT_DISCONNECT_GENERIC, string.format("Unknown message type: %d", msgType), true)
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
    accountType = "Administrator"

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

            loginAccount(client, fields, accountId, playToken, openChat, isPaid, dislId, linkedToParent, accountType, speedChatPlus)
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

            loginAccount(client, account, accountId, playToken, openChat, isPaid, dislId, linkedToParent, accountType, speedChatPlus)
        end)
    end
end

function loginAccount(client, account, accountId, playToken, openChat, isPaid, dislId, linkedToParent, accountType, speedChatPlus)
    -- TODO
end
