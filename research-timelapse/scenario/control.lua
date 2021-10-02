local handler = require("event_handler")

local resource_gen = require("make-technology-screenshots")
script.on_event(
  defines.events.on_tick,
  function ()
    script.on_event(defines.events.on_tick, nil)
    resource_gen.run()
  end
)
