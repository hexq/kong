-- a plugin fixture to test running of the rewrite phase handler.

local BasePlugin = require "kong.plugins.base_plugin"

local MeshRun = BasePlugin:extend()

MeshRun.PRIORITY = 1000

local REWRITE = "x-mesh-run-rewrite"
local ACCESS = "x-mesh-run-access"

local function set_header(name, value)
  if not ngx.req.get_headers()[name] then
    ngx.req.set_header(name, value)
  end
end

function MeshRun:new()
  MeshRun.super.new(self, "mesh-run")
end

function MeshRun:rewrite(conf)
  MeshRun.super.rewrite(self)

  set_header(REWRITE, ngx.var.server_port)
end

function MeshRun:access(conf)
  MeshRun.super.access(self)

  set_header(ACCESS, ngx.var.server_port)
end

return MeshRun
