/process/lighting_sources

/process/lighting_sources/setup()
	name = "lighting sources process"
	schedule_interval = 1 // every 1/10th second
	start_delay = 10
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_HIGH
	processes.lighting_sources = src

/process/lighting_sources/fire()

	for (current in lighting_update_lights)
		if (!isDeleted(current))

			var/datum/light_source/L = current
			. = L.check()
			if (L.destroyed || . || L.force_update)
				L.remove_lum()
				if (!L.destroyed)
					L.apply_lum()

			else if (L.vis_update)	// We smartly update only tiles that became (in) visible to use.
				L.smart_vis_update()

			L.vis_update   = FALSE
			L.force_update = FALSE
			L.needs_update = FALSE
			lighting_update_lights -= L
		else
			catchBadType(current)
			lighting_update_lights -= current

		PROCESS_TICK_CHECK

/process/lighting_sources/reset_current_list()
	return