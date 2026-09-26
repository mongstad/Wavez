extends RefCounted
# Physical-memory policy shared by playback workers. Swap is never capacity.
const MIB := 1048576
static func system_reserve(physical: int) -> int:
	return clampi(int(physical*.03),512*MIB,2048*MIB)
static func snapshot() -> Dictionary:
	var info := OS.get_memory_info()
	var physical: int = maxi(0,info.get("physical",0))
	var available: int = maxi(0,info.get("free",0))
	var rss := 0;var peak := 0;var swap := 0
	if OS.get_name() == "Linux":
		for path in ["/proc/meminfo","/proc/self/status"]:
			var file := FileAccess.open(path,FileAccess.READ)
			var contents := file.get_buffer(65536).get_string_from_utf8() if file != null else ""
			for line in contents.split("\n"):
				var parts := line.replace("\t"," ").split(" ",false)
				if parts.size() < 2:continue
				match parts[0]:
					"MemTotal:":physical = int(parts[1])*1024
					"MemAvailable:":available = int(parts[1])*1024
					"VmRSS:":rss = int(parts[1])*1024
					"VmHWM:":peak = int(parts[1])*1024
					"VmSwap:":swap = int(parts[1])*1024
	var system := system_reserve(physical)
	# Existing process/driver pages already reduce available RAM. Reserve only
	# future driver/UI growth here; per-job decode/upload scratch is separate.
	var renderer := 256*MIB
	var reserve := system+renderer
	return {"physical":physical,"available_physical":available,"process_rss":rss,"process_peak_rss":peak,"process_swap":swap,"system_reserve":system,"renderer_reserve":renderer,"reserve":reserve,"safe_cache_bytes":maxi(0,mini(int(physical*.4),available-reserve))}
static func capacity(memory: Dictionary, resident: int, pending_other: int, largest: int) -> int:
	# MemAvailable already excludes process RSS; do not subtract it twice.
	# Credit only still-owned field arrays/planes, never historical RSS peaks.
	# Three jobs cover decoding/copies and current/staged references at turnover;
	# 5% slack covers allocation overhead beyond the explicit byte accounting.
	var physical_credit := maxi(0,resident-int(memory.get("process_swap",0)))
	return maxi(0,int((int(memory.available_physical)+physical_credit-int(memory.reserve)-pending_other-largest*3)/1.05))
