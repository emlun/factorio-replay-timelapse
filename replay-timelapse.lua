-- Output settings
local resolution = {x = 1920, y = 1080}  -- Output image resolution (1080p)
--local resolution = {x = 3840, y = 2160}  -- Output image resolution (4k)
local framerate = 30                     -- Timelapse frames per second
local speedup = 300                      -- Game seconds per timelapse second
local capture_gui = false                -- If true, also save screenshots with GUI

local output_dir = "replay-timelapse"    -- Output directory (relative to Factorio script output directory)
local screenshot_filename_pattern = output_dir .. "/%08d-replay.png"
local gui_screenshot_filename_pattern = output_dir .. "/%08d-gui.png"
local research_progress_filename = output_dir .. "/research-progress.csv"
local research_finished_filename = output_dir .. "/research-finish.csv"

-- Camera movement parameters
local min_zoom = 0.03125 * 4             -- Min zoom level (widest field of view)
local max_zoom = 0.5                     -- Max zoom level (narrowest field of view)
local margin_fraction = 0.05             -- Fraction of screen to leave as margin on each edge
local shrink_threshold = 0.75            -- Shrink base boundary when base width or height is less than this fraction of it
local shrink_delay_s = 3                 -- Seconds to wait since last boundary expansion before shrinking base boundary
local shrink_time_s = 2                  -- Seconds to complete a boundary shrink
local shrink_abort_transition_s = 1      -- Seconds of smooth transition after aborting a shrink
local recently_built_seconds = 2         -- When at minimum zoom, track buildings built in the last this many seconds
local base_bbox_lerp_step = 0.35         -- Exponential approach factor for base boundary tracking
local camera_lerp_step = 0.35            -- Exponential approach factor for camera movement


-- Game constants
local tick_per_s = 60
local tile_size_px = 32
local min_zoom_hard = 0.03125            -- Minimum zoom allowed by the game

-- Derived parameters
local resolution_correction = math.max(resolution.x / 1920, resolution.y / 1080)
min_zoom = math.max(min_zoom_hard, min_zoom * resolution_correction)
max_zoom = max_zoom * resolution_correction
local nth_tick = tick_per_s * speedup / framerate
local recently_built_ticks = recently_built_seconds * tick_per_s * speedup
local margin_expansion_factor = 1 + (2 * margin_fraction)
local shrink_delay_ticks = shrink_delay_s * tick_per_s * speedup
local shrink_time_ticks = shrink_time_s * tick_per_s * speedup
local shrink_abort_recovery_ticks = shrink_abort_transition_s * tick_per_s * speedup


-- Return the bounding box of an entity.
function entity_bbox(entity)
  return {
    l = entity.bounding_box.left_top.x,
    r = entity.bounding_box.right_bottom.x,
    t = entity.bounding_box.left_top.y,
    b = entity.bounding_box.right_bottom.y,
  }
end

-- Compute the smallest bounding box containing the union of two bounding boxes.
function expand_bbox(bbox_a, bbox_b)
  return {
    l = math.floor(math.min(bbox_a.l, bbox_b.l or bbox_a.l)),
    r = math.ceil(math.max(bbox_a.r, bbox_b.r or bbox_a.r)),
    t = math.floor(math.min(bbox_a.t, bbox_b.t or bbox_a.t)),
    b = math.ceil(math.max(bbox_a.b, bbox_b.b or bbox_a.b)),
  }
end

-- Linearly interpolate between two bounding boxes.
-- t: Interpolation factor in the interval [0, 1]
function lerp_bbox(bbox_a, bbox_b, t)
  local s = 1 - t
  return {
    l = s * bbox_a.l + t * bbox_b.l,
    r = s * bbox_a.r + t * bbox_b.r,
    t = s * bbox_a.t + t * bbox_b.t,
    b = s * bbox_a.b + t * bbox_b.b,
  }
end

-- Linearly interpolate only the x axis between two bounding boxes.
-- t: Interpolation factor in the interval [0, 1]
function lerp_bbox_x(bbox_a, bbox_b, t)
  local s = 1 - t
  return {
    l = s * bbox_a.l + t * bbox_b.l,
    r = s * bbox_a.r + t * bbox_b.r,
    t = bbox_a.t,
    b = bbox_a.b,
  }
