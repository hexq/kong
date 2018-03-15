-- a plugin fixture to test running of the rewrite phase handler.

local BasePlugin = require "kong.plugins.base_plugin"

local Mesh = BasePlugin:extend()

Mesh.PRIORITY = 1000

local REWRITE = "x-mesh-rewrite"
local ACCESS = "x-mesh-access"

local function set_header(name, value)
  if not ngx.req.get_headers()[name] then
    ngx.req.set_header(name, value)
  end
end

function Mesh:new()
  Mesh.super.new(self, "mesh")
end

function Mesh:rewrite(conf)
  Mesh.super.rewrite(self)

  set_header(REWRITE, ngx.var.server_port)
end

function Mesh:access(conf)
  Mesh.super.access(self)

  set_header(ACCESS, ngx.var.server_port)
end

return Mesh
