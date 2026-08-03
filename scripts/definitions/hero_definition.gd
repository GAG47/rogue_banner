class_name HeroDefinition
extends DefinitionResource

@export var portrait: Texture2D
@export var starting_units: Array[UnitDefinition] = []
@export var starting_relics: Array[RelicDefinition] = []
@export var exclusive_relics: Array[RelicDefinition] = []
@export var preferred_tags: Array[TagWeight] = []
@export var art_pool: Array[ArtDefinition] = []
