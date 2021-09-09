local tick_per_s = 60
local speedup = 300
local framerate = 30
local nth_tick = tick_per_s * speedup / framerate
local tile_size_px = 32
local shrink_threshold = 0.75
local shrink_delay_s = 3
local shrink_time_s = 2
local margin_fraction = 0.05
local min_zoom = 0.03125
local resolution = {x = 1920, y = 1080}

local output_dir = "replay-timelapse"
local screenshot_filename_pattern = output_dir .. "/%08d-replay.png"
local research_progress_filename = output_dir .. "/research-progress.txt"
local research_finished_filename = output_dir .. "/research-finish.txt"

local shrink_delay_ticks = shrink_delay_s * tick_per_s * speedup
local shrink_time_ticks = shrink_time_s * tick_per_s * speedup

function entity_bbox(entity)
  return {
    l = entity.bounding_box.left_top.x,
    r = entity.bounding_box.right_bottom.x,
    t = entity.bounding_box.left_top.y,
    b = entity.bounding_box.right_bottom.y,
  }
end

function expand_bbox(bbox_a, bbox_b)
  return {
    l = math.floor(math.min(bbox_a.l, bbox_b.l or bbox_a.l)),
    r = math.ceil(math.max(bbox_a.r, bbox_b.r or bbox_a.r)),
    t = math.floor(math.min(bbox_a.t, bbox_b.t or bbox_a.t)),
    b = math.ceil(math.max(bbox_a.b, bbox_b.b or bbox_a.b)),
  }
end

function lerp_bbox(bbox_a, bbox_b, t)
  local s = 1 - t
  return {
    l = s * bbox_a.l + t * bbox_b.l,
    r = s * bbox_a.r + t * bbox_b.r,
    t = s * bbox_a.t + t * bbox_b.t,
    b = s * bbox_a.b + t * bbox_b.b,
  }
end

function sirp_bbox(bbox_a, bbox_b, t)
  return lerp_bbox(bbox_a, bbox_b, (math.sin((t - 0.5) * math.pi) + 1) / 2)
end

function base_bbox()
  local entities = game.surfaces[1].find_entities_filtered{force = "player"}
  local result = {}
  for _, entity in ipairs(entities) do
    if entity.type ~= "character" and entity.type ~= "car" and entity.name ~= "crash-site-spaceship" then
      result = expand_bbox(entity_bbox(entity), result)
    end
  end
  return result
end

function compute_camera(bbox, resolution, margin_fraction)
  local center = { x = (bbox.l + bbox.r) / 2, y = (bbox.t + bbox.b) / 2 }
  local aspect_ratio = 16/9

  local w_tile = bbox.r - bbox.l
  local h_tile = bbox.b - bbox.t

  local w_px = w_tile * tile_size_px
  local h_px = h_tile * tile_size_px

  local margin_expansion_factor = margin_fraction / (1 - margin_fraction)

  local w_margin_px = w_px + w_px * margin_expansion_factor
  local h_margin_px = h_px + h_px * margin_expansion_factor

  local zoom = math.min(1, resolution.x / w_margin_px, resolution.y / h_margin_px)

  return {
    position = center,
    resolution = resolution,
    zoom = zoom,
  }
end

function run()
  local bbox = { l = -30, r = 30, t = -30, b = 30 }
  local last_expansion = 0
  local last_expansion_bbox = bbox
  local shrink_start_tick = nil
  local shrink_end_tick = nil
  local shrink_start_bbox = nil

  script.on_nth_tick(
    nth_tick,
    function(event)
      local base_bb = base_bbox()
      local expanded_bbox = expand_bbox(bbox, base_bb)
      if (expanded_bbox.l < last_expansion_bbox.l
            or expanded_bbox.r > last_expansion_bbox.r
            or expanded_bbox.t < last_expansion_bbox.t
            or expanded_bbox.b > last_expansion_bbox.b)
      then
        last_expansion = event.tick
        last_expansion_bbox = expanded_bbox
        shrink_start_tick = nil
        shrink_end_tick = nil
        shrink_start_bbox = nil
      end
      bbox = lerp_bbox(bbox, expanded_bbox, 0.35)

      if base_bb.l ~= nil then
        local bbox_w = bbox.r - bbox.l
        local bbox_h = bbox.b - bbox.t
        local base_w = base_bb.r - base_bb.l
        local base_h = base_bb.b - base_bb.t

        if last_expansion ~= nil
          and (base_w < shrink_threshold * bbox_w or base_h < shrink_threshold * bbox_h)
          and event.tick - last_expansion >= shrink_delay_ticks
        then
          last_expansion = nil
          shrink_start_bbox = bbox
          shrink_start_tick = event.tick
          shrink_end_tick = shrink_start_tick + shrink_time_ticks
        end

        if shrink_start_tick ~= nil then
          if event.tick >= shrink_end_tick then
            shrink_start_tick = nil
            shrink_end_tick = nil
            shrink_start_bbox = nil
            bbox = base_bb
          else 
            bbox = sirp_bbox(shrink_start_bbox, base_bb, (event.tick - shrink_start_tick) / (shrink_end_tick - shrink_start_tick))
          end
        end
      end

      --log("base bbox: " .. serpent.line(base_bb))
      --log("bbox: " .. serpent.line(bbox))

      local camera = compute_camera(bbox, resolution, margin_fraction)

      game.take_screenshot{
        surface = game.surfaces[1],
        position = camera.position,
        resolution = {camera.resolution.x, camera.resolution.y},
        zoom = camera.zoom,
        path = string.format(screenshot_filename_pattern, event.tick/event.nth_tick),
        show_entity_info = true,
        daytime = 0,
        allow_in_replay = true,
      }

      local force = game.players[1].force
      if force.current_research then
        local research = force.current_research
        game.write_file(
          research_progress_filename,
          string.format("current %s %s %s %s\n", event.tick, event.tick/nth_tick, research.name, force.research_progress),
          true
        )
      else
        game.write_file(
          research_progress_filename,
          string.format("none %s %s\n", event.tick, event.tick/nth_tick),
          true
        )
      end
    end
  )

  script.on_event(
    defines.events.on_research_finished,
    function (event)
      game.write_file(
        research_finished_filename,
        string.format("%s %s %s ", event.tick, event.tick/nth_tick, event.research.name),
        true
      )
      game.write_file(research_finished_filename, event.research.localised_name, true)
      game.write_file(research_finished_filename, "\n", true)
    end
  )
end

return {
  run = run,
}
