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
    else
        client:sendDisconnect(CLIENT_DISCONNECT_GENERIC, string.format("Unknown message type: %d", msgType), true)
    end
end
