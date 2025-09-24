class AddAdsDataAndLinksDataToKeywords < ActiveRecord::Migration[8.0]
  def change
    add_column :keywords, :ads_data, :json
    add_column :keywords, :links_data, :json
  end
end
