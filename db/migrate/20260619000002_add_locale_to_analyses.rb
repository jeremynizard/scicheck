class AddLocaleToAnalyses < ActiveRecord::Migration[8.1]
  def change
    add_column :analyses, :locale, :string, null: false, default: "en"
    remove_index :analyses, :doi
    add_index :analyses, [ :doi, :locale ], unique: true
  end
end
