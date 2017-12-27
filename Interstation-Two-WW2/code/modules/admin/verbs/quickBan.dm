/* A simpler and more flexible code for banning, designed for SQLite. Its
 * not nearly as fancy as old banning, and it wasn't worth making an interface
 * for this rather small amount of code, so its all done via BYOND's input() */

/* this is a WIP, currently only server bans are supported */
var/list/ban_types = list("Job Ban", "Faction Ban", "Officer Ban", "Server Ban", "Observe Ban", "Playing Ban")

/* admin procedures */
/client/proc/quickBan_search()
	set category = "Bans"

	var/option = input(src, "Search for a ban?") in list("Yes", "No")
	if (option == "No")
		return

	var/_ckey = input(src, "What ckey will you search for? (optional)") as null|text
	var/cID = input(src, "What cID will you search for? (optional)") as null|text
	var/ip = input(src, "What address will you search for? (optional)") as null|text
	var/ban_type = input(src, "What type of ban do you want to search for?") in ban_types + "All"

	var/html = "<center><big>List of Quick Bans</big></center>"

	var/list/result = list()

	if (ban_type == "All")
		result = database.execute("SELECT * FROM quick_bans;", FALSE)
	else
		result = database.execute("SELECT * FROM quick_bans WHERE ban_type == '[ban_type]';", FALSE)

	var/list/possibilities = list()

	if (islist(result) && !isemptylist(result))
		for (var/v in 1 to 100)
			if (_ckey && result.Find("ckey_[v]") && result["ckey_[v]"] != _ckey)
				continue
			if (cID && result.Find("cID_[v]") && result["cID_[v]"] != cID)
				continue
			if (ip && result.Find("ip_[v]") && result["ip_[v]"] != ip)
				continue
			if (text2num(result["expire_realtime_[v]"]) <= world.realtime)
				database.execute("REMOVE * FROM quick_bans WHERE UID == '[result["UID_v"]]';")
				continue
			possibilities += "<big><b>UID [result["UID_v"]]</b> (<a href='byond://?src=\ref[src];quickBan_removeBan=1;quickBan_removeBan_UID=[result["UID_[v]"]];quickBan_removeBan_ckey=[result["ckey_[v]"]];quickBan_removeBan_cID=[result["cID_[v]"]];quickBan_removeBan_ip=[result["ip_[v]"]]'>DELETE</a>)</big>: [result["ckey"]]/[result["cID"]]/[result["ip"]], type [result["type"]] ([result["type_specific_info"]]): banned for '[result["reason"]]' by [result["banned_by"]] on [result["ban_date"]]. <b>[result["expire_info"]]</b>. (After assigned date)"

	for (var/possibility in possibilities)
		html += "<br>"
		html += possibility

	src << browse(html, "window=quick_bans_search;")

/client/Topic(href,href_list[],hsrc)
	..(href, href_list, hsrc)
	if (href_list["quickBan_removeBan"])
		var/UID = href_list["quickBan_removeBan_UID"]
		if (UID)
			var/confirm = input("Are you sure you want to remove the ban with the UID '[UID]' ?") in list("Yes", "No")
			if (confirm == "Yes")
				if (database.execute("REMOVE * FROM quick_bans WHERE UID == '[UID]';"))
					var/M = "[key_name(usr)] removed quickBan '<b>[UID]</b>' from the database. It belonged to [href_list["ckey"]]/[href_list["cID"]]/[href_list["ip"]]"
					log_admin(M)
					message_admins(M)

