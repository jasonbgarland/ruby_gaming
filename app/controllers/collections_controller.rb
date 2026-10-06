class CollectionsController < ApplicationController
  def index
    @collections = Current.user.collections.order(:title)
  end
end
