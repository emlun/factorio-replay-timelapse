function set_timeout (ticks, callback)
  local count = 0
  script.on_event(
    defines.events.on_tick,
    function (event)
      count = count + 1
      if count == ticks then
        script.on_event(defines.events.on_tick, nil)
        callback()
      end
    end
  )
end

function record_technologies(and_then)
  game.print("Recording technologies...")

  local techs = game.get_filtered_technology_prototypes{{filter = "enabled"}}

  local force = game.players[1].force
  force.research_queue_enabled = true

  local tech_names = {}
  for name, _ in pairs(techs) do
    table.insert(tech_names, name)
  end

  force.research_queue = { tech_names[1] }
  local i = 0
  local screenshot_done = false

  return function (event)
      if event.tick % 4 == 0 then
        if force.current_research then
          game.take_screenshot{
            path = string.format("research-timelapse/technology/%s.png", force.current_research.name),
            show_gui = true,
            force_render = true,
          }
          table.remove(tech_names, i + 1)
          screenshot_done = true
        end

      elseif event.tick % 4 == 2 then
        if force.current_research then
          if screenshot_done then
            force.research_progress = 1
            screenshot_done = false
          end
        else
          if #tech_names > 0 then
            i = (i + 1) % #tech_names
            force.research_queue = { tech_names[i + 1] }
          else
            script.on_nth_tick(2, nil)
            game.print("Done recording technologies!")

            if and_then then
              and_then()
            end
          end
        end
      end
  end
end

function record_progress(and_then)
  return function(event)
    game.print("Recording research progress...")

    local last_p = -1
    local take_next_screenshot = false
    local force = game.players[1].force

    if force.current_research then
      force.research_progress = 0
    end
    force.technologies["automation"].researched = false
    force.research_queue = { "automation" }
    force.research_progress = 0

    local record = function (event)
      if force.current_research then
        local p = math.floor(force.research_progress * 1000)
        if take_next_screenshot then
          game.take_screenshot{
            path = string.format("research-timelapse/progress-bar/progress-%04d.png", p),
            show_gui=true,
            force_render=true,
          }
          take_next_screenshot = false
          last_p = p
        elseif p ~= last_p then
          take_next_screenshot = true
        else
          force.research_progress = math.min(1, force.research_progress + 0.0004)
        end
      end
    end

    set_timeout(
      5,
      function ()
        script.on_nth_tick(2, record)
      end
    )

    script.on_event(
      defines.events.on_research_finished,
      function (event)
        set_timeout(
          1,
          function()
            game.take_screenshot{
              path = "research-timelapse/progress-bar/progress-1000.png",
              show_gui=true,
              force_render=true,
            }
            game.print("Done recording progress!")
            script.on_nth_tick(2, nil)
            script.on_event(defines.events.on_research_finished, nil)
            if and_then then
              and_then()
            end
          end
        )
      end
    )
  end
end

return {
  run = function ()
    script.on_nth_tick(
      2,
      record_technologies(
        record_progress(
          function ()
            game.set_game_state{
              game_finished = true,
              player_won = true,
              can_continue = false,
            }
          end
        )
      )
    )
  end,
}