/client/proc/quickBan_person()
	set category = "Bans"

	var/option = input(src, "Do you wish to ban by client or by manual input? (Necessary to ban an offline client)") in list("Client", "Manual Input", "Cancel")
	if (option == "Cancel")
		return

	var/list/fields = list() // as much storage as we need

	if (option == "Manual Input")
		fields["ckey"] = input(src, "What is the person's ckey? (optional)") as null|text
		fields["cID"] = input(src, "What is the person's cID? (optional)") as null|text
		fields["ip"] = input(src, "What is the person's IP? (optional)") as null|text
	else if (option == "Client")
		var/client/C = input(src, "Which client?") in clients + "Cancel"
		if (C == "Cancel")
			return
		fields["ckey"] = C.ckey
		fields["cID"] = C.computer_id
		fields["ip"] = C.address

	fields["ckey"] = ckey(fields["ckey"])

	if (trying_to_quickBan_admin(fields["ckey"], fields["cID"], fields["ip"]))
		return

	fields["type"] = input(src, "What type of ban will this be?") in ban_types + "Cancel"
	if (fields["type"] == "Cancel")
		return

	fields["type"] = replacetext(fields["type"], " Ban", "")

	switch (fields["type"])
		if ("Job")
			var/list/possibilities = job_master.occupations
			var/datum/job/J = input("What job?") in possibilities
			fields["type_specific_info"] = J.title
		if ("Faction")
			var/faction = input("What faction?") in list(GERMAN, RUSSIAN, ITALIAN, UKRAINIAN, SCHUTZSTAFFEL, PARTISAN, CIVILIAN)
			fields["type_specific_info"] = faction

	reenter_bantime

	var/duration_in_x_units = input(src, "How long do you want the ban to last ('5 hours', '4 days': the default unit is days)") as text
	var/duration_in_days = text2num(ckey(splittext(duration_in_x_units, " ")[1]))

	if (!isnum(duration_in_days))
		src << "<span class = 'warning'>Invalid amount.</span>"
		goto reenter_bantime

	if (findtext(duration_in_x_units, "year"))
		duration_in_days *= 365
	else if (findtext(duration_in_x_units, "month"))
		duration_in_days *= 30
	else if (findtext(duration_in_x_units, "week"))
		duration_in_days *= 7
	else if (findtext(duration_in_x_units, "hour"))
		duration_in_days /= 24
	else if (findtext(duration_in_x_units, "minute"))
		duration_in_days /= 1440
	else if (findtext(duration_in_x_units, "second"))
		duration_in_days /= 86400
	else if (!findtext(duration_in_x_units, "day"))
		src << "<span class = 'warning'>Invalid unit.</span>"
		goto reenter_bantime

	var/duration_in_deciseconds = duration_in_days * 86400 * 10
	fields["expire_realtime"] = num2text(world.realtime + duration_in_deciseconds, 20)

	switch (duration_in_days)
		if (0 to 0.99) // count in hours
			fields["expire_info"] = "Expires in [duration_in_days*24] hour(s)"
		if (0.99 to 6.99) // count in days
			fields["expire_info"] = "Expires in [duration_in_days] day(s)"
		if (6.99 to 29.99) // count in weeks
			fields["expire_info"] = "Expires in [duration_in_days/7] week(s)"
		if (29.99 to 364.99) // count in months
			fields["expire_info"] = "Expires in [duration_in_days/30] month(s)"
		if (364.99 to INFINITY) // count in years
			fields["expire_info"] = "Expires in [duration_in_days/365] years(ss"

	if (global_game_schedule)
		fields["ban_date"] = global_game_schedule.getDateInfoAsString()

	fields["reason"] = input(src, "Provide a reason for the ban.") as text
	fields["banned_by"] = key

	quickBan_ban(fields, src)

/* helpers */
/proc/quickBan_sanitize_fields(var/list/fields)

	if (!fields.Find("ckey"))
		fields["ckey"] = "nil"
	if (!fields.Find("cID"))
		fields["cID"] = "nil"
	if (!fields.Find("ip") || fields["i"] == null) // host
		fields["ip"] = "nil"
	if (!fields.Find("type"))
		fields["type"] = "nil"
	if (!fields.Find("type_specific_info"))
		fields["type_specific_info"] = "nil"
	if (!fields.Find("UID"))
		fields["UID"] = database.newUID()
	if (!fields.Find("reason"))
		fields["reason"] = "nil"
	if (!fields.Find("banned_by"))
		fields["banned_by"] = "nil"
	if (!fields.Find("ban_date"))
		fields["ban_date"] = "nil"
	if (!fields.Find("expire_realtime"))
		fields["expire_realtime"] = "nil"
	if (!fields.Find("expire_info"))
		fields["expire_info"] = "nil"

	// sanitize user input
	for (var/x in fields)
		if (!istext(fields[x]))
			if (!isnum(fields[x]))
				fields[x] = "[fields[x]]"
			else
				fields[x] = num2text(fields[x], 20)
		if (x == "ckey" || x == "cID" || x == "ip")
			fields[x] = copytext(fields[x], 1, 51)
		else if (x == "reason")
			fields[x] = copytext(fields[x], 1, 151)
		fields[x] = sanitizeSQL(fields[x], 200)

	fields["test"] = "test"

/* the actual banning procedure */
/proc/quickBan_ban(var/list/fields, var/client/banner)

	quickBan_sanitize_fields(fields)

	var/ckey = fields["ckey"]
	var/cID = fields["cID"]
	var/ip = fields["ip"]
	var/expire_info = fields["expire_info"]
