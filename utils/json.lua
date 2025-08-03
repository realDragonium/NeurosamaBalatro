local json = {}

local function escape_str(s)
    return s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
end

local function skip_delim(str, pos, delim, err_if_missing)
    pos = pos + #str:match('^%s*', pos)
    if str:sub(pos, pos) ~= delim then
        if err_if_missing then
            error('Expected ' .. delim .. ' near position ' .. pos)
        end
        return pos, false
    end
    return pos + 1, true
end

local function parse_str_val(str, pos, val)
    val = val or ''
    local early_end_error = 'End of input found while parsing string.'
    if pos > #str then error(early_end_error) end
    local c = str:sub(pos, pos)
    if c == '"' then return val, pos + 1 end
    if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
    local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
    local nextc = str:sub(pos + 1, pos + 1)
    if not nextc then error(early_end_error) end
    return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

local function parse_num_val(str, pos)
    local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
    local val = tonumber(num_str)
    if not val then error('Error parsing number at position ' .. pos .. '.') end
    return val, pos + #num_str
end

local parse_json_val

local function parse_json_array(str, pos)
    local res, pos = {}, pos + 1
    pos = pos + #str:match('^%s*', pos)
    if str:sub(pos, pos) == ']' then return res, pos + 1 end
    local nil_pos = #res
    repeat
        nil_pos = nil_pos + 1
        res[nil_pos], pos = parse_json_val(str, pos)
        pos = pos + #str:match('^%s*', pos)
        local delim = str:sub(pos, pos)
        pos = pos + 1
        if delim == ']' then break end
        if delim ~= ',' then error('Delimiter error in array at position ' .. pos) end
        pos = pos + #str:match('^%s*', pos)
    until false
    return res, pos
end

local function parse_json_obj(str, pos)
    local res, pos = {}, pos + 1
    pos = pos + #str:match('^%s*', pos)
    if str:sub(pos, pos) == '}' then return res, pos + 1 end
    repeat
        local key, val
        pos = pos + #str:match('^%s*', pos)
        if str:sub(pos, pos) ~= '"' then
            error('Expected string key, got "' .. str:sub(pos, pos) .. '" at position ' .. pos)
        end
        key, pos = parse_str_val(str, pos + 1)
        pos = skip_delim(str, pos, ':', true)
        val, pos = parse_json_val(str, pos)
        res[key] = val
        pos = pos + #str:match('^%s*', pos)
        local delim = str:sub(pos, pos)
        pos = pos + 1
        if delim == '}' then break end
        if delim ~= ',' then error('Delimiter error in object at position ' .. pos) end
        pos = pos + #str:match('^%s*', pos)
    until false
    return res, pos
end

parse_json_val = function(str, pos)
    pos = pos + #str:match('^%s*', pos)
    local first = str:sub(pos, pos)
    if first == '{' then return parse_json_obj(str, pos)
    elseif first == '[' then return parse_json_array(str, pos)
    elseif first == '"' then return parse_str_val(str, pos + 1)
    elseif first == '-' or first:match('%d') then return parse_num_val(str, pos)
    elseif first == 't' then return true, pos + 4
    elseif first == 'f' then return false, pos + 5
    elseif first == 'n' then return nil, pos + 4
    else error('Invalid json syntax starting at position ' .. pos .. ': ' .. str:sub(pos, pos + 10))
    end
end

function json.decode(str)
    if type(str) ~= 'string' then
        error('Expected string, got ' .. type(str))
    end
    local res, pos = parse_json_val(str, 1)
    pos = pos + #str:match('^%s*', pos)
    if pos <= #str then
        error('Trailing content after JSON at position ' .. pos)
    end
    return res
end

function json.encode(val, indent)
    local function val_to_str(v, indent)
        local indent_str = indent and string.rep('  ', indent) or ''
        local next_indent = indent and (indent + 1) or nil
        
        if type(v) == 'string' then
            return '"' .. escape_str(v) .. '"'
        elseif type(v) == 'number' then
            return tostring(v)
        elseif type(v) == 'boolean' then
            return tostring(v)
        elseif type(v) == 'nil' then
            return 'null'
        elseif type(v) == 'table' then
            local is_array = true
            local max_index = 0
            for k, _ in pairs(v) do
                if type(k) ~= 'number' or k <= 0 or k ~= math.floor(k) then
                    is_array = false
                    break
                end
                max_index = math.max(max_index, k)
            end
            
            if is_array then
                local result = {}
                for i = 1, max_index do
                    table.insert(result, val_to_str(v[i], next_indent))
                end
                if indent then
                    return '[\n  ' .. indent_str .. table.concat(result, ',\n  ' .. indent_str) .. '\n' .. indent_str .. ']'
                else
                    return '[' .. table.concat(result, ',') .. ']'
                end
            else
                local result = {}
                for k, val in pairs(v) do
                    local key_str = '"' .. escape_str(tostring(k)) .. '"'
                    table.insert(result, key_str .. ':' .. (indent and ' ' or '') .. val_to_str(val, next_indent))
                end
                if indent then
                    return '{\n  ' .. indent_str .. table.concat(result, ',\n  ' .. indent_str) .. '\n' .. indent_str .. '}'
                else
                    return '{' .. table.concat(result, ',') .. '}'
                end
            end
        else
            error('Cannot encode value of type ' .. type(v))
        end
    end
    
    return val_to_str(val, indent and 0 or nil)
end

function json.safe_decode(str)
    local success, result = pcall(json.decode, str)
    if success then
        return result, nil
    else
        return nil, result
    end
end

function json.safe_encode(val, indent)
    local success, result = pcall(json.encode, val, indent)
    if success then
        return result, nil
    else
        return nil, result
    end
end

return json