module GamesHelper
  # Short display names for IGDB platform names, which are long
  # ("PC (Microsoft Windows)"). Anything not listed shows its full name.
  PLATFORM_LABELS = {
    "PC (Microsoft Windows)" => "PC",
    "PlayStation 5" => "PS5",
    "PlayStation 4" => "PS4",
    "PlayStation 3" => "PS3",
    "PlayStation 2" => "PS2",
    "PlayStation" => "PS1",
    "Nintendo Switch" => "Switch",
    "Nintendo Switch 2" => "Switch 2",
    "Super Nintendo Entertainment System" => "SNES",
    "Nintendo Entertainment System" => "NES",
    "Nintendo 64" => "N64",
    "New Nintendo 3DS" => "New 3DS"
  }.freeze

  def platform_label(name)
    PLATFORM_LABELS.fetch(name, name)
  end
end
