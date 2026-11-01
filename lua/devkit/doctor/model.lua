local M = {}
local statuses = { OK = true, WARNING = true, ERROR = true, SKIPPED = true }
function M.result(check, status, reason, values)
    assert(statuses[status], "Invalid diagnostic status")
    return { id = check.id, category = check.category, name = check.name, status = status,
        reason = reason, values = values or {}, what = check.what, why = check.why, fix = check.fix }
end
function M.describe(result, platform)
    local text = require("devkit.doctor.text")
    return { id = result.id, category = text.get(result.category), name = text.pair(result.name),
        status = text.get(result.status), explanation = text.get(result.reason, unpack(result.values)),
        what = text.pair(result.what), why = text.pair(result.why),
        recommendation = require("devkit.doctor.advice").get(result.fix, platform, result.status) }
end
function M.count(results)
    local count = { OK = 0, WARNING = 0, ERROR = 0, SKIPPED = 0, complete = 0 }
    for _, result in pairs(results) do count[result.status] = count[result.status] + 1; count.complete = count.complete + 1 end
    return count
end
return M
