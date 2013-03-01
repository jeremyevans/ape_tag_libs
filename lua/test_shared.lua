require('apetag')

ASSERTIONS = 0

--- String representation of table suitable for printing.
-- Gives outside similar to ruby's Hash#inspect.
-- @param t The table to print
-- @param l How many recursive levels to use (default 3)
-- @param p The parent table of the current table
-- @param gp The grandparent table of the current table
-- @return string
function table.print(t,level,p,gp)
    local typ = type(t)
    if typ == 'table' then
        local res = {}
        if type(level) == 'nil' then
            level = 3
        end
        if level < 0 then
            return tostring(t)
        end
        table.insert(res, '{')
        local first_item = true
        for k,v in pairs(t) do
            if first_item == false then
                table.insert(res, ', ')
            end
            table.insert(res, table.print(k, level - 1, t, p))
            table.insert(res, "=")
            if v == t then
                table.insert(res, '..')
            elseif p and v == p then
                table.insert(res, '...')
            elseif gp  and v == gp then
                table.insert(res, '....')
            else
                table.insert(res, table.print(v, level - 1, t, p))
            end
            first_item = false
        end
        table.insert(res, '}')
        return table.concat(res)
    elseif typ == 'string' then
        return string.format('%q', t)
    else
        return tostring(t)
    end
end

function table.equal(a,b)
    for k,v in pairs(a) do
        if b[k] ~= v then
            return false
        end
    end
    for k,v in pairs(b) do
        if a[k] ~= v then
            return false
        end
    end
    return true
end

function table.array_equals(a,b)
    for k,v in pairs(a) do
        if type(k) == 'number' and b[k] ~= v then
            return false
        end
    end
    for k,v in pairs(b) do
        if type(k) == 'number' and a[k] ~= v then
            return false
        end
    end
    return true
end

function assert_tables_equal(a, b)
    assert(table.equal(a,b), string.format("Tables not equal:\n%s\n%s", table.print(a), table.print(b)))
    ASSERTIONS = ASSERTIONS + 1
end

function assert_arrays_equal(a, b)
    assert(table.array_equals(a,b), string.format("Arrays not equal:\n%s\n%s", table.print(a), table.print(b)))
    ASSERTIONS = ASSERTIONS + 1
end

function assert_equal(a, b)
    assert(a == b, string.format("Values not equal:\n%q\n%q", tostring(a), tostring(b)))
    ASSERTIONS = ASSERTIONS + 1
end

function assert_error(f)
    r, f = pcall(f)
    assert(not r, 'No error occured')
    ASSERTIONS = ASSERTIONS + 1
end

function assert_no_error(f)
    r, reason = pcall(f)
    assert(r, reason)
    ASSERTIONS = ASSERTIONS + 1
end

function run_tests(filename)
    -- If called on the command line, run all tests
    if arg and string.find(arg[0], filename) then
        for i,f in pairs(TestApeTag) do
            ASSERTIONS = 0
            f()
            print(i, 'No errors, ' .. tostring(ASSERTIONS) .. ' assertions')
        end
    end
end
