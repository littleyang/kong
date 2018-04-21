local helpers = require "spec.helpers"
local constants = require "kong.constants"

describe(constants.HEADERS.UPSTREAM_STATUS .. " header", function()
  local client

  setup(function()
    local bp = helpers.get_db_utils()
    assert(helpers.dao:run_migrations())

    local service = bp.services:insert {
      host = helpers.mock_upstream_host,
      port = helpers.mock_upstream_port,
      protocol = helpers.mock_upstream_protocol,
    }
    assert(service)

    local route1 = bp.routes:insert {
      protocols = { "http" },
      service = service,
      paths = { "/foo" },
    }
    assert(route1)

    local route2 = bp.routes:insert {
      protocols = { "http" },
      service = service,
      paths = { "/bar" },
    }
    assert(route2)

    bp.plugins:insert({
      name = "dummy",
      route_id = route2.id,
      config = {
        resp_code = 500,
      }
    })
  end)


  describe("should be same as upstream status code", function()
    setup(function()
      assert(helpers.start_kong {
        headers = "server_tokens,latency_tokens,x-kong-upstream-status",
        custom_plugins = "dummy",
        nginx_conf = "spec/fixtures/custom_nginx.template",
      })
      client = helpers.proxy_client()
    end)

    teardown(function()
      if client then
        client:close()
      end
      helpers.stop_kong(nil, nil, true)
    end)

    it("when no plugin changes status code", function()
      local res = assert(client:send {
        method  = "GET",
        path    = "/foo",
        headers = {
          host = helpers.mock_upstream_host,
        }
      })
      assert.res_status(200, res)
      assert.equal('200', res.headers[constants.HEADERS.UPSTREAM_STATUS])
    end)

    it("when a plugin changes status code", function()
      local res = assert(client:send {
        method  = "GET",
        host = helpers.mock_upstream_host,
        path    = "/bar",
        headers = {
          ["Host"]  = helpers.mock_upstream_host,
        }
      })
      assert.res_status(500, res)
      assert.equal('200', res.headers[constants.HEADERS.UPSTREAM_STATUS])
    end)
  end)

  describe("is not injected with default configuration", function()
    setup(function()
      assert(helpers.start_kong{
        nginx_conf = "spec/fixtures/custom_nginx.template",
      })
    end)

    teardown(function()
      if client then
        client:close()
      end
      helpers.stop_kong(nil, nil, true)
    end)

    it("", function()
      local client = helpers.proxy_client()
      local res = assert(client:send {
        method  = "GET",
        path    = "/foo",
        headers = {
          host = helpers.mock_upstream_host,
        }
      })
      assert.res_status(200, res)
      assert.is_nil(res.headers[constants.HEADERS.UPSTREAM_STATUS])
    end)
  end)

  describe("is injected with configuration [headers=X-Kong-Upstream-Status]", function()

    setup(function()
      assert(helpers.start_kong{
        nginx_conf = "spec/fixtures/custom_nginx.template",
        headers="X-Kong-Upstream-Status",
      })
    end)

    teardown(function()
      if client then
        client:close()
      end
      helpers.stop_kong(nil, nil, true)
    end)

    it("", function()
      local client = helpers.proxy_client()
      local res = assert(client:send {
        method  = "GET",
        path    = "/foo",
        headers = {
          host = helpers.mock_upstream_host,
        }
      })
      assert.res_status(200, res)
      assert('200', res.headers[constants.HEADERS.UPSTREAM_STATUS])
    end)
  end)
end)
