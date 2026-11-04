class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :review, null: false, foreign_key: true
      t.string :reason, null: false

      t.timestamps
    end

    add_index :reports, [ :user_id, :review_id ], unique: true, name: "index_reports_on_user_and_review"
    add_check_constraint :reports, "reason IN ('spam', 'abusive', 'spoiler', 'other')", name: "reports_reason_values"
  end
end
