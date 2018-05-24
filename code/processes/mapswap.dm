/process/mapswap
	// map = required players
	var/list/maps = list(
		MAP_CITY = 0,
		MAP_FOREST = 0,
		MAP_PILLAR = 0)
	var/ready = TRUE
	var/admin_triggered = FALSE
	var/finished_at = -1
	var/next_map_title = "City"

/process/mapswap/setup()
	name = "mapswap"
	schedule_interval = 50 // every 5 seconds
	start_delay = 50
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	processes.mapswap = src

/process/mapswap/fire()
	// no SCHECK here
	if (is_ready())
		ready = FALSE
		vote.initiate_vote("map", "MapSwap Process", TRUE, list(src, "swap"))

/process/mapswap/proc/is_ready()
	. = FALSE

	if (ready)
		if (admin_triggered)
			. = TRUE
		// 60 minutes have passed
		else if (ticks >= 720)
			. = TRUE
		// round will end in 5 minutes or less
		else if (map && map.next_win_time() <= 3 && map.next_win != -1)
			. = TRUE
		else if (map && map.admins_triggered_roundend)
			. = TRUE
		else if (ticker.finished)
			. = TRUE
	return .

/process/mapswap/proc/swap(var/winner = "City")
	next_map_title = winner
	winner = uppertext(winner)
	if (!maps.Find(winner))
		winner = maps[1]
	if (!processes.python.execute("mapswap.py", list(winner)))
		log_debug("Failed to swap the map! mapswap.py must have broke.")