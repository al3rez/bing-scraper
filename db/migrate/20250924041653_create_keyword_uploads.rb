class CreateKeywordUploads < ActiveRecord::Migration[8.0]
  def change
    create_table :keyword_uploads do |t|
      t.references :user, null: false, foreign_key: true
      t.string :original_filename, null: false
      t.integer :keyword_count, null: false, default: 0
      t.integer :processed_keywords_count, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.text :error_message
      t.datetime :processed_at

      t.timestamps
    end

    add_index :keyword_uploads, :status
  end
end
