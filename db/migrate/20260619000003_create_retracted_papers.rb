class CreateRetractedPapers < ActiveRecord::Migration[8.1]
  def change
    create_table :retracted_papers do |t|
      t.string :doi, null: false
      t.string :nature          # Retraction / Correction / Expression of concern / ...
      t.text   :reason
      t.date   :retraction_date
      t.text   :title

      t.timestamps
    end

    add_index :retracted_papers, :doi, unique: true
  end
end
