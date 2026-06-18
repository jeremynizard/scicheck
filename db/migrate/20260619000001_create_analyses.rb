class CreateAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :analyses do |t|
      t.string   :doi, null: false
      t.text     :payload
      t.integer  :global_score
      t.string   :grade
      t.datetime :computed_at
      t.datetime :accessed_at

      t.timestamps
    end

    add_index :analyses, :doi, unique: true
  end
end