end

-- Linearly interpolate only the y axis between two bounding boxes.
-- t: Interpolation factor in the interval [0, 1]
function lerp_bbox_y(bbox_a, bbox_b, t)
  local s = 1 - t
  return {
    l = bbox_a.l,
    r = bbox_a.r,
    t = s * bbox_a.t + t * bbox_b.t,
    b = s * bbox_a.b + t * bbox_b.b,
  }
end

-- Linear interpolation between two numbers
-- t: Interpolation factor in the interval [0, 1]
function lerp(a, b, t)
  return (1 - t) * a + t * b
end

-- Sinusoidal interpolation between two numbers
-- t: Interpolation parameter in the interval [0, 1]
function sirp(t)
  return (math.sin((t - 0.5) * math.pi) + 1) / 2
end

-- Linear interpolation between two cameras
-- t: Interpolation factor in the interval [0, 1]
-- Position and zoom are interpolated, desired zoom is taken from camera_b.
function lerp_camera(camera_a, camera_b, t)
  local s = 1 - t
  return {
    position = {
      x = s * camera_a.position.x + t * camera_b.position.x,
      y = s * camera_a.position.y + t * camera_b.position.y,
    },
    zoom = s * camera_a.zoom + t * camera_b.zoom,
    desired_zoom = camera_b.desired_zoom,
  }
end

-- Compute the smallest bounding box containing the union
-- of a list of lists of bounding boxes.
-- bboxess: list of lists of bounding boxes
function bbox_union_flattened(bboxess)
  local result = {}
  for _, bboxes in ipairs(bboxess) do
    for _, bbox in ipairs(bboxes) do
      result = expand_bbox(bbox, result)
    end
  end
  return result
end

-- Compute the smallest bounding box covering all of the player's buildings.
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

-- Compute a camera view centered on and zoomed out (as far as allowed) to cover a bounding box.
function compute_camera(bbox)
  local center = { x = (bbox.l + bbox.r) / 2, y = (bbox.t + bbox.b) / 2 }

  local w_tile = bbox.r - bbox.l
  local h_tile = bbox.b - bbox.t

  local w_px = w_tile * tile_size_px * margin_expansion_factor
  local h_px = h_tile * tile_size_px * margin_expansion_factor

  local desired_zoom = math.min(1, resolution.x / w_px, resolution.y / h_px)
  local zoom = math.min(max_zoom, math.max(min_zoom, desired_zoom))

  return {
    position = center,
    zoom = zoom,
    desired_zoom = desired_zoom,
  }
end

-- Compute a new camera with the same settings but a displaced position.
function translate_camera(camera, dxy)
  return {
    position = {
      x = camera.position.x + dxy.x,
      y = camera.position.y + dxy.y,
    },
    zoom = camera.zoom,
    desired_zoom = camera.desired_zoom,
  }
end

-- Add margins to a bounding box.
function marginize_bbox(bbox)
  if bbox.l ~= nil then
    local x = (bbox.r + bbox.l) / 2
    local y = (bbox.b + bbox.t) / 2
    local half_w = (bbox.r - bbox.l) * margin_expansion_factor / 2
    local half_h = (bbox.b - bbox.t) * margin_expansion_factor / 2

    return {
      l = x - half_w,
      r = x + half_w,
      t = y - half_h,
      b = y + half_h,
    }
  else
    return bbox
  end
end

-- Compute the bounding box for a camera's view.
function camera_bbox(camera)
  local f = 2 * camera.zoom * tile_size_px
  return {
    l = camera.position.x - resolution.x / f,
    r = camera.position.x + resolution.x / f,
    t = camera.position.y - resolution.y / f,
    b = camera.position.y + resolution.y / f,
  }
end

