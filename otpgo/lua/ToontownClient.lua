package.path = package.path .. ";lua/?.lua"

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
end
