local char = require "hap.char"

local lightbulb = {}

local logger = log.getLogger("lightbulb")
local inited = false

function lightbulb.isInited()
    return inited
end

function lightbulb.init()
    inited = true
    logger:info("Initialized.")
    return true
end

function lightbulb.deinit()
    inited = false
    logger:info("Deinitialized.")
end

local function checkAccessoryConf(conf)
    return true
end

local function lightBulbOnCharacteristic()
    return {
        format = "Bool",
        iid = hap.getNewInstanceID(),
        type = "On",
        props = {
            readable = true,
            writable = true,
            supportsEventNotification = true,
            hidden = false,
            requiresTimedWrite = false,
            supportsAuthorizationData = false,
            ip = { controlPoint = false, supportsWriteResponse = false },
            ble = {
                supportsBroadcastNotification = true,
                supportsDisconnectedNotification = true,
                readableWithoutSecurity = false,
                writableWithoutSecurity = false
            }
        },
        cbs = {
            read = function (request, context)
                logger:info(string.format("Read lightBulbOn: %s", context.lightBulbOn))
                return context.lightBulbOn, hap.Error.None
            end,
            write = function (request, value, context)
                local changed = false
                logger:info(string.format("Write lightBulbOn: %s", value))
                if value ~= context.lightBulbOn then
                    context.lightBulbOn = value
                    changed = true
                end
                return changed, hap.Error.None
            end
        }
    }
end

function lightbulb.gen(conf)
    if checkAccessoryConf(conf) == false then
        return nil
    end
    local state = {
        lightBulbOn = false,
    }
    return {
        aid = hap.getNewBridgedAccessoryID(),
        category = "BridgedAccessory",
        name = conf.name,
        mfg = "Acme",
        model = "LightBulb1,1",
        sn = conf.sn,
        fwVer = "1",
        hwVer = "1",
        services = {
            hap.AccessoryInformationService,
            hap.HapProtocolInformationService,
            hap.PairingService,
            {
                iid = hap.getNewInstanceID(),
                type = "LightBulb",
                name = "Light Bulb",
                props = {
                    primaryService = true,
                    hidden = false,
                    ble = {
                        supportsConfiguration = false,
                    }
                },
                chars = {
                    char.newServiceSignatureCharacteristic(),
                    char.newNameCharacteristic(),
                    lightBulbOnCharacteristic()
                }
            }
        },
        cbs = {
            identify = function (request, context)
                logger:info("Identify callback is called.")
                logger:info(string.format("transportType: %s, remote: %s.",
                    request.transportType, request.remote))
                return hap.Error.None
            end
        },
        context = state,
    }
end

return lightbulb
