require "test_helper"

class CollectionsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
  end

  test "index requires authentication" do
    get collections_path
    assert_redirected_to new_session_path
  end

  test "index shows an empty state when the user has no collections" do
    sign_in(@user)
    get collections_path

    assert_response :success
    assert_match "any collections yet", response.body
  end

  test "index lists only the current user's collections, ordered by title" do
    @user.collections.create!(title: "Wishlist", description: "Games I want")
    @user.collections.create!(title: "Owned")
    @other_user.collections.create!(title: "Graces Secret List")

    sign_in(@user)
    get collections_path

    assert_response :success
    assert_match "Games I want", response.body
    assert_no_match "Graces Secret List", response.body
    assert_operator response.body.index("Owned"), :<, response.body.index("Wishlist")
  end
end