-- If the camera is larger than the bounding box, move the camera as little as
-- possible to cover the bounding box.
-- If the camera is smaller than the bounding box, move the camera as little as
-- possible to be within the bounding box.
-- This applies to each dimension independently.
function pan_camera_to_cover_bbox(camera, bbox)
  if bbox.l ~= nil then
    local cbb = camera_bbox(camera)
    local bbox_w = bbox.r - bbox.l
    local bbox_h = bbox.b - bbox.t
    local camera_w = cbb.r - cbb.l
    local camera_h = cbb.b - cbb.t

    if camera_w < bbox_w then
      if cbb.l < bbox.l then
        camera = translate_camera(camera, { x = bbox.l - cbb.l, y = 0 })
      elseif cbb.r > bbox.r then
        camera = translate_camera(camera, { x = bbox.r - cbb.r, y = 0 })
      end
    else
      if bbox.l < cbb.l then
        camera = translate_camera(camera, { x = bbox.l - cbb.l, y = 0 })
      elseif bbox.r > cbb.r then
        camera = translate_camera(camera, { x = bbox.r - cbb.r, y = 0 })
      end
    end

    cbb = camera_bbox(camera)

    if camera_h < bbox_h then
      if cbb.t < bbox.t then
        camera = translate_camera(camera, { x = 0, y = bbox.t - cbb.t })
      elseif cbb.b > bbox.b then
        camera = translate_camera(camera, { x = 0, y = bbox.b - cbb.b })
      end
    else
      if bbox.t < cbb.t then
        camera = translate_camera(camera, { x = 0, y = bbox.t - cbb.t })
      elseif bbox.b > cbb.b then
        camera = translate_camera(camera, { x = 0, y = bbox.b - cbb.b })
      end
    end
  end

  return camera
end

-- Compute an ffmpeg time duration expressing the given frame count.
function frame_to_timestamp(frame)
  s = math.floor(frame / framerate)
  m = math.floor(s / 60)
  h = math.floor(m / 60)
  f = frame % framerate
  s = s % 60
  m = m % 60
  return string.format("%02d:%02d:%02d:%02d", h, m, s, f)
end

-- Write CSV headers to the research progress files.
function init_research_csv()
  game.write_file(
    research_finished_filename,
    string.format("%s,%s,%s,%s,%s\n", "tick", "frame", "timestamp", "research_name", "research_localised_name"),
    false
  )
  game.write_file(
    research_progress_filename,
    string.format("%s,%s,%s,%s,%s,%s\n", "state", "tick", "frame", "timestamp", "research_name", "research_progress"),
    false
  )
end

