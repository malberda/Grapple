extends Node

# --------------------
# ROCKET BOOST
# --------------------
@export var rocket_boost_strength := 1800.0  # tweak for speediness
@export var rocket_boost_duration := 0.2     # seconds of boost
var rocket_boost_timer := 0.0
var rocket_boost_used := false
