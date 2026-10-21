require "test_helper"

class GamesHelperTest < ActionView::TestCase
  test "platform_label shortens known IGDB platform names" do
    assert_equal "PC", platform_label("PC (Microsoft Windows)")
    assert_equal "PS5", platform_label("PlayStation 5")
    assert_equal "Switch", platform_label("Nintendo Switch")
  end

  test "platform_label falls back to the full name for unlisted platforms" do
    assert_equal "Xbox Series X|S", platform_label("Xbox Series X|S")
  end

  test "platform_label passes nil through" do
    assert_nil platform_label(nil)
  end
end
