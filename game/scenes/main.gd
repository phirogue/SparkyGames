extends Control
## Placeholder main scene: proves the project boots and content validates.
## Replaced by the real hub/battle scenes as the UI layer is built.

@onready var label: Label = $Label

func _ready() -> void:
	var catalog := DataLoader.load_catalog()
	var problems := catalog.validate()
	var status := "content OK" if problems.is_empty() else "CONTENT PROBLEMS:\n" + "\n".join(problems)
	label.text = "The Nine Lives of Ash\nscaffold v0.1.0\n\n%d energy cards / %d skills / %d enemies / %d encounters\n%s" % [
		catalog.energy_cards.size(), catalog.skills.size(),
		catalog.enemies.size(), catalog.encounters.size(), status,
	]
	for problem in problems:
		push_error(problem)
