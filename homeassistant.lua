
-- https://pinestore.cc/projects/69/logging-lib
local logging = require("logging")
logging.init(0, true, '')

local pretty = require("cc.pretty")

local home_assistant = {}

local ws = nil
local interaction_id = 0

function home_assistant.connect(host, token)
    local sock, err = http.websocket("wss://" .. host .. "/api/websocket")
    if not sock then
        logging.error("Failed to connect to Home Assistant: " .. err)
        return false
    end

    local value = sock.receive()
    local resp, err = textutils.unserializeJSON(value)
    if not resp then
        logging.error("Failed to parse JSON: " .. err)
        return false
    end

    if resp.type ~= "auth_required" then
        logging.error("Unexpected response: " .. resp)
        return false
    end

    -- Send auth message
    sock.send(textutils.serializeJSON({type = "auth", access_token = token}))

    local value = sock.receive()
    local resp, err = textutils.unserializeJSON(value)
    if not resp then
        logging.error("Failed to parse JSON: " .. err)
        return false
    end

    if resp.type == "auth_ok" then
        logging.info("Connected to Home Assistant, running version " .. resp.ha_version)
    else -- if resp.type == "auth_invalid" then
        logging.error("Failed to authenticate with Home Assistant: " .. resp.message)
        return false
    end

    ws = sock
    return true
end

function home_assistant.disconnect()
    if ws then
        ws.close()
        ws = nil
        logging.info("Disconnected from Home Assistant")
    end
end

-- success = false, error.code = not found, error.message = ...
-- success = false, error.code = invalid_format, error.message = ...

function home_assistant.call_service(domain, service, target, data)
    if not ws then
        logging.error("Not connected to Home Assistant")
        return
    end

    interaction_id = interaction_id + 1
    request = {
        id = interaction_id,
        type = "call_service",
        domain = domain,
        service = service,
        target = target,
        service_data = data
    }
    ws.send(textutils.serializeJSON(request))

    local value = ws.receive()
    local resp, err = textutils.unserializeJSON(value)
    if not resp then
        logging.error("Failed to parse JSON: " .. err)
        return
    end

    logging.debug("Message: " .. pretty.render(pretty.pretty(request)))
    logging.debug("Response: " .. pretty.render(pretty.pretty(resp)))

    if resp.id == interaction_id then
        return resp.result
    end
end

return home_assistant