function run()
  local bbox = { l = -30, r = 30, t = -30, b = 30 }
  local current_camera = compute_camera(bbox)
  local last_expansion = 0
  local last_expansion_bbox = bbox
  local recently_built_bboxes = {{}, {}, {}}
  local shrink_start_tick = nil
  local shrink_start_camera = nil
  local shrink_end_camera = nil
  local shrink_abort_tick = nil

  script.on_nth_tick(
    nth_tick,
    function(event)
      if event.tick == 0 then
        init_research_csv()
      end

      local base_bb = base_bbox()
      local expanded_bbox = expand_bbox(bbox, base_bb)
      if (expanded_bbox.l < last_expansion_bbox.l)
        or (expanded_bbox.r > last_expansion_bbox.r)
        or (expanded_bbox.t < last_expansion_bbox.t)
        or (expanded_bbox.b > last_expansion_bbox.b)
      then
        last_expansion = event.tick
        last_expansion_bbox = expanded_bbox
        if shrink_start_tick ~= nil then
          shrink_abort_tick = event.tick
        end
      end

      if base_bb.l ~= nil and shrink_start_tick == nil and (event.tick - last_expansion) >= shrink_delay_ticks then
        local target_bbox = bbox
        local shrinking = false
        if (base_bb.r - base_bb.l) / (bbox.r - bbox.l) < shrink_threshold then
          target_bbox = lerp_bbox_x(target_bbox, base_bb, 1)
          shrinking = true
        end
        if (base_bb.b - base_bb.t) / (bbox.b - bbox.t) < shrink_threshold then
          target_bbox = lerp_bbox_y(target_bbox, base_bb, 1)
          shrinking = true
        end

        if shrinking then
          shrink_start_tick = event.tick
          shrink_start_camera = current_camera
          shrink_end_camera = compute_camera(target_bbox)
          shrink_abort_tick = nil
          bbox = base_bb
        end
      else
        bbox = lerp_bbox(bbox, expanded_bbox, base_bbox_lerp_step)
      end

      local bbox_target_camera = compute_camera(bbox)
      if bbox_target_camera.desired_zoom < min_zoom then
        local recent_bbox = bbox_union_flattened(recently_built_bboxes)
        bbox_target_camera = pan_camera_to_cover_bbox(
          {
            position = current_camera.position,
            zoom = bbox_target_camera.zoom,
            desired_zoom = current_camera.zoom,
          },
          marginize_bbox(recent_bbox)
        )
      end

      local shrink_target_camera = nil
      if shrink_start_tick ~= nil then
        local shrink_tick = event.tick - shrink_start_tick
        if shrink_tick > shrink_time_ticks
          or (shrink_abort_tick ~= nil and event.tick - shrink_abort_tick >= shrink_abort_recovery_ticks)
        then
          shrink_start_tick = nil
          shrink_start_camera = nil
          shrink_end_camera = nil
          shrink_abort_tick = nil
          shrinking_w = false
          shrinking_h = false
        else
          shrink_target_camera = lerp_camera(
            shrink_start_camera,
            shrink_end_camera,
            sirp(shrink_tick / shrink_time_ticks)
          )
        end
      end

      local target_camera = bbox_target_camera
      if shrink_target_camera ~= nil and shrink_abort_tick ~= nil then
        target_camera = lerp_camera(
          shrink_target_camera,
          bbox_target_camera,
          sirp(math.min(1, (event.tick - shrink_abort_tick) / shrink_abort_recovery_ticks))
        )
      elseif shrink_target_camera ~= nil then
        target_camera = shrink_target_camera
      end
      current_camera = lerp_camera(current_camera, target_camera, camera_lerp_step)

      game.take_screenshot{
        surface = game.surfaces[1],
        position = current_camera.position,
        resolution = {resolution.x, resolution.y},
        zoom = current_camera.zoom,
        path = string.format(screenshot_filename_pattern, event.tick/event.nth_tick),
        show_entity_info = true,
        daytime = 0,
        allow_in_replay = true,
        anti_alias = true,
      }

      if capture_gui then
        game.take_screenshot{
          surface = game.surfaces[1],
          position = {0, 0},
          zoom = 1,
          path = string.format(gui_screenshot_filename_pattern, event.tick/event.nth_tick),
          show_entity_info = true,
          daytime = 0,
          allow_in_replay = true,
          show_gui = true,
          anti_alias = true,
        }
      end

      local force = game.players[1].force
      if force.current_research then
        local research = force.current_research
        game.write_file(
          research_progress_filename,
          string.format(
            "current,%s,%s,%s,%s,%s\n",
            event.tick,
            event.tick/nth_tick,
            frame_to_timestamp(event.tick/nth_tick),
            research.name,
            force.research_progress
          ),
          true
        )
      else
        game.write_file(
          research_progress_filename,
          string.format(
            "none,%s,%s,%s,,\n",
            event.tick,
            event.tick/nth_tick,
            frame_to_timestamp(event.tick/nth_tick)
          ),
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
        string.format(
          "%s,%s,%s,%s,",
          event.tick,
          event.tick/nth_tick,
          frame_to_timestamp(event.tick/nth_tick),
          event.research.name
        ),
        true
      )
      game.write_file(research_finished_filename, event.research.localised_name, true)
      game.write_file(research_finished_filename, "\n", true)
    end
  )

  script.on_event(
    defines.events.on_built_entity,
    function (event)
      local idx = (event.tick % recently_built_ticks) + 1
      recently_built_bboxes[idx] = recently_built_bboxes[idx] or {}
      table.insert(recently_built_bboxes[idx], entity_bbox(event.created_entity))
    end
  )

  script.on_event(
    defines.events.on_tick,
    function (event)
      local idx = ((event.tick + 1) % recently_built_ticks) + 1
      recently_built_bboxes[idx] = {}
    end
  )
end

return {
  run = run,
}