/*
	for (var/x in fields)
	//	world << "[x] = [fields[x]]"
		if (!istext(fields[x]))
	//		world << "ERROR! [x] is not a text field!!!!"

	if (database.execute("INSERT INTO qbans (ckey, cID, ip, type, UID, reason, banned_by, ban_date, expire_realtime) VALUES ('[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]');"))
	//	world << "Test #0 succeeded"

	if (database.execute("INSERT INTO qbans (ckey, cID, ip, type, UID, reason, banned_by, ban_date, expire_realtime) VALUES ('[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]');"))
	//	world << "Test #1 succeeded"

	if (database.execute("INSERT INTO quick_bans (ckey, cID, ip, type, UID, reason, banned_by, ban_date, expire_realtime) VALUES ('[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]');"))
	//	world << "Test #2 succeeded"
		*/
	if (database.execute("INSERT INTO quick_bans (ckey, cID, ip, type, type_specific_info, UID, reason, banned_by, ban_date, expire_realtime, expire_info) VALUES ('[fields["ckey"]]', '[fields["cID"]]', '[fields["ip"]]', '[fields["type"]]', '[fields["type_specific_info"]]', '[fields["UID"]]', '[fields["reason"]]', '[fields["banned_by"]]', '[fields["ban_date"]]', '[fields["expire_realtime"]]', '[fields["expire_info"]]');"))
		if (banner)
			banner << "<span class = 'notice'>You have successfully banned [ckey]/[cID]/[ip]. This ban [lowertext(expire_info)]."
		var/M = "[key_name(banner)] banned [ckey]/[cID]/[ip] (bantype = [fields["type"]]) for reason '[fields["reason"]]'. This ban [lowertext(expire_info)]."
		log_admin(M)
		message_admins(M)
		// kick whoever got banned if they're on
		if (lowertext(fields["type"]) == "server")
			for (var/client/C in clients)
				if (C.ckey == ckey)
					C.quickBan_kicked(fields["type"], fields["reason"])
	else
		if (banner)
			banner << "<span class = 'warning'>FAILED to ban [ckey]/[cID]/[ip]! A database error occured.</span>"

/* checking if we're banned & then reject us */
/client/proc/quickBan_isbanned(var/ban_type = "Server")
	var/list/bans = database.execute("SELECT * FROM quick_bans WHERE (ckey = '[ckey]' OR cID = '[computer_id]' OR ip = '[address]') AND type == '[ban_type]';", FALSE)
	if (islist(bans) && !isemptylist(bans))
		for (var/x in bans)
		//	world << "[x] = [bans[x]]"
			if (x == "expire_realtime" && text2num(bans[x]) <= world.realtime)
				database.execute("DELETE FROM quick_bans WHERE UID == '[bans["UID"]]';")
				continue
			if (x == "reason")
				if (bans.Find("expire_realtime") && text2num(bans["expire_realtime"]) <= world.realtime)
					database.execute("DELETE FROM quick_bans WHERE UID == '[bans["UID"]]';")
					continue
				return bans[x]
	return FALSE

/* check if we're banned and tell us why we're banned */
/client/proc/quickBan_rejected(var/bantype = "Server")
	var/banreason = quickBan_isbanned(bantype)
	if (banreason)
		src << "<span class = 'userdanger'>You're [lowertext(bantype)]-banned. Reason: '[banreason]'</span>"
		return TRUE
	return FALSE

/* kick us if we just got banned */
/client/proc/quickBan_kicked(var/bantype, var/reason)
	src << "<span class = 'userdanger'>You have been given a [lowertext(bantype)]-ban. Reason: '[reason]'</span>"
	del src

/* check if we're an admin trying to quickBan another admin */
/client/proc/trying_to_quickBan_admin(_ckey, cID, ip)
	// check to see if we're trying to ban an admin by ckey
	var/list/admincheck = database.execute("SELECT * FROM admin WHERE ckey == '[_ckey]';")
	if (islist(admincheck) && !isemptylist(admincheck))
		src << "<span class = 'danger'>You can't ban admins!</span>"
		return 1

	var/list/playercheck = database.execute("SELECT * FROM connection_log WHERE ckey == '[_ckey]' OR ip == '[ip]' OR computerid == '[cID]';")
	if (islist(playercheck) && !isemptylist(playercheck))
		if (playercheck.Find("ckey"))
			var/player_ckey = playercheck["ckey"]
			if (player_ckey)
				admincheck = database.execute("SELECT * FROM admin WHERE ckey == '[player_ckey]';")
				if (islist(admincheck) && !isemptylist(admincheck))
					src << "<span class = 'danger'>You can't ban admins!</span>"
					return 1
	return 0