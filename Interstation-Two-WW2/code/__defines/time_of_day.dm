//#define ALWAYS_DAY

var/time_of_day = "Morning"
var/list/times_of_day = list("Morning", "Afternoon", "Midday", "Evening", "Night", "Midnight", "Early Morning")
// from lightest to darkest: midday, afternoon, morning, early morning, evening, night, midnight
var/list/time_of_day2luminosity = list(
	"Midday" = 1.0,
	"Afternoon" = 0.8,
	"Morning" = 0.7,
	"Evening" = 0.5,
	"Early Morning" = 0.4,
	"Night" = 0.3,
	"Midnight" = 0.2)

/proc/pick_TOD()
	// attempt to fix broken BYOND probability
	times_of_day = shuffle(times_of_day)
	#ifdef ALWAYS_DAY
	return "Midday"
	#else
	if (prob(40))
		return "Midday"
	else
		return pick(times_of_day - "Midday")
	#endif

// cycles
/proc/randomly_update_lighting()
	update_lighting(null)