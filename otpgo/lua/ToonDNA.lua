NumToColor = {
    'White', 'Peach', 'Bright Red', 'Red', 'Maroon', 'Sienna', 'Brown', 'Tan',
    'Coral', 'Orange', 'Yellow', 'Cream', 'Citrine', 'Lime', 'Sea Green',
    'Green', 'Light Blue', 'Aqua', 'Blue', 'Periwinkle', 'Royal Blue',
    'Slate Blue', 'Purple', 'Lavender', 'Pink', 'Plum', 'Black'
}

AnimalToSpecies = {
    dog = 'Dog',
    cat = 'Cat',
    mouse = 'Mouse',
    horse = 'Horse',
    rabbit = 'Rabbit',
    duck = 'Duck',
    monkey = 'Monkey',
    bear = 'Bear',
    pig = 'Pig'
}

toonHeadTypes = {'dls',
 'dss',
 'dsl',
 'dll',
 'cls',
 'css',
 'csl',
 'cll',
 'hls',
 'hss',
 'hsl',
 'hll',
 'mls',
 'mss',
 'rls',
 'rss',
 'rsl',
 'rll',
 'fls',
 'fss',
 'fsl',
 'fll',
 'pls',
 'pss',
 'psl',
 'pll',
 'bls',
 'bss',
 'bsl',
 'bll',
 'sls',
 'sss',
 'ssl',
 'sll'}

toonHeadTypeToAnimalName = {
    d = 'dog',
    c = 'cat',
    m = 'mouse',
    h = 'horse',
    r = 'rabbit',
    f = 'duck',
    p = 'monkey',
    b = 'bear',
    s = 'pig'
}

-- DNA validation:
DNA_FIRST_CHAR = "t"
DNA_LENGTH = 15

DNA_MAX_HEAD_INDEX = 34
DNA_MAX_TORSO_INDEX = 9
DNA_MAX_LEG_INDEX = 3

DNA_MAX_SHIRTS = 151
DNA_MAX_CLOTHING_COLORS = 31
DNA_MAX_SLEEVES = 138

DNA_MAX_MALE_BOTTOMS = 58
DNA_MAX_FEMALE_BOTTOMS = 63

DNA_MAX_COLOR = 27

function isValidNetString(dnaString)
    local validDna = true

    local dg = datagram:new()
    dg:addString(dnaString)

    local _dgi = datagramiterator.new(dg)
    _dgi:readUint16() -- length, unused

    if _dgi:getRemainingSize() ~= DNA_LENGTH then
        validDna = false
    end

    if _dgi:readFixedString(1) ~= DNA_FIRST_CHAR then
        validDna = false
    end

    -- headIndex
    local headIndex = _dgi:readUint8()
    if headIndex >= DNA_MAX_HEAD_INDEX then
        validDna = false
    end

    -- torsoIndex
    if _dgi:readUint8() >= DNA_MAX_TORSO_INDEX then
        validDna = false
    end

    -- legsIndex
    if _dgi:readUint8() >= DNA_MAX_LEG_INDEX then
        validDna = false
    end

    -- gender
    local validForGender

    if _dgi:readUint8() == 1 then
        validForGender = DNA_MAX_MALE_BOTTOMS
    else
        validForGender = DNA_MAX_FEMALE_BOTTOMS
    end

    local topTex = _dgi:readUint8()
    local topTexColor = _dgi:readUint8()
    local sleeveTex = _dgi:readUint8()
    local sleeveTexColor = _dgi:readUint8()
    local botTex = _dgi:readUint8()
    local botTexColor = _dgi:readUint8()
    local armColor = _dgi:readUint8()
    local gloveColor = _dgi:readUint8()
    local legColor = _dgi:readUint8()
    local headColor = _dgi:readUint8()

    -- Shirts
    if topTex >= DNA_MAX_SHIRTS then
        validDna = false
    end

    -- ClothesColors
    if topTexColor >= DNA_MAX_CLOTHING_COLORS then
        validDna = false
    end

    -- Sleeves
    if sleeveTex >= DNA_MAX_SLEEVES then
        validDna = false
    end

    -- ClothesColors
    if sleeveTexColor >= DNA_MAX_CLOTHING_COLORS then
        validDna = false
    end

    if botTex >= validForGender then
        validDna = false
    end

    -- ClothesColors
    if botTexColor >= DNA_MAX_CLOTHING_COLORS then
        validDna = false
    end

    -- allColorsList
    if armColor >= DNA_MAX_COLOR then
        validDna = false
    end

    if gloveColor ~= 0 then
        validDna = false
    end

    if legColor >= DNA_MAX_COLOR then
        validDna = false
    end

    if headColor >= DNA_MAX_COLOR then
        validDna = false
    end

    local head = toonHeadTypes[headIndex + 1]
    return validDna, {headColor + 1, toonHeadTypeToAnimalName[head:sub(1, 1)]}
end
