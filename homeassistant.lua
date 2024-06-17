
local pretty = require("cc.pretty")

local home_assistant = {}

local ws = nil
local interaction_id = 0

function home_assistant.connect(host, token)
    local url = "wss://" .. host .. "/api/websocket"

    -- local ws = assert(http.websocket(url))
    local sock, err = http.websocket(url)
    if not sock then
        local color_before = term.getTextColor()
        term.setTextColor(colors.red)
        print("Failed to connect to Home Assistant: " .. err)
        term.setTextColor(color_before)
        ws = nil
        return
    end

    ws = sock

    value = sock.receive()
    resp, err = textutils.unserializeJSON(value)
    if not resp then
        local color_before = term.getTextColor()
        term.setTextColor(colors.red)
        print("Failed to parse JSON: " .. err)
        term.setTextColor(color_before)
        ws = nil
        return
    end

    if resp.type == "auth_required" then
        sock.send(textutils.serializeJSON({type = "auth", access_token = token}))
    end

    value = sock.receive()
    resp, err = textutils.unserializeJSON(value)
    if not resp then
        local color_before = term.getTextColor()
        term.setTextColor(colors.red)
        print("Failed to parse JSON: " .. err)
        term.setTextColor(color_before)
        ws = nil
        return
    end

    if resp.type == "auth_ok" then
        local color_before = term.getTextColor()
        term.setTextColor(colors.green)
        print("Successfully connected to Home Assistant, running version " .. resp.ha_version)
        term.setTextColor(color_before)
    else -- if resp.type == "auth_invalid" then
        local color_before = term.getTextColor()
        term.setTextColor(colors.red)
        print("Failed to authenticate with Home Assistant: " .. resp.message)
        term.setTextColor(color_before)
        ws = nil
        return
    end
end

function home_assistant.disconnect()
    if ws then
        ws.close()
        ws = nil
        local color_before = term.getTextColor()
        term.setTextColor(colors.green)
        print("Disconnected from Home Assistant")
        term.setTextColor(color_before)
    end
end

-- success = false, error.code = not found, error.message = ...

function home_assistant.call_service(domain, service, target, data)
    if not ws then
        local color_before = term.getTextColor()
        term.setTextColor(colors.red)
        print("Not connected to Home Assistant")
        term.setTextColor(color_before)
        return
    end

    interaction_id = interaction_id + 1
    ws.send(textutils.serializeJSON({id = interaction_id, type = "call_service", domain = domain, service = service, target = target, service_data = data}))

    local value = ws.receive()
    pretty.pretty_print(value)
    local resp, err = textutils.unserializeJSON(value)
    if not resp then
        local color_before = term.getTextColor()
        term.setTextColor(colors.red)
        print("Failed to parse JSON: " .. err)
        term.setTextColor(color_before)
        return
    end

    if resp.id == interaction_id then
        return resp.result
    end
end

return home_assistant
