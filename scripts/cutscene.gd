class_name Cutscene
extends Resource

enum Trigger {
	FIRST_LAUNCH,      # plays once on the very first day_started of a new save
	DAY_NUMBER,        # plays on the exact day_number == threshold
	MONEY_TOTAL_EARNED,  # plays the day_started after total_money_earned >= threshold
}

@export var id: StringName = &""
@export var title: String = ""
@export var body: String = ""
@export var trigger: Trigger = Trigger.DAY_NUMBER
@export var threshold: float = 1.0
@export var run_once: bool = true  # most cutscenes play once; toggle off for repeat beats
