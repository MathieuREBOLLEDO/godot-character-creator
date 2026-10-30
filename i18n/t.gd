@tool
extends RefCounted

## Traduction des textes de l'écran de création. Les textes sont écrits en
## anglais dans le code : T.t("Random"). L'écran est vu par le joueur : il
## suit la langue du jeu (TranslationServer), sauf si set_language() en
## impose une. Un texte absent du dictionnaire reste en anglais.
## Pour ajouter une langue : copier i18n/fr.gd, le traduire, l'ajouter ici.

const FR = preload("res://addons/character_creator/i18n/fr.gd")
const LANGUAGES: Array[String] = ["en", "fr"]
const META: StringName = &"character_creator_language"


static func t(text: String) -> String:
	if get_language() == "fr":
		return FR.TEXTS.get(text, text)
	return text


static func get_language() -> String:
	if Engine.has_meta(META):
		return Engine.get_meta(META)
	return TranslationServer.get_locale().left(2)


## "" : suivre la langue du jeu.
static func set_language(language: String) -> void:
	if language == "":
		Engine.remove_meta(META)
	else:
		Engine.set_meta(META, language if LANGUAGES.has(language) else "en")
