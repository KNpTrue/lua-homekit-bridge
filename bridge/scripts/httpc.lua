local stream = require "stream"
local urlparser = require "url"
local tonumber = tonumber

---@class httpclib HTTP client library.
local M = {}

---@alias HTTPMethod
---| '"GET"'
---| '"POST"'
---| '"HEAD"'
---| '"OPTIONS"'
---| '"PUT"'
---| '"PATCH"'
---| '"DELETE"'

---@class HTTPClient:HTTPClientPriv HTTP client.
local client = {}

---Start a HTTP request.
---@param method HTTPMethod The request method.
---@param path string The request path.
---@param headers? table<string, string> The request headers.
---@param body? string|fun():string The request body.
---@return integer code The response status code.
---@return table<string, string> headers The response headers.
---@return string|fun():string|nil body The response body.
---@nodiscard
function client:request(method, path, headers, body)
    local sc = self.sc

    local chunked = false
    do
        headers = headers or {}
        if not headers.host then
            headers.host = self.host
        end
        if body then
            if type(body) == "function" then
                chunked = true
                headers["transfer-encoding"] = "chunked"
            else
                headers["content-length"] = #body
            end
        else
            headers["content-length"] = 0
        end
        sc:write(("%s %s HTTP/1.1\r\n"):format(method, path))
        for k, v in pairs(headers) do
            sc:write(("%s:%s\r\n"):format(k, v))
        end
        sc:write("\r\n")
    end

    if body then
        if chunked then
            while true do
                local chunk = body()
                if #chunk > 0 then
                    sc:write(("%X\r\n%s\r\n"):format(#chunk, chunk))
                else
                    sc:write("\r\n")
                    break
                end
            end
        else
            sc:write(body)
        end
    end

    do
        local line = sc:readline("\r\n", true)
        local code, _ = line:match("HTTP/[%d%.]+%s+([%d]+)%s+(.*)$")
        code = assert(tonumber(code))

        headers = {}
        while true do
            line = sc:readline("\r\n", true)
            if #line == 0 then
                break
            end
            local k, v = line:match("^(.-):%s*(.*)")
            headers[k:lower()] = v
        end

        local length = headers["content-length"]
        if length then
            length = tonumber(length)
        end

        local mode = headers["transfer-encoding"]
        if mode then
            if mode ~= "identity" and mode ~= "chunked" then
                error("unsupport transfer-encoding: " .. mode)
            end
        end
        if mode == "chunked" then
            return code, headers, function ()
                local line = sc:readline("\r\n", true)
                if #line == 0 then
                    return ""
                end
                local size = tonumber(line, 16)
                return sc:read(size, true)
            end
        end

        if length then
            return code, headers, sc:read(length, true)
        elseif code == 204 or code == 304 or code < 200 then
            return code, headers
        else
            return code, headers, sc:readall()
        end
    end
end

---Close the connection.
function client:close()
    self.sc:close()
end

---Connect to HTTP server and return a client.
---@param host string Server host name or IP address.
---@param port integer Remote port number, in host order.
---@param tls boolean Whether to enable SSL/TLS.
---@param timeout integer Timeout period (in milliseconds).
---@return HTTPClient client HTTP client.
---@nodiscard
function M.connect(host, port, tls, timeout)
    ---@class HTTPClientPriv:table
    local o = {
        host = host,
        timeout = timeout
    }
    local sc = stream.client(tls and "TLS" or "TCP", host, port, timeout)
    sc:settimeout(timeout)
    o.sc = sc

    return setmetatable(o, {
        __index = client,
        __close = client.close
    })
end

---Start a HTTP request and wait for the response back.
---@param method HTTPMethod The request method.
---@param url string URL string.
---@param timeout? integer Timeout period (in milliseconds).
---@param headers? table<string, string> The request headers.
---@param body? string|fun():string The request body.
---@return integer code The response status code.
---@return table<string, string> headers The response headers.
---@return string|nil body The response body.
---@nodiscard
function M.request(method, url, timeout, headers, body)
    local u = urlparser.parse(url)
    local host = u.host
    assert(type(host) == "string", "missing host in url")

    local port = u.port
    local scheme = u.scheme
    if not port and scheme then
        if scheme == "http" then
            port = 80
        elseif scheme == "https" then
            port = 443
        else
            error("invalid scheme: " .. scheme)
        end
    end
    port = port or 80

    local path = u.path or "/"
    if u.query then
        local query = tostring(u.query)
        if query ~= "" then
            path = path .. "?" .. query
        end
    end

    local hc <close> = M.connect(host, port, port == 443, timeout or 5000)
    local code
    code, headers, body = hc:request(method, path, headers, body)
    if type(body) == "function" then
        local content = ""
        while true do
            local bytes = body()
            if #bytes == 0 then
                break
            end
            content = content .. bytes
        end
        return code, headers, content
    end
    return code, headers, body
end

return M
