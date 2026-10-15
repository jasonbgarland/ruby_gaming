class CreateCompaniesAndGameCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :companies, "lower(name)", unique: true, name: "index_companies_on_lower_name"

    create_table :game_companies do |t|
      t.references :game, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end
    add_index :game_companies, [ :game_id, :company_id, :role ], unique: true,
      name: "index_game_companies_on_game_company_role"
  end
end
