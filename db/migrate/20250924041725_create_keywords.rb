class CreateKeywords < ActiveRecord::Migration[8.0]
  def change
    create_table :keywords do |t|
      t.references :user, null: false, foreign_key: true
      t.references :keyword_upload, null: false, foreign_key: true
      t.string :phrase, null: false
      t.integer :status, null: false, default: 0
      t.integer :ads_count, null: false, default: 0
      t.integer :links_count, null: false, default: 0
      t.datetime :scraped_at
      t.text :error_message
      t.string :serp_digest

      t.timestamps
    end

    add_index :keywords, :status
    add_index :keywords, :serp_digest
    add_index :keywords, [:keyword_upload_id, :phrase], unique: true
  end
end
