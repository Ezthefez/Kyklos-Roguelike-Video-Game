extends Node

var ammo: int = 5
var targets_remaining: int = 0
var game_over := false

signal ammo_changed(new_ammo)
signal game_won
signal game_lost
