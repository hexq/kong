local helpers = require "spec.helpers"
local cjson = require "cjson"

local ORDERS = {
  PREFIX = "orders",
  PORT = 8000
}

local INVOICES = {
  PREFIX = "invoices",
  PORT = 7000
}

local REWRITE = "x-mesh-rewrite"
local ACCESS = "x-mesh-access"

describe("Service Mesh", function()
  local orders_client, invoices_client

  setup(function()
    local bp = helpers.get_db_utils()

    local service1 = bp.services:insert{
      name = "orders",
      protocol = "http",
      port     = ORDERS.PORT,
      host     = "127.0.0.1",
    }

    bp.routes:insert {
      hosts      = { "orders.srv" },
      service    = service1,
      preserve_host = true
    }

    local service2 = bp.services:insert{
      name = "invoices",
      protocol = "http",
      port     = INVOICES.PORT,
      host     = "127.0.0.1",
    }

    bp.routes:insert {
      hosts      = { "invoices.srv" },
      service    = service2,
      preserve_host = true
    }

    bp.plugins:insert {
      name   = "mesh",
      config = {}
    }

    -- Start Orders (Kong + Service)
    assert(helpers.start_kong({
      prefix = ORDERS.PREFIX,
      nginx_conf = "spec/fixtures/mesh/orders.template",
      proxy_listen = "127.0.0.1:"..ORDERS.PORT,
      admin_listen = "127.0.0.1:9000",
      service_mesh = "on",
      service_name = "orders",
      service_sidecar_port = 5000,
      custom_plugins = "mesh"
    }))

    -- Start Invoices (Kong + Service)
    assert(helpers.start_kong({
      prefix = INVOICES.PREFIX,
      nginx_conf = "spec/fixtures/mesh/invoices.template",
      proxy_listen = "127.0.0.1:"..INVOICES.PORT,
      admin_listen = "off",
      service_mesh = "on",
      service_name = "invoices",
      service_sidecar_port = 4000,
      custom_plugins = "mesh"
    }))

    orders_client = helpers.http_client("127.0.0.1", ORDERS.PORT)
    invoices_client = helpers.http_client("127.0.0.1", INVOICES.PORT)
  end)

  teardown(function()
    if orders_client then
      orders_client:close()
    end
    if invoices_client then
      invoices_client:close()
    end

    helpers.stop_kong(ORDERS.PREFIX)
    helpers.stop_kong(INVOICES.PREFIX)
  end)

  it("consumes invoices from orders", function()
    local res = assert(orders_client:send {
      method  = "GET",
      path    = "/",
      headers = {
        ["Host"] = "invoices.srv"
      }
    })

    local body = cjson.decode(assert.res_status(200, res))
    assert.equals("invoices", body.service)

    -- Check that plugins are executed on the receiving end
    assert.equals(ORDERS.PORT, tonumber(body.req_headers[REWRITE]))
    assert.equals(INVOICES.PORT, tonumber(body.req_headers[ACCESS]))
  end)

end)
