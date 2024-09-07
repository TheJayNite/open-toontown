package.path = package.path .. ";lua/?.lua"

function receiveDatagram(client, dgi)
    msgType = dgi:readUint16()
	print(msgType)
end
